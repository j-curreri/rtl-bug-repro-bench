#include "test.h"
    .text
    .globl test_main
test_main:
    csrr t1, mstatus
    srli t1, t1, 34
    andi t1, t1, 3
    bnez t1, 1f
    /* Also try writing SXL; must stay zero */
    li t2, (3 << 34)
    csrs mstatus, t2
    csrr t1, mstatus
    srli t1, t1, 34
    andi t1, t1, 3
    bnez t1, 2f
    PASS
1:  FAIL(1)
2:  FAIL(2)
