#include "test.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  # Zero out root page table (512 entries of 8 bytes = 4096 bytes)
  la t0, page_table_root
  li t1, 512
1:
  sd zero, 0(t0)
  addi t0, t0, 8
  addi t1, t1, -1
  bnez t1, 1b

  # Setup 1 GiB gigapage identity mapping for DRAM: 0x80000000 - 0xBFFFFFFF
  # VPN[2] = 2. Index = 2 * 8 = 16.
  # PPN = 0x80000.
  # Flags: D (0x80) | A (0x40) | X (0x08) | W (0x04) | R (0x02) | V (0x01) = 0xcf
  # Value = (0x80000 << 10) | 0xcf = 0x200000cf
  la t0, page_table_root
  li t1, 0x200000cf
  sd t1, 16(t0)

  # Enable Sv39 translation in satp
  srli t0, t0, 12
  li t1, 8
  slli t1, t1, 60
  or t0, t0, t1
  csrw satp, t0
  sfence.vma

  # Set MPRV = 1 in mstatus
  li t0, (1 << 17)
  csrs mstatus, t0

  # Return to S-mode.
  # RISC-V Privileged Architecture requires MRET returning to S-mode (mpp < M)
  # to clear mstatus.MPRV to 0.
  ENTER_MODE(1, smode_entry)

smode_entry:
  # In S-mode: execution runs via the Sv39 mapping at 0x80000000.
  # Trap back to M-mode via ecall.
  ecall

  FAIL(4)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 9 # Environment call from S-mode
  bne t0, t1, unexpected_trap

  # Software is running in M-mode handling the trap from S-mode.
  # Access CLINT at physical address 0x0200bff8 (mtime).
  #
  # On a correct core:
  #   MRET cleared MPRV to 0. M-mode loads are untranslated physical accesses,
  #   so reading CLINT succeeds.
  #
  # On this buggy core:
  #   MRET failed to clear MPRV. Because MPRV is still 1 and MPP is S,
  #   the load is translated through satp, where 0x02000000 is unmapped.
  #   This triggers a Load Page Fault (mcause 13), trapping to unexpected_trap.
  li t0, 0x0200bff8
  ld t1, 0(t0)

  # Verify MPRV is 0 in mstatus
  csrr t0, mstatus
  li t1, (1 << 17)
  and t0, t0, t1
  bnez t0, bug_detected

  PASS

bug_detected:
  FAIL(1)

unexpected_trap:
  FAIL(2)

  .data
  .align 12
page_table_root:
  .space 4096
