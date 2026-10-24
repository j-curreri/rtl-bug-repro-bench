    .data
    g_root: .space 16384

    .text
    .globl test_main
    test_main:
      PMP_ALLOW_ALL
      HGATP_ON

      # Write HGATP with ModeSv48 = 9 (unsupported for MODE_SV = 8 = ModeSv39)
      # Format: [mode:4][warl0:2][vmid:14][ppn:44]
      # SATP_SV39 = 8 << 60, ModeSv48 = 9 << 60 = 0x9000000000000000
      li t1, 0x9000000000000000
      csrw hgatp, t1

      # Read back HGATP
      csrr t2, hgatp

      # Extract mode field (bits 63:60) -> t3[3:0]
      srli t3, t2, 60
      li t4, 9

      # Mask to 4 bits to avoid high bits from the shift
      and t3, t3, 0xF
      and t4, t4, 0xF

      bne t3, t4, fail_label

      PASS

      fail_label:
      FAIL(1)
