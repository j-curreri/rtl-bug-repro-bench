#include "test.h"

/* Reproducer for: Sdtrig mcontrol6 address-match triggers in NAPOT mode (match = 1) do not
 * fire at ordinary addresses. A NAPOT execute breakpoint covering the instruction at `pos`
 * must trap with mcause 3 at `pos`; on the buggy core it does not trap and the program fails.
 *
 * tdata2 = base | 0x7 encodes a 16-byte NAPOT region at `base`. `pos` is placed at that base,
 * so it lies inside the region under any size interpretation of the encoding. */

  .option norvc
  .section .data
  .align 3
last_cause: .dword 0
last_epc:   .dword 0

  .section .text
  .globl trap_handler
  .align 2
trap_handler:
  csrr t4, mcause
  csrr t5, mepc
  la t3, last_cause
  sd t4, 0(t3)
  la t3, last_epc
  sd t5, 0(t3)
  addi t5, t5, 4
  csrw mepc, t5
  mret

/* Arm trigger 0 as an M-mode execute breakpoint on the NAPOT region encoded in tdata2 = \addr_reg */
.macro ARM_NAPOT_EXEC addr
  li t0, 0
  csrw tselect, t0
  csrw tdata1, x0
  la t0, \addr
  andi t0, t0, -16
  ori t0, t0, 7
  csrw tdata2, t0
  li t0, ((6 << 60) | (1 << 7) | 0x44)
  csrw tdata1, t0
  nop
  nop
  nop
  nop
.endm

.macro DISARM_0
  li t0, 0
  csrw tselect, t0
  csrw tdata1, x0
  nop
  nop
.endm

  .globl test_main
test_main:
  # Control: the region is around a data word, so the code at `ctl` must not trap.
  ARM_NAPOT_EXEC dat
  .balign 16
ctl:
  nop
  la t3, last_cause
  ld t4, 0(t3)
  bnez t4, 1f
  DISARM_0
  j 2f
1:
  FAIL(2)
2:

  # Positive: the region's base is `pos`; the breakpoint must trap at `pos`.
  ARM_NAPOT_EXEC pos
  .balign 16
pos:
  nop
  la t3, last_cause
  ld t4, 0(t3)
  li t5, 3
  bne t4, t5, 3f
  la t3, last_epc
  ld t4, 0(t3)
  la t5, pos
  bne t4, t5, 3f
  DISARM_0
  PASS
3:
  DISARM_0
  FAIL(1)

  .section .data
  .align 3
dat: .dword 0x1234
