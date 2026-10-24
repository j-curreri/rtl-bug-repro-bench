#include "test.h"

/* CBIE (bits 5:4) of menvcfg/senvcfg is WARL; 2'b10 is reserved and
 * must never be read back after a write. */
#define CSR_MENVCFG 0x30a
#define CSR_SENVCFG 0x10a

#define CHECK_CBIE(csr, n)      \
  li t0, 0x30;                  \
  csrc csr, t0;                 \
  li t0, 0x20;                  \
  csrs csr, t0;                 \
  csrr t1, csr;                 \
  andi t1, t1, 0x30;            \
  li t2, 0x20;                  \
  bne t1, t2, 1f;               \
  FAIL(n);                      \
1:

  .text
  .globl test_main
test_main:
  CHECK_CBIE(CSR_MENVCFG, 1)
  CHECK_CBIE(CSR_SENVCFG, 2)
  PASS
