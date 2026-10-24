/* Bug reproducer: two-stage address translation, wrong exception on a faulting store.
 *
 * The core reports a *load* access fault instead of a *store* access fault when
 * a store's two-stage page-table walk is denied by PMP. In cva6_mmu.sv the
 * DTLB-miss ptw_access_exception path only selects ST_ACCESS_FAULT when
 * (lsu_is_store_q && !CVA6Cfg.RVH && CVA6Cfg.PtLevels == 3), which can never
 * hold in this RVH-enabled configuration, so the cause defaults to
 * LD_ACCESS_FAULT even for stores.
 *
 * Scenario (two-stage translation, V=1):
 *   - G-stage root g_root (Sv39x4, 1 GiB leaves) and VS-stage root vs_root
 *     (Sv39, 1 GiB leaves) are set up so that instruction fetches of the code
 *     translate fine.
 *   - PMP denies S-mode reads of the 8-byte word at 0x80008018, which holds
 *     vs_root entry 3 - the VS-stage PTE the store's walk must read. All other
 *     PTEs the walks touch are readable.
 *   - A store to VA 0xC0000040 misses in the DTLB. Its two-stage walk starts in
 *     the G stage (reads g_root[2] at 0x80004010, allowed), then in the S stage
 *     reads vs_root[3] at 0x80008018 -> PMP denial -> ptw_access_exception for
 *     a *store* -> must be a store access fault (cause 7).
 *
 * PMP layout (this core checks entries in ascending index order, first match
 * wins; M-mode is not subject to PMP; PTW checks run as S-mode reads). All
 * entries are set via pmpcfg0 (byte i = entry i). pmpcfg byte =
 * {L(7), 0(6:5), A(4:3), X(2), W(1), R(0)} with TOR = 0b01.
 * g_root is at 0x80004000, vs_root at 0x80008000:
 *   entry 0 (TOR): [0, 0x80008018)        RWX - code, tohost, g_root,
 *                                             vs_root entries 0..2 (fetch PTEs)
 *   entry 1 (TOR): [0x80008018, 0x80008020) no access - the vs_root entry 3
 *                                             word the store walk must read
 *   entry 2 (TOR): [0x80008020, top)      RWX - rest of vs_root, stack
 *
 * A correct core takes the trap in HS mode with scause == 7 (store access
 * fault) -> PASS. The buggy core reports scause == 5 (load access fault) ->
 * FAIL.
 */
#include "hyp.h"

  HYP_TABLES

  .text
  .globl test_main
test_main:
  /* PMP: split the table region around the 8-byte word holding vs_root entry 3
   * (vs_root is at 0x80008000, so entry 3 is at 0x80008018). All entries fit in
   * pmpcfg0 (this core faults on writes to the odd pmpcfg CSRs at XLEN=64). */
  li t0, 0x20002006; csrw pmpaddr0, t0   /* 0x80008018 / 4 */
  li t0, 0x20002008; csrw pmpaddr1, t0   /* 0x80008020 / 4 */
  li t0, -1;         csrw pmpaddr2, t0   /* top */
  li t0, 0x000f080f; csrw pmpcfg0, t0    /* e0: TOR RWX; e1: TOR no-access; e2: TOR RWX */

  la t0, m_backstop;  csrw mtvec, t0
  la t0, hs_handler;  csrw stvec, t0

  /* deliver load/store access faults from any S-level trap to HS (not to VS,
   * not to M): delegate causes 5 and 7, hedeleg stays 0 */
  li t0, (1 << 5) | (1 << 7);
  csrw medeleg, t0

  /* G-stage (Sv39x4): 1 GiB leaves. entry 2 covers the code/table GPA range,
   * entry 3 covers the data GPA range used below. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, G_RWX)
  /* VS-stage (Sv39): entry 2 maps the code VAs, entry 3 maps the data VA.
   * The entry-3 PTE word itself is PMP-read-denied (0x80008018). */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  GIGA_LEAF(vs_root, 3, 0xC0000000, VS_RWX)

  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  /* mret straight into VS mode (MPP=S, MPV=1) */
  ENTER_VS(vs_entry)

vs_entry:
  /* two-stage enabled (V=1, vsatp+hgatp valid): this store misses in the
   * DTLB and its walk faults in the S stage on the PMP-denied PTE word.
   * Must raise a store access fault (cause 7). */
  li t3, 0xC0000040
  sd zero, 0(t3)
  /* the store must have faulted; reaching here means setup is broken */
  FAIL(300)

/* HS-mode trap handler: the V=1 access fault lands here (medeleg set,
 * hedeleg=0 -> stvec, scause/sepc/stval). */
hs_handler:
  csrr t0, scause
  li t1, 7                  /* store/AMO access fault */
  bne t0, t1, hs_fail
  /* expected cause: return to HS mode (V=0) and PASS */
  li t1, 0x80
  csrc mstatus, t1          /* SPP = S */
  csrs mstatus, t1
  li t1, HSTATUS_SPVP
  csrc hstatus, t1          /* SPVP = 0 */
  la t1, hs_done
  csrw sepc, t1
  sret
hs_fail:
  /* wrong exception (or wrong anything): FAIL(scause+1) */
  addi a0, t0, 1
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt

hs_done:
  PASS

/* M-mode backstop: any trap taken in M mode is unexpected.
 * FAIL(((mepc-0x80000000)/4)<<8 | mcause) + 200 so the code reveals both. */
  .globl m_backstop
  .globl trap_handler
  .align 2
m_backstop:
trap_handler:
  csrr t0, mcause
  csrr t1, mepc
  li t2, 0x80000000
  sub t1, t1, t2
  srli t1, t1, 2
  slli t1, t1, 8
  or a0, t1, t0
  addi a0, a0, 200
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt
