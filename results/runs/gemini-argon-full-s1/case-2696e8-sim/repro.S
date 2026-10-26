#include "hyp.h"

#define CAUSE_LOAD_GUEST_PAGE_FAULT 21
#define MSTATUS_MXR (1 << 19)
#define GUEST_INSN_WORD 0x12345013

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Route all traps to M-mode trap_handler; disable interrupts; clear MXR, MPV, VMXR. */
  csrw medeleg, zero
  csrw mie, zero
  li t0, (MSTATUS_MXR | MSTATUS_MPV)
  csrc mstatus, t0
  csrw vsstatus, zero
  csrw satp, zero
  sfence.vma

  /* HLV/HLVX effective privilege = VS-mode (SPVP = 1). */
  li t0, HSTATUS_SPVP
  csrw hstatus, t0

  /* G-stage (Sv39x4):
   * - idx 2 (GPA 0x80000000..0xbfffffff) -> PA 0x80000000 RWX (for vs_root walk)
   * - idx 1 (GPA 0x40000000..0x7fffffff) -> PA 0x80000000 execute-only (X=1, R=0, W=0)
   */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 1, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))

  /* VS-stage (Sv39):
   * - idx 1 (GVA 0x40000000..0x7fffffff) -> GPA 0x40000000 RWX
   */
  GIGA_LEAF(vs_root, 1, 0x40000000, VS_RWX)

  fence rw, rw
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  /* Compute GVA in 0x40000000..0x7fffffff aliasing guest_word in PA 0x80000000.. */
  la s0, guest_word
  li t0, 0x40000000
  sub s0, s0, t0

  li s1, GUEST_INSN_WORD
  li s2, 0

  /* Enter HS-mode (S-mode, V=0) to execute hypervisor loads. */
  ENTER_MODE(1, hs_entry)

hs_entry:
  /* Stage 1: Before HLVX populates the DTLB, plain HLV.WU must fault. */
  li s2, 1
  .globl hlv_cold_insn
hlv_cold_insn:
  hlv.wu a1, (s0)

  /* trap_handler sets s2 = 2 and advances mepc past hlv_cold_insn. */
  li t0, 2
  bne s2, t0, fail_cold_no_trap

  /* Stage 2: HLVX.WU from G-stage execute-only page must succeed. */
  hlvx.wu a0, (s0)
  bne a0, s1, fail_hlvx_val

  /* Stage 3: Plain HLV.WU from the same page must still raise Load Guest-Page Fault (21). */
  li s2, 3
  .globl hlv_after_insn
hlv_after_insn:
  hlv.wu a2, (s0)

  /* Buggy core reaches here because plain HLV succeeded after HLVX cached the translation. */
  FAIL(2)

fail_cold_no_trap:
  FAIL(1)
fail_hlvx_val:
  FAIL(3)

  .globl trap_handler
  .balign 4
trap_handler:
  csrr t0, mcause
  li t1, CAUSE_LOAD_GUEST_PAGE_FAULT
  bne t0, t1, fail_wrong_cause

  li t2, 1
  beq s2, t2, handle_cold_fault

  li t2, 3
  beq s2, t2, handle_after_fault

  FAIL(4)

handle_cold_fault:
  csrr t0, mepc
  la t1, hlv_cold_insn
  bne t0, t1, fail_wrong_epc
  addi t0, t0, 4
  csrw mepc, t0
  li s2, 2
  mret

handle_after_fault:
  csrr t0, mepc
  la t1, hlv_after_insn
  bne t0, t1, fail_wrong_epc
  PASS

fail_wrong_cause:
  FAIL(5)
fail_wrong_epc:
  FAIL(6)

  .balign 8
guest_word:
  .word GUEST_INSN_WORD
  .word 0

  HYP_TABLES
