    .section .text
    .globl test_main
    test_main:
    .align 2
    la sp, _stack_top

    /* Allow all memory access */
    li t0, -1
    csrw pmpaddr0, t0
    li t0, 0x1f
    csrw pmpcfg0, t0

    /* Write hgatp with MODE_SV (supported), vmid=1, ppn=0 */
    li t0, 0
    li t1, 8          /* MODE_SV = ModeSv39 = 8 */
    or t0, t0, t1    /* t0 = MODE_SV in mode bits */
    csrw hgatp, t0

    /* Read hgatp back */
    csrr t2, hgatp

    /* Write hgatp with ModeSv32 (unsupported), same vmid=1, ppn=0 */
    li t0, 0
    li t3, 1          /* ModeSv32 = 1 */
    or t0, t0, t3    /* t0 = ModeSv32 in mode bits */
    csrw hgatp, t0

    /* Read hgatp back */
    csrr t4, hgatp

    /* Compare t2 and t4: if equal (buggy), FAIL; if different (correct), PASS */
    bne t2, t4, .Lpass  /* if t2 != t4, PASS (correct core) */
.Lfail:
    li a0, 3         /* FAIL(1) */
    j _halt
.Lpass:
    li a0, 1         /* PASS */
    j _halt
