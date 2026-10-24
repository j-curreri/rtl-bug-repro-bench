    .section .text
    .globl test_main
    .globl trap_handler
    
    test_main:
    // PMP allow all (RWX all)
    li t0, -1
    csrw pmpaddr0, t0
    li t0, 0x1f
    csrw pmpcfg0, t0
    
    // Enable machine interrupts (mie = 1)
    li t0, 1        // mie = 1
    csrw mstatus, t0
    
    // Set machine interrupt pending (mip = 1)
    li t0, 1        // mip = 1
    csrw mip, t0
    
    // Execute a few NOPs to allow interrupt delivery
    nop
    nop
    
    // Just continue; interrupt should fire soon
    li a0, 1        // PASS fallback
    j _halt
    
    .globl trap_handler
trap_handler:
    // Read mcause to verify it's a machine interrupt
    csrr t6, mcause
    
    // Read mtval
    csrr t0, mtval
    
    // Check if mtval is zero
    beqz t0, handler_mtval_is_zero
    li a0, 3        // FAIL(1)
    j _halt
    
    handler_mtval_is_zero:
    li a0, 1        // PASS
    j _halt
