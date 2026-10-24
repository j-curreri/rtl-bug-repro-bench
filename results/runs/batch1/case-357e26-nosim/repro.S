#include "test.h"
  .globl test_main
  .globl trap_handler
test_main:
  la t1, buf
  srli t2, t1, 2
  csrw pmpaddr0, t2          # A (OFF)
  addi t1, t1, 16
  srli t2, t1, 2
  ori t2, t2, 1              # B | 1, TOR (G=1: bit0 ignored)
  csrw pmpaddr1, t2
  li t2, -1
  csrw pmpaddr2, t2
  li t2, 0x1f0800            # cfg2=NAPOT RWX, cfg1=TOR no perms, cfg0=OFF
  csrw pmpcfg0, t2
  ENTER_MODE(0, user)
  .align 2
user:
  la t1, buf
  ld t0, 16(t1)              # at B: outside the TOR region, must be allowed
  ecall
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 8
  bne t0, t1, 1f
  PASS
1:
  FAIL(1)
  .data
  .align 4
buf: .space 64
