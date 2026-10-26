#include "test.h"
# UBE is a WARL endianness field. This configuration implements big-endian
# accesses (MBE is honored), so UBE=1 is a legal value and must read back as 1
# after a write, independent of MBE (which stays 0 here).
  .section .text
  .globl test_main
test_main:
  li t0, (1 << 6)            # UBE
  csrc mstatus, t0           # start from UBE=0
  csrs mstatus, t0           # write UBE=1
  csrr t1, mstatus
  andi t1, t1, (1 << 6)
  beqz t1, 1f                # UBE read back as 0 -> bug
  csrc mstatus, t0           # restore UBE=0
  PASS
1:
  csrc mstatus, t0
  FAIL(1)
