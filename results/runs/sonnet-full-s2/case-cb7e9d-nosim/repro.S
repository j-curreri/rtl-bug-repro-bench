#include "test.h"
  .globl test_main
  .globl trap_handler
  .align 2
trap_handler:
  csrr t5, mcause
  li t4, 3
  bne t5, t4, bad
  li s1, 1
  csrw tdata1, x0       # disable trigger so the load retries cleanly
  mret
bad:
  FAIL(127)

test_main:
  PMP_ALLOW_ALL
  li s1, 0
  csrw tselect, x0
  la t1, buf
  li t2, 0xfff
  not t2, t2
  and t1, t1, t2        # 4KiB aligned base
  addi t1, t1, 0x400    # inside, aligned to 0x80
  li t2, 0x7f
  not t2, t2
  and t1, t1, t2
  ori t0, t1, 0x3f      # NAPOT encoding, trailing ones
  csrw tdata2, t0
  li t0, 6
  slli t0, t0, 60
  ori t0, t0, 0x41      # m=1 (bit6), load=1 (bit0)
  li t3, 1<<7           # match=1 (NAPOT)
  or t0, t0, t3
  csrw tdata1, t0
  ld a1, 0(t1)          # within range -> must trigger
  fence
  beqz s1, fail1
  PASS
fail1:
  FAIL(1)

  .section .data
  .align 12
buf: .space 8192
