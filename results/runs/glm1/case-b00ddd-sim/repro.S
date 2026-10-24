// Bug reproducer for CVA6 (cv64a6_imafdch_sv39, CV-X-IF coprocessor interface
// enabled): an illegal instruction executed in VS-mode must trap into M-mode
// with mstatus.GVA = 0.  The riscv privileged spec says mstatus.GVA is set to 1
// only when a trap writes a guest virtual address to mtval; for an
// illegal-instruction trap mtval holds the instruction encoding, so GVA must
// stay 0.  On this core the illegal instruction is offloaded through the
// CV-X-IF interface and the resulting exception carries gva = v, so the trap
// reports mstatus.GVA = 1.
//
// Program: enter VS-mode, execute an illegal instruction, trap into M-mode and
// check mstatus.  PASS iff mcause is illegal-instruction, the trap came from
// VS-mode (mstatus.MPV = 1) and GVA = 0.

#include "hyp.h"

	.section .text.init
	.globl test_main

test_main:
	/* Let VS-mode access all of memory. */
	PMP_ALLOW_ALL

	/* mtvec was set to trap_handler by crt.S.  G-stage stays in Bare mode
	 * (hgatp.MODE = 0), so guest-physical addresses are plain physical. */
	ENTER_VS(vs_code)

	.align 2
vs_code:
	.word 0xFFFFFFFF	/* illegal instruction -> trap into M-mode */

	/* Reached only if no trap was taken at all. */
	FAIL(3)

	.align 2
	.globl trap_handler
trap_handler:
	csrr t5, mcause
	li t6, 2		/* cause 2 = illegal instruction */
	bne t5, t6, 2f

	csrr t5, mstatus
	/* The trap must have come from VS-mode: mstatus.MPV = 1 (bit 39). */
	li t6, MSTATUS_MPV
	and t6, t5, t6
	beqz t6, 1f

	/* GVA must be 0 for an illegal-instruction trap (bit 38). */
	li t6, MSTATUS_GVA
	and t5, t5, t6
	beqz t5, 3f		/* GVA = 0 -> correct core */
	FAIL(1)			/* GVA = 1 -> the bug */

3:
	PASS

1:
	FAIL(4)			/* trap did not come from VS-mode */

2:
	FAIL(2)			/* unexpected trap cause */