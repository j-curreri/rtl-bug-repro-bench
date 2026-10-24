/* repro.S — CVA6 bug reproducer.
 *
 * Bug: the DATA page-table walker treats the implicit read of a VS-stage PTE
 * (the G_INTERMED_STAGe walk that fetches the VS page-table page the HLVX's
 * virtual address points at) as if it were an HLVX load.  It applies the
 * hlvx_inst_i execute-as-read bypass to the *G-stage intermediate* leaf
 * permission check in cva6_ptw.sv:
 *
 *     (pte.a && ((pte.r && !hlvx_inst_i) || (pte.x && (mxr_i || hlvx_inst_i ...))))
 *
 * An implicit PTE read is an ordinary load for G-stage permission checks, so
 * the G-stage page table entry covering the VS page table must be READABLE
 * (pte.r) for the walk to proceed.  Here the VS-stage root table lives at
 * guest-physical addresses that the G stage maps with an EXECUTE-ONLY 1 GiB
 * leaf (pte.r = 0), so a correct core raises a load guest-page fault while
 * the buggy core happily serves the HLVX.
 *
 * Mission: run ONLY the data path through the two-stage walker — i.e. execute
 * HLVX in HS mode (V=0) with hgatp/vsatp enabled so that no instruction fetch
 * ever goes through the VS stage (instruction walks check the G-stage
 * intermediate leaf correctly: cva6_ptw.sv's ITLB path already requires
 * pte.r at G_INTERMED_STAGE).  See the note in FAIL(1) below.
 *
 * Expected results:
 *   Correct core:  trap with mcause = 21 (load guest-page fault) -> PASS
 *   Buggy core:    HLVX succeeds  -> FAIL(1)
 */

#include "test.h"
#include "hyp.h"

/* X|U|A|D|V (no R, no W): leaf PTE through which only HLVX may read/cx. */
#define XONLY (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)

  .section .text
  .globl  test_main

test_main:
  /* ---- M-mode setup ---- */
  PMP_ALLOW_ALL
  la   t0, trap_entry
  csrw mtvec, t0
  csrw medeleg, x0
  csrw satp, x0

  /* Defensive: make sure no MPRV/MXR-style aliasing retunes the load checks.
   * Reset values are 0; force them for determinism. */
  li   t0, (1 << 19)          /* mstatus.MXR */
  csrc mstatus, t0
  li   t0, HSTATUS_SPVP
  csrc hstatus, t0            /* hstatus.SPVP = 0 */

  /* ---- Page tables ----
   * G stage (Sv39x4), 1 GiB leaves only:
   *   g_root[2]: GPA 0x80000000+i -> HPA 0x80000000+i, R|W|X (plain memory)
   *   g_root[3]: GPA 0xC0000000+i -> HPA 0x80000000+i, EXECUTE-ONLY (no R)
   * The VS-stage root table lives in DRAM at HPA ~0x80005000 and is
   * therefore accessed through the x-only guest-physical alias region at
   * GPA 0xC0000000.  That aliases the *implicit* VS-stage PTE reads: their
   * G-stage leaf is g_root[3] — pte.r = 0 — which is precisely the check the
   * buggy walker gets wrong. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, XONLY)
  /* VS stage (Sv39), 1 GiB leaf:
   *   vs_root[2]: VA 0x80000000+i -> GPA 0x80000000+i, EXECUTE-ONLY, U|A|D.
   * HLVX is the op that may execute-read it; a plain load must fault. */
  GIGA_LEAF(vs_root, 2, 0x80000000, XONLY)

  /* ---- Enable two-stage translation ---- */
  HGATP_ON                    /* hgatp <- (8<<60) | (pa(g_root)>>12); hfence.gvma  */

  /* vsatp <- (8<<60) | ((pa(v_sroot) + 0x40000000) >> 12): the GS-stage root
   * at its GUEST-PHYSICAL alias 0xC0000000+.  hfence.vvma, then return to
   * HS mode (V=0) with satp left bare so instruction fetch stays one-stage. */
  la   t0, vs_root
  li   t1, 0x40000000
  add  t0, t0, t1
  srli t0, t0, 12
  li   t1, SATP_SV39
  or   t0, t0, t1
  csrw vsatp, t0
  hfence.vvma

  ENTER_MODE(1, hs_test)      /* MPP=1, mret -> HS mode at hs_test */

  /* ---- The trigger ----
   * First two-stage data access of the context: HLVX.WU at VA 0x80002000.
   * hlvx_inst_i=1 reaches the walker; the VS leaf is X-only and the G-stage
   * leaf covering the VS PTE is X-only.
   *
   * NOTE: the encoding is hand-written .word because this core decodes
   * HLVX.WU as funct7=0110100 rs2=00011 funct3=100 (see decoder.sv);
   * the standard assembler encoding (rs2=00100) decodes to a plain op here.
   *   .word 0x683342F3 = hlvx.wu t0, 0(t1)   (rd=x5, rs1=x6) */
hs_test:
  li   t1, 0x80002000
  .word 0x683342F3            /* hlvx.wu t0, 0(t1) */
  FAIL(1)                     /* HLVX succeeded: implicit VS-PTE read was EX   */

  /* ---- Trap handler: mtvec from _start ----
   * Correct core: the walk raises a load guest-page fault (mcause 21) -> PASS.
   * Anything else is an unexpected trap -> FAIL(mcause).  Traps stay in M
   * mode: medeleg = 0, mtvec points in bare-mode here (satp = 0 before span
   * entry). */
  .align 2
  .globl trap_entry
trap_entry:
  csrr t0, mcause
  li   t1, 0x3F               /* mask off any interrupt bit; compare mod 64 */
  and  t0, t0, t1
  li   t1, 21                 /* load guest-page fault */
  beq  t0, t1, ok
  slli a0, t0, 1              /* FAIL(mcause) for debugging */
  ori  a0, a0, 1
  j    _halt
ok:
  PASS

  /* ---- Tables (in DRAM, zero-filled pages) ---- */
  HYP_TABLES