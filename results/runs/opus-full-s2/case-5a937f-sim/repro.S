#include "test.h"

/* CBIE (bits 5:4) of menvcfg/senvcfg is WARL; writing the reserved
 * encoding 2'b10 must never leave 2'b10 readable. */
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
1:                              \
  li t0, 0x30;                  \
  csrc csr, t0;                 \
  li t0, 0x20;                  \
  csrw csr, t0;                 \
  csrr t1, csr;                 \
  andi t1, t1, 0x30;            \
  li t2, 0x20;                  \
  bne t1, t2, 2f;               \
  FAIL(n + 10);                 \
2:

.text
.global test_main
test_main:
  CHECK_CBIE(menvcfg, 1)
  CHECK_CBIE(senvcfg, 2)
  PASS
