#include "test.h"

#define CSR_TSELECT 0x7a0
#define CSR_TDATA1  0x7a1
#define CSR_TDATA2  0x7a2

  .globl test_main
  .globl trap_handler

test_main:
  /* Register trap handler */
  la t0, trap_handler
  csrw mtvec, t0

  /* Select trigger 0 */
  li t0, 0
  csrw CSR_TSELECT, t0

  /* Set NAPOT address:
   * target_instr is 64-byte aligned (bits 5:0 are 0).
   * Setting the low 3 bits to 1 (value 7 = 0b0111) encodes an 8-byte
   * NAPOT range [target_instr, target_instr + 7].
   */
  la t0, target_instr
  ori t0, t0, 7
  csrw CSR_TDATA2, t0

  /* Configure mcontrol6 trigger:
   * type   = 6 (mcontrol6, bits 63:60)
   * match  = 1 (NAPOT, bits 10:7 -> 1 << 7 = 0x80)
   * m      = 1 (M-mode, bit 6 -> 1 << 6 = 0x40)
   * action = 0 (breakpoint exception, bits 15:12)
   * execute= 1 (instruction address match, bit 2 -> 1 << 2 = 0x04)
   *
   * Value: (6ULL << 60) | 0x80 | 0x40 | 0x04 = 0x60000000000000C4
   */
  li t0, 6
  slli t0, t0, 60
  ori t0, t0, 0xC4
  csrw CSR_TDATA1, t0

  /* Jump to target instruction */
  j target_instr

  .align 6
target_instr:
  nop
  nop

  /* On a core adhering to the RISC-V Sdtrig spec, an execution breakpoint
   * exception (mcause = 3) is raised before target_instr executes, jumping
   * to trap_handler.
   * On this buggy core, napot_match64 checks ((base & (base + 1)) == 0),
   * which fails for any address in DRAM (>= 0x80000000), so the trigger never
   * fires and execution falls through to here.
   */
  FAIL(2)

  .align 2
trap_handler:
  /* Disable trigger */
  csrw CSR_TDATA1, zero

  /* Verify the trap was a breakpoint exception (mcause == 3) */
  csrr t0, mcause
  li t1, 3
  bne t0, t1, 1f
  PASS

1:
  FAIL(3)
