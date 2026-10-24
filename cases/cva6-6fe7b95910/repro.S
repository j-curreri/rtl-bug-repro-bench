/* With PMP grain G=1 (8 bytes), pmpaddr bit 0 must not move a TOR boundary.
 * Entry 0: TOR [0, probe) RWX, written with bit 0 set (naive decode puts the top at probe+4).
 * Entry 1: NAPOT all memory, read-only. A U-mode store to `probe` must fault. */
#include "test.h"
  .text
  .globl test_main
test_main:
  la t0, probe
  srli t0, t0, 2
  ori t0, t0, 1
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  li t0, (0x19 << 8) | 0x0f    /* entry1 NAPOT R, entry0 TOR RWX */
  csrw pmpcfg0, t0
  ENTER_MODE(0, in_umode)
in_umode:
  la t0, probe
  sw zero, 0(t0)
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 7                     /* store access fault */
  bne t0, t1, 1f
  csrr t0, mtval
  la t1, probe
  bne t0, t1, 2f
  PASS
1: FAIL(1)
2: FAIL(2)

  .data
  .align 4
  .space 64
probe: .dword 0
