#include "test.h"

/* CHECK(n, csr, wval, expect): write wval to csr, read it back, FAIL(n) on mismatch. */
#define CHECK(n, csr, wval, expect)  \
  li t0, wval;                       \
  csrw csr, t0;                      \
  csrr t1, csr;                      \
  li t2, expect;                     \
  beq t1, t2, 1f;                    \
  FAIL(n);                           \
1:

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  CHECK(1, medeleg, -1, 0xB1FF)
  CHECK(2, mideleg, -1, 0x222)
  CHECK(3, mie, -1, 0xAAA)
  CHECK(4, mcounteren, -1, 0xFFFFFFFF)
  CHECK(5, mcountinhibit, -1, 0x1FD)
  CHECK(6, mepc, 0x1003, 0x1002)

  # 7: W=1,R=0 is a reserved PMP encoding and must not be readable back
  li t0, 0x02
  csrw pmpcfg0, t0
  csrr t1, pmpcfg0
  andi t1, t1, 3
  li t2, 2
  bne t1, t2, 1f
  FAIL(7)
1:
  li t0, 0x1f
  csrw pmpcfg0, t0

  # 8: stvec mode 2 is reserved: base must survive, mode must be 0 or 1
  li t0, 0x80000002
  csrw stvec, t0
  csrr t1, stvec
  li t2, 0x80000000
  srli t3, t1, 2
  slli t3, t3, 2
  bne t3, t2, 1f
  andi t1, t1, 2
  beqz t1, 2f
1:
  FAIL(8)
2:

  # 9: sepc bit 1 is writable with C
  CHECK(9, sepc, 0x2003, 0x2002)

  # 10: mstatus.MPP=2 (reserved) must keep the old MPP (U=0 here)
  csrw mstatus, zero
  li t0, (2 << 11)
  csrw mstatus, t0
  csrr t1, mstatus
  srli t1, t1, 11
  andi t1, t1, 3
  beqz t1, 1f
  FAIL(10)
1:
  csrw mstatus, zero

  # 11: sstatus writes must hit only the sstatus fields (low 32 bits)
  csrw mstatus, zero
  li t0, -1
  csrw sstatus, t0
  csrr t1, mstatus
  li t2, 0x000C6122
  slli t1, t1, 32
  srli t1, t1, 32
  beq t1, t2, 1f
  FAIL(11)
1:
  csrw mstatus, zero

  # 12: mstatus writable fields (low 32 bits), SD/UXL/SXL excluded
  csrw mstatus, zero
  li t0, -1
  csrw mstatus, t0
  csrr t1, mstatus
  slli t1, t1, 32
  srli t1, t1, 32
  li t2, 0x007E79EA
  beq t1, t2, 1f
  FAIL(12)
1:
  csrw mstatus, zero

  # 13: SIE is not readable through mie when mideleg is clear
  csrw mideleg, zero
  csrw mie, zero
  li t0, -1
  csrw sie, t0
  csrr t1, mie
  beqz t1, 1f
  FAIL(13)
1:

  # 14: satp with an unsupported mode (Sv48) must not be accepted
  li t0, (9 << 60)
  csrw satp, t0
  csrr t1, satp
  beqz t1, 1f
  FAIL(14)
1:

  PASS

  .globl trap_handler
  .align 2
trap_handler:
  FAIL(100)
