#include "test.h"

#define PTE_V 0x01
#define PTE_R 0x02
#define PTE_W 0x04
#define PTE_X 0x08
#define PTE_U 0x10
#define PTE_A 0x40
#define PTE_D 0x80

#define MSTATUS_MPP_MASK (3 << 11)
#define MSTATUS_MPP_S    (1 << 11)
#define MSTATUS_MPRV     (1 << 17)
#define MSTATUS_SUM      (1 << 18)
#define MSTATUS_MXR      (1 << 19)

#define SATP_MODE_SV39         0x8000000000000000
#define CAUSE_SUPERVISOR_ECALL 9
#define CAUSE_LOAD_PAGE_FAULT  13

  .section .text
  .globl test_main
  .align 2
test_main:
  /* Grant S/U-mode RWX access to physical memory via PMP. */
  PMP_ALLOW_ALL

  /* Ensure traps from S-mode reach M-mode and SUM/MXR are clear. */
  csrw medeleg, zero
  csrw mideleg, zero
  li   t0, (MSTATUS_SUM | MSTATUS_MXR)
  csrc mstatus, t0

  /* Zero l2_pt and l1_pt (4 KiB each). */
  la   t0, l2_pt
  li   t1, 512
1:
  sd   zero, 0(t0)
  addi t0, t0, 8
  addi t1, t1, -1
  bnez t1, 1b

  la   t0, l1_pt
  li   t1, 512
2:
  sd   zero, 0(t0)
  addi t0, t0, 8
  addi t1, t1, -1
  bnez t1, 2b

  /* Populate l0_pt: identity-map [0x80000000, 0x80200000) as 4 KiB S-mode RWX pages. */
  la   t0, l0_pt
  li   t1, ((0x80000000 >> 12) << 10) | (PTE_V | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D)
  li   t2, 512
3:
  sd   t1, 0(t0)
  addi t0, t0, 8
  addi t1, t1, (1 << 10)
  addi t2, t2, -1
  bnez t2, 3b

  /* Remap VA(page_a) -> PA(page_b) as an S-mode RW page. */
  la   t0, page_a
  srli t0, t0, 12
  andi t0, t0, 0x1ff
  slli t0, t0, 3
  la   t1, l0_pt
  add  t0, t1, t0

  la   t1, page_b
  srli t1, t1, 12
  slli t1, t1, 10
  ori  t1, t1, (PTE_V | PTE_R | PTE_W | PTE_A | PTE_D)
  sd   t1, 0(t0)

  /* Map VA(page_c) -> PA(page_c) with U=1 (inaccessible to S-mode when SUM=0). */
  la   t0, page_c
  srli t0, t0, 12
  andi t0, t0, 0x1ff
  slli t0, t0, 3
  la   t1, l0_pt
  add  t0, t1, t0

  la   t1, page_c
  srli t1, t1, 12
  slli t1, t1, 10
  ori  t1, t1, (PTE_V | PTE_R | PTE_W | PTE_U | PTE_A | PTE_D)
  sd   t1, 0(t0)

  /* Link l1_pt[0] -> l0_pt (non-leaf PTE: V=1, R=W=X=U=A=D=0). */
  la   t0, l1_pt
  la   t1, l0_pt
  srli t1, t1, 12
  slli t1, t1, 10
  ori  t1, t1, PTE_V
  sd   t1, 0(t0)

  /* Link l2_pt[2] (covering 0x80000000..0xbfffffff) -> l1_pt (non-leaf PTE: V=1). */
  la   t0, l2_pt
  la   t1, l1_pt
  srli t1, t1, 12
  slli t1, t1, 10
  ori  t1, t1, PTE_V
  sd   t1, (2 * 8)(t0)

  /* Enable Sv39 translation in satp and flush TLBs. */
  fence rw, rw
  la   t0, l2_pt
  srli t0, t0, 12
  li   t1, SATP_MODE_SV39
  or   t0, t0, t1
  csrw satp, t0
  sfence.vma

  /* Set MPP=S and MPRV=1 while in M-mode. */
  la   t0, s_entry
  csrw mepc, t0
  li   t0, MSTATUS_MPP_MASK
  csrc mstatus, t0
  li   t0, (MSTATUS_MPP_S | MSTATUS_MPRV)
  csrs mstatus, t0

  /* Confirm MPRV=1 + MPP=S translates page_a -> page_b before MRET (also warms DTLB). */
  la   a0, page_a
  ld   t2, 0(a0)
  li   t3, 0xdeadbeefcafebabe
  bne  t2, t3, fail_setup

  /* MRET from M-mode to S-mode: per RISC-V Privileged Spec, returning to a mode
   * less privileged than M must clear mstatus.MPRV to 0. */
  mret

  .align 2
s_entry:
  /* Trap back to M-mode via ECALL (sets MPP=S while leaving MPRV unchanged). */
  ecall
  j    fail_unexpected

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li   t1, CAUSE_SUPERVISOR_ECALL
  bne  t0, t1, unexpected_trap

  /* Now running in M-mode with MPP=S and satp=Sv39.
   * Because MRET to S-mode cleared MPRV on a spec-compliant core, M-mode memory
   * accesses must use bare physical addresses and M-mode permissions. */

  /* 1. Verify M-mode load from page_a is NOT translated to page_b. */
  la   a0, page_a
  ld   s0, 0(a0)
  li   t0, 0x1111111122222222
  bne  s0, t0, fail_translated

  /* 2. Verify M-mode load from U=1 page_c is NOT S-mode permission-checked. */
  la   a1, page_c
  ld   s1, 0(a1)
  li   t0, 0x3333333344444444
  bne  s1, t0, fail_perm

  csrw satp, zero
  sfence.vma
  PASS

fail_translated:
  csrw mstatus, zero
  csrw satp, zero
  sfence.vma
  FAIL(1)

fail_perm:
  csrw mstatus, zero
  csrw satp, zero
  sfence.vma
  FAIL(2)

unexpected_trap:
  csrw mstatus, zero
  csrw satp, zero
  sfence.vma
  li   t1, CAUSE_LOAD_PAGE_FAULT
  beq  t0, t1, 1f
  FAIL(3)
1:
  FAIL(2)

fail_unexpected:
  csrw mstatus, zero
  csrw satp, zero
  sfence.vma
  FAIL(4)

fail_setup:
  csrw mstatus, zero
  csrw satp, zero
  sfence.vma
  FAIL(5)

  .section .data
  .align 12
l2_pt:
  .space 4096
  .align 12
l1_pt:
  .space 4096
  .align 12
l0_pt:
  .space 4096

  .align 12
page_a:
  .dword 0x1111111122222222
  .space 4088

  .align 12
page_b:
  .dword 0xdeadbeefcafebabe
  .space 4088

  .align 12
page_c:
  .dword 0x3333333344444444
  .space 4088
