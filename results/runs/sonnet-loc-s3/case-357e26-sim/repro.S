#include "test.h"
.globl test_main
.globl trap_handler
.align 2
test_main:
  la t1, buf
  srli t2, t1, 2
  csrw pmpaddr0, t2        # entry 0: NA4 over buf, no permissions
  li t0, -1
  csrw pmpaddr1, t0
  li t0, (0x1f << 8) | 0x10
  csrw pmpcfg0, t0         # entry1 NAPOT RWX all; entry0 NA4 ---
  ENTER_MODE(0, umode)
.align 2
umode:
  la t1, buf
  lw t2, 0(t1)             # must fault (load access fault)
  li a0, 1
  ecall
.align 2
trap_handler:
  csrr t0, mcause
  li t1, 5
  bne t0, t1, 1f
  PASS
1:
  FAIL(1)
.align 3
buf: .dword 0
