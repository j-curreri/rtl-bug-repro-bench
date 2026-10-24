    .section .text
    .globl test_main
test_main:
    la t0, trap_handler
    csrw mtvec, t0
    ebreak

    .globl trap_handler
trap_handler:
    csrr t1, mtval
    li t2, 0
    beq t1, t2, mret_pass

    li a0, 3      # FAIL(1) = (((1) << 1) | 1) = 3
    j _halt

mret_pass:
    mret
    li a0, 1      # PASS = (((0) << 1) | 1) = 1
    j _halt
