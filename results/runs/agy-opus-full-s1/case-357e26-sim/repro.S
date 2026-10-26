/*
 * Reproducer: PMP TOR entries must ignore pmpaddr[G-1:0] (G=1 here).
 *
 * With grain G=1, a pmpaddr written with bit 0 set behaves (in TOR/OFF mode)
 * as if bit 0 were 0 (priv spec: pmpaddr[G-1:0] read as zero in TOR/OFF and
 * the TOR range uses the effective value).
 *
 * Layout (D = 8-byte aligned address of `probe`, located above all code):
 *   entry 0: TOR, pmpaddr0 = (D>>2)|1, RWX  -> correct range [0, D)
 *   entry 1: TOR, pmpaddr1 = (D+8)>>2, ---  -> correct range [D, D+8)  (deny)
 *   entry 2: NAPOT all memory, RWX
 *
 * A U-mode load from D must therefore raise a load access fault (mcause 5).
 * The buggy core uses the raw bit 0, making entry 0 cover [0, D+4) so the
 * load at D is granted by entry 0 and no fault happens -> FAIL.
 */
#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* clear all pmp config first */
  csrw pmpcfg0, zero

  la   t1, probe
  srli t0, t1, 2
  ori  t0, t0, 1            /* lowest bit set */
  csrw pmpaddr0, t0

  addi t0, t1, 8
  srli t0, t0, 2
  csrw pmpaddr1, t0

  li   t0, -1
  csrw pmpaddr2, t0

  /* cfg: entry0 = TOR|RWX (0x0f), entry1 = TOR, no perms (0x08),
          entry2 = NAPOT|RWX (0x1f) */
  li   t0, 0x1f080f
  csrw pmpcfg0, t0
  sfence.vma

  /* sanity: M-mode reads of pmpcfg0 */
  csrr t2, pmpcfg0
  li   t0, 0x1f080f
  bne  t2, t0, fail_cfg

  la   s0, probe            /* address to probe in U-mode */
  li   s1, 0                /* fault flag */
  ENTER_MODE(0, user_code)

fail_cfg:
  FAIL(2)

  .align 2
user_code:
  /* Access just below the boundary: must be allowed by entry 0. */
  ld   t3, -8(s0)
  /* Access at the boundary: correct core -> load access fault. */
  .globl probe_insn
probe_insn:
  lw   t3, 0(s0)
  /* Reached only if no fault was raised (buggy core). */
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t4, mcause
  li   t5, 5                /* load access fault */
  beq  t4, t5, 1f
  li   t5, 8                /* ecall from U-mode: load was not blocked */
  beq  t4, t5, 2f
  FAIL(3)                   /* unexpected trap */
1:
  csrr t4, mepc
  la   t5, probe_insn
  bne  t4, t5, 3f
  PASS
2:
  FAIL(1)
3:
  FAIL(4)
4:
  FAIL(5)

  .section .data
  .align 12
pad:
  .dword 0x1111111111111111
  .align 3
probe:
  .dword 0x2222222222222222
  .dword 0x3333333333333333
