/* G-stage PTEs must be checked as user-level accesses (U=1 required), including
 * the implicit reads of VS-stage page tables (H spec, two-stage translation).
 * The PTW accepts a G-stage leaf with U=0 when translating the GPA of a VS-level
 * page table (G_INTERMED_STAGE), so the walk succeeds instead of raising a
 * load guest-page fault.
 *
 * Setup: G-stage maps GPA 0x80000000 (1 GiB, identity) and GPA 0x3000 -> vs_root
 * through 4 KiB G-stage pages. vsatp points to GPA 0x3000. An HLV.D from M-mode
 * (hstatus.SPVP=1) to VA 0 walks vs_root via that G-stage 4 KiB PTE. */
#include "hyp.h"

#define MAGIC 0x1234567
#define MKPTE(reg, sym, flags) la reg, sym; srli reg, reg, 12; slli reg, reg, 10; ori reg, reg, flags
#define STPTE(table, idx, reg) la t2, table; li t3, ((idx) * 8); add t2, t2, t3; sd reg, 0(t2)
#define FLUSH hfence.vvma; hfence.gvma; sfence.vma; li s11, 0

  .option norvc
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* G-stage */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  MKPTE(t0, g_l1, PTE_V)
  STPTE(g_root, 0, t0)
  MKPTE(t0, g_l0, PTE_V)
  STPTE(g_l1, 0, t0)
  MKPTE(t0, vs_root, G_RWX)          /* GPA 0x3000 -> vs_root */
  STPTE(g_l0, 3, t0)
  HGATP_ON

  /* VS-stage: VA 0 -> vs_l1 -> vs_l0 -> datapg (GPA == PA in DRAM) */
  MKPTE(t0, vs_l1, PTE_V)
  STPTE(vs_root, 0, t0)
  MKPTE(t0, vs_l0, PTE_V)
  STPTE(vs_l1, 0, t0)
  MKPTE(t0, datapg, VS_RWX)
  STPTE(vs_l0, 0, t0)
  li t0, 0x3000
  VSATP_ON(t0)

  /* 1: sanity, U=1 on the G-stage PTE of the VS root: load succeeds */
  FLUSH
  li a1, 0
  hlv.d a0, (a1)
  bnez s11, fail1
  li t0, MAGIC
  bne a0, t0, fail2

  /* 2: same G-stage PTE with U=0: must raise a load guest-page fault (21) */
  MKPTE(t0, vs_root, G_RWX & ~PTE_U)
  STPTE(g_l0, 3, t0)
  FLUSH
  li a1, 0
  hlv.d a0, (a1)
  li t0, 21
  bne s11, t0, fail3
  PASS

fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)

  /* Record mcause in s11 and skip the faulting instruction. */
  .align 2
  .globl trap_handler
trap_handler:
  csrr s11, mcause
  csrr t6, mepc
  addi t6, t6, 4
  csrw mepc, t6
  mret

  HYP_TABLES
  .align 12
g_l1: .space 4096
g_l0: .space 4096
vs_l1: .space 4096
vs_l0: .space 4096
datapg: .dword MAGIC
  .space 4088
