    .section .text
    .globl test_main


test_main:
    // PMP_ALLOW_ALL
    li t0, -1
    csrw pmpaddr0, t0
    li t0, 0x1f
    csrw pmpcfg0, t0

    // Write CBIE_RSVD (2'b10) to MENVCFG first
    li t1, 0x20      // Write CSR value: CBIE=10 (bits 5:4), CBFE=0 (bit 6) = 0x20
    csrw menvcfg, t1

    // Write CBIE_FLUSH (2'b01) to MENVCFG
    li t2, 0x10      // Write CSR value: CBIE=01 (bits 5:4), CBFE=0 = 0x10
    csrw menvcfg, t2

    // Read back MENVCFG CSR
    csrr t3, menvcfg

    // Extract CBIE field (bits 5:4 of CSR) = (CSR >> 4) & 3
    srl t4, t3, 4    // t4 = CSR >> 4
    and t4, t4, 3    // t4 = CBIE (bits 0:1 of (CSR>>4))

    // CBIE_RSVD = 2'b10 = 2
    li t5, 2

    // If CBIE == CBIE_RSVD (2), FAIL(1); else PASS
    bne t4, t5, pass
    fail1:
    li a0, 3          // FAIL(1) = (1 << 1) | 1 = 3
    j _halt

pass:
    li a0, 1          // PASS = 1
    j _halt
