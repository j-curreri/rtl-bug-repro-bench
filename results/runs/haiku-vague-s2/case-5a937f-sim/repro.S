#include "test.h"

# menvcfg.CBIE (bits 5:4) is a WARL field. Encoding 2'b10 is reserved by the
# Zicbom spec and must not be held by the register. The buggy core stores it
# anyway (riscv::CBIE_RSVD), so reading menvcfg back shows CBIE == 2.

    .section .text
    .globl test_main
test_main:
    li   t0, 0x20              # CBIE = 2'b10 (reserved)
    csrw menvcfg, t0
    csrr t1, menvcfg
    srli t1, t1, 4
    andi t1, t1, 3             # t1 = CBIE as read back
    li   t2, 2
    beq  t1, t2, 1f           # reserved value retained -> bug
    PASS
1:
    FAIL(1)
