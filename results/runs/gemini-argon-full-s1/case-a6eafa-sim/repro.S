#include "hyp.h"

/* G-stage execute-only leaf PTE (U=1 is required for all G-stage leaves). */
#define G_XO (PTE_V | PTE_X | PTE_U | PTE_A)

#define CAUSE_LOAD_GUEST_PAGE_FAULT 21

  .text
  .globl test_main
test_main:
  /* Grant RWX PMP permissions over all physical memory for HS/VS/PTW accesses. */
  PMP_ALLOW_ALL

  /* Keep all traps in M-mode and ensure HS-mode stage-1 translation is Bare. */
  csrw medeleg, zero
  csrw satp, zero
  csrw vsstatus, zero

  /* Clear MXR, SUM, MPRV, TVM, TW, TSR, MPV in mstatus. */
  li t0, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20) | (1 << 21) | (1 << 22) | MSTATUS_MPV
  csrc mstatus, t0

  /* HLVX effective privilege = VS-mode (SPVP = 1). */
  li t0, HSTATUS_SPVP
  csrw hstatus, t0

  /*
   * Build G-stage root table (Sv39x4, 1 GiB leaves):
   *   g_root[2]: GPA [0x80000000, 0xc0000000) -> HPA 0x80000000 with G_RWX
   *   g_root[3]: GPA [0xc0000000, 0x100000000) -> HPA 0x80000000 with G_XO (execute-only)
   */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, G_XO)

  /*
   * Build VS-stage root table (Sv39, 1 GiB leaves):
   *   vs_root[2]: GVA [0x80000000, 0xc0000000) -> GPA 0x80000000 with VS_RWX
   *   vs_root[1]: GVA [0x40000000, 0x80000000) -> GPA 0x80000000 with VS_RWX
   */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  GIGA_LEAF(vs_root, 1, 0x80000000, VS_RWX)

  fence rw, rw

  /* Enable G-stage translation. */
  HGATP_ON

  /* Phase 1: point vsatp at vs_root via its G_RWX GPA (0x8000xxxx). */
  la t0, vs_root
  VSATP_ON(t0)

  /* s0 = 1 only while executing the faulting HLVX in Phase 2. */
  li s0, 0
  li s1, 0

  /* Drop to HS-mode (MPP=1, MPV=0) to execute HLVX.WU. */
  ENTER_MODE(1, hs_entry)

hs_entry:
  /* Sanity check: HLVX.WU must succeed when vs_root is mapped G_RWX. */
  la a0, guest_word
  hlvx.wu t2, (a0)
  li t3, 0x12345678
  bne t2, t3, fail_sanity

  /*
   * Phase 2 (bug check): repoint vsatp at the execute-only G-stage alias of
   * vs_root at GPA = PA(vs_root) + 0x40000000 (covered by g_root[3] with G_XO).
   * Reading the VS-stage PTE is an implicit ordinary load for G-stage checks,
   * so HLVX.WU must raise a load guest-page fault (mcause = 21).
   */
  la t0, vs_root
  li t1, 0x40000000
  add t0, t0, t1
  VSATP_ON(t0)
  hfence.gvma

  /* Use a fresh GVA in vs_root[1] mapping to the same guest_word in g_root[2]. */
  la a1, guest_word
  li t1, 0x40000000
  sub a1, a1, t1

  la s1, hlvx_fault_insn
  li s0, 1
hlvx_fault_insn:
  hlvx.wu t4, (a1)
  li s0, 0

  /* Buggy core reaches here because HLVX.WU erroneously succeeded. */
  FAIL(2)

fail_sanity:
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  li t0, 1
  bne s0, t0, unexpected_trap

  csrr t0, mepc
  bne t0, s1, wrong_epc

  csrr t0, mcause
  li t1, CAUSE_LOAD_GUEST_PAGE_FAULT
  bne t0, t1, wrong_cause

  PASS

unexpected_trap:
  FAIL(3)
wrong_epc:
  FAIL(4)
wrong_cause:
  FAIL(5)

  .align 2
guest_word:
  .word 0x12345678

  HYP_TABLES
