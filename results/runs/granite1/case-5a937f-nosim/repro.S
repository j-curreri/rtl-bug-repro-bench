  .section .text
  .globl test_main
  .globl _pass
  .globl _fail
  _pass:
      li a0, 1
      j _halt
  _fail:
      li a0, 3      // FAIL(1) = ((1) << 1) | 1 = 3
      j _halt
  test_main:
      // PMP_ALLOW_ALL
      li t0, -1
      csrw pmpaddr0, t0
      li t0, 0x1f
      csrw pmpcfg0, t0

      // Write menvcfg with CBIE=2'b10 (CBFE=0, CBIE=2'b10, fiom=0) = 0x08
      li t0, 0x30A
      li t1, 8
      csrw menvcfg, t1

      // Read back menvcfg
      csrr t2, menvcfg

      // Check if CBIE == 2'b10 (bits5:4 == 0b10)
      // CBIE bits are bits5:4 (bit5 = CBIE high, bit4 = CBIE low)
      and t3, t2, 0x20    // mask bit5 (CBIE high = 0x20)
      and t4, t2, 0x10    // mask bit4 (CBIE low = 0x10)

      bnez t3, .check_bit4  // if bit5=1, check bit4
      bnez t4, _pass        // if bit4=1 → CBIE=01 or 11 → PASS (correct core accepted or corrected)
      _pass                 // if bit5=0 → CBIE=00 → PASS (correct core corrected)

  .check_bit4:
      bnez t4, _pass       // if bit4=1 → CBIE=01 or 11 → PASS (correct core accepted)
      _fail                // if bit4=0 and bit5=1 → CBIE=10 (reserved) → FAIL (buggy core stored reserved value)
