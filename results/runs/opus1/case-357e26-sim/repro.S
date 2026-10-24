#include "test.h"

/* TOR entry whose pmpaddr has bit 0 set: with G=1 that bit must be ignored
 * (it reads as 0), so the entry ends exactly at `target`. A U-mode load of
 * `target` must therefore match the next (RWX) entry, not the deny entry. */

  .text
  .globl test_main
test_main:
  /* entry0: TOR [0, deny_start) RWX -> code/data below */
  la t0, deny_start
  srli t0, t0, 2
  csrw pmpaddr0, t0
  /* entry1: TOR [deny_start, target) no perms; write with bit 0 set */
  la t0, target
  srli t0, t0, 2
  ori t0, t0, 1
  csrw pmpaddr1, t0
  /* entry2: TOR [target, top) RWX */
  li t0, -1
  csrw pmpaddr2, t0
  /* cfg: e0 = TOR|RWX (0x0f), e1 = TOR (0x08), e2 = TOR|RWX (0x0f) */
  li t0, 0x0f080f
  csrw pmpcfg0, t0
  sfence.vma
  fence

  /* readback must show bit 0 cleared (TOR) */
  csrr t1, pmpaddr1
  andi t1, t1, 1
  bnez t1, readback_bad

  li s0, 0
  ENTER_MODE(0, umode)

readback_bad:
  FAIL(2)

umode:
  la t1, target
  lw t2, 0(t1)
  li s0, 1
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 8              /* ecall from U */
  bne t6, t5, bad_trap
  beqz s0, bad_trap
  PASS
bad_trap:
  FAIL(1)

  .data
  .align 4
deny_start:
  .dword 0
target:
  .dword 0x1234
  .dword 0
