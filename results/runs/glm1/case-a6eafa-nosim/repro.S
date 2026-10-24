/* repro.S
 *
 * Bug: HLVX succeeds even when the VS-stage page table lives in guest-physical
 * memory that the G-stage maps execute-only.  The implicit read of a VS-stage
 * PTE is an ordinary load for G-stage permission checks, so the walk must
 * raise a load guest-page fault (mcause 21).
 *
 * Walk chain exercised (all leaves are 1 GiB entries):
 *   TARGET_VA --VS 1GiB leaf--> GPA --G 1GiB leaf (RWX)--> HPA(target_page)
 * and the VS root page itself is placed in the G-stage EXECUTE-ONLY region:
 *   G leaf 1: GPA[0x40000000, 0x80000000) -> HPA 0x80000000+GPA[29:0], V|X only
 *
 * - Correct core: the implicit G-stage read of the VS PTE is not a valid load
 *   (exec-only leaf) => LOAD_GUEST_PAGE_FAULT (21) from trap_handler => PASS.
 * - Buggy core: the shared PTW leaf permission check lets HLVX pass the
 *   execute-only intermediate G leaf, the walk completes and HLVX returns the
 *   planted magic word => FAIL(4).
 *
 * Expected trap: LOAD_GUEST_PAGE_FAULT = 21 (LOAD_PAGE_FAULT = 13 accepted as
 * well, in case the fix reports the implicit read as a plain page fault).
 */

#include "test.h"
#include "hyp.h"

/* Magic word planted in target_page (32 bit: HLVX.WU zero-extends). */
#define MAGIC 0x0BADF00D

	.section .text
	.globl test_main

test_main:
	/* phase 0 = setup: any trap in here must FAIL */
	li	s3, 0

	PMP_ALLOW_ALL

	/* Keep everything strict: no MXR, no SUM, no virtualized MXR.
	 * mstatus (0x300): clear MXR (19), SUM (18) */
	li	t0, (1 << 19) | (1 << 18)
	csrrc	x0, 0x300, t0
	/* vsstatus (0x200): clear MXR (19), SUM (18) */
	csrrc	x0, 0x200, t0
	/* hstatus (0x600): SPVP = 0, so the VS-stage checks act as U-mode
	 * (our VS leaf sets U accordingly). */
	li	t0, 0x100
	csrrc	x0, 0x600, t0

	/* ---------------- page tables ---------------- */
	/* G-stage (Sv39x4, root 16 KiB g_root in DRAM):
	 *  leaf 0: GPAs [0, 1GiB)        -> DRAM base 0x80000000, R|W|X
	 *  leaf 1: GPAs [1GiB, 2GiB)     -> DRAM base 0x80000000, EXECUTE-ONLY
	 * Both are 1 GiB entries aligned to 1 GiB (ppn[17:0] == 0). */
	GIGA_LEAF(g_root, 0, 0x80000000, (PTE_V|PTE_R|PTE_W|PTE_X|PTE_U|PTE_A|PTE_D))
	GIGA_LEAF(g_root, 1, 0x80000000, (PTE_V|PTE_X|PTE_U|PTE_A|PTE_D))

	/* VS-stage (Sv39): VA [0, 1GiB) -> GPA [0, 1GiB) (1 GiB leaf, R|W|X|U).
	 * Only index 0 of vs_root is ever read. */
	GIGA_LEAF(vs_root, 0, 0x0, (PTE_V|PTE_R|PTE_W|PTE_X|PTE_U|PTE_A|PTE_D))

	/* Enable G-stage translation with g_root (VMID 0). */
	HGATP_ON

	/* Point vsatp at the VS root *through the execute-only G region*:
	 * GPA(vs_root) = HPA(vs_root) - 0x40000000, so the VS root PTEs are
	 * guest-physical memory that G-stage maps execute-only. */
	la	t2, vs_root
	li	t1, 1
	slli	t1, t1, 30		/* 0x40000000 */
	sub	t2, t2, t1
	VSATP_ON(t2)

	/* ---------------- critical section ---------------- */
	li	s3, 1

	/* TARGET_VA = HPA(target_page) - 0x80000000 (GPA region 0, < 2^30). */
	la	t2, target_page
	li	t1, 2
	slli	t1, t1, 30		/* 0x80000000 */
	sub	t2, t2, t1
	mv	a0, t2

	/* HLVX.WU: execute-only load through the two-stage translation.
	 *              hlvx.wu a1, 0(a0)
	 * imm[11:0]=0x683 funct3=4 rd=a1 rs1=a0 opcode=SYSTEM
	 * (binutils encodes exactly this word for the mnemonic). */
	.align	2
	.word	0x683545F3

	/* Reached only when HLVX did NOT trap -- this is the bug. */
	li	t0, MAGIC
	li	a0, ((4 << 1) | 1)	/* FAIL(4) */
	beq	a1, t0, fail_out
	li	a0, ((5 << 1) | 1)	/* FAIL(5): loaded something else */
fail_out:
	j	_halt

	/* ---------------- trap handler ---------------- */
	.align	2
	.globl	trap_handler
trap_handler:
	csrr	t5, mcause
	/* LOAD_GUEST_PAGE_FAULT = 21, LOAD_PAGE_FAULT = 13 */
	li	t0, 21
	beq	t5, t0, guest_fault
	li	t0, 13
	beq	t5, t0, guest_fault
j	fatal_trap
guest_fault:
	/* Only the critical HLVX walk may claim PASS. */
	li	t0, 1
	bne	s3, t0, fatal_trap
	PASS
fatal_trap:
	li	a0, ((2 << 1) | 1)	/* FAIL(2): unexpected trap */
	j	_halt

	/* ---------------- data ---------------- */
	HYP_TABLES

	.align	12
	.globl	target_page
target_page:
	.word	MAGIC