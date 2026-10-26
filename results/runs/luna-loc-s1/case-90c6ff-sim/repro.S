#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  la      t0, root
  la      t1, l1
  srli    t1, t1, 12
  slli    t1, t1, 10
  ori     t1, t1, 1
  sd      t1, 16(t0)
  la      t0, l1
  la      t1, l0
  srli    t1, t1, 12
  slli    t1, t1, 10
  ori     t1, t1, 1
  sd      t1, 0(t0)
  la      s0, l0
  li      s1, 0x80000000
  li      s2, 512
  li      s4, 4096
1:
  srli    t0, s1, 12
  slli    t0, t0, 10
  ori     t0, t0, 0xcf
  sd      t0, 0(s0)
  addi    s0, s0, 8
  add     s1, s1, s4
  addi    s2, s2, -1
  bnez    s2, 1b
  la      t0, root
  srli    t0, t0, 12
  li      t1, (8 << 60) | (1 << 44)
  or      t0, t0, t1
  csrw    satp, t0
  sfence.vma x0, x0
  li      t0, (3 << 11)
  csrc    mstatus, t0
  li      t0, (1 << 11)
  csrs    mstatus, t0
  la      t0, s_test
  csrw    mepc, t0
  mret

s_test:
  la      s3, target_page
  ld      t1, 0(s3)
  li      t2, 0x1111222233334444
  bne     t1, t2, fail_1
  la      t3, l0
  la      t4, target_page
  srli    t4, t4, 12
  andi    t4, t4, 0x1ff
  slli    t4, t4, 3
  add     t3, t3, t4
  la      t5, alt_page
  srli    t5, t5, 12
  slli    t5, t5, 10
  ori     t5, t5, 0xcf
  sd      t5, 0(t3)
  fence   rw, rw
  li      t0, 0
  sfence.vma s3, t0
  ld      t1, 0(s3)
  li      t2, 0x1111222233334444
  bne     t1, t2, fail_2
  PASS
fail_1:
  FAIL(1)
fail_2:
  FAIL(2)

  .section .data
  .align 12
root: .zero 4096
  .align 12
l1:   .zero 4096
  .align 12
l0:   .zero 4096
  .align 12
target_page:
  .dword 0x1111222233334444
  .zero 4088
  .align 12
alt_page:
  .dword 0x5555666677778888
  .zero 4088
