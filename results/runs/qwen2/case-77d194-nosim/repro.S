/* Reproducer for the hgatp unsupported-MODE write bug.
 *
 * Bug (per report): writing hgatp with an unsupported MODE value is ignored
 * entirely -- none of the other fields (PPN, VMID) change. The hypervisor
 * spec says this is NOT how it should behave (unlike satp): hgatp's fields
 * are WARL in the normal way, so on a write with an unsupported MODE the MODE
 * field keeps its prior value while PPN and VMID are updated from the written
 * value.
 *
 * This core supports only MODE in {0=off, 8=Sv39x4}. Any other MODE value is
 * unsupported. We therefore:
 *   1. put hgatp in a known state: MODE=off, PPN=0, VMID=0  (value 0)
 *   2. write an UNSUPPORTED MODE (1) with PPN=8 and VMID=5
 *   3. read it back and require PPN==8 and VMID==5
 *
 * Correct core: PPN and VMID are updated  -> PASS
 * Buggy core  : the whole write is ignored, PPN/VMID stay 0 -> FAIL
 *
 * hgatp (this core, XLEN=64) layout:
 *   MODE [63:60]  (4 bits)   supported: 0 (off) and 8 (Sv39x4)
 *   WARL [59:58]  (2 bits)
 *   VMID [57:44]  (14 bits)
 *   PPN  [43:0]   (44 bits)  PPN[1:0] hardwired 0
 */
#include "test.h"

	.section .text
	.globl test_main
test_main:
	/* 1. known clean state: MODE=off (supported), PPN=0, VMID=0.
	 *    MODE=off is a supported value, so this write is applied in full. */
	li	t0, 0
	csrw	hgatp, t0

	/* sanity: the supported write must have taken effect (register == 0) */
	csrr	t0, hgatp
	bnez	t0, fail_init

	/* 2. write an UNSUPPORTED MODE (1) with PPN=8 and VMID=5.
	 *    value = (MODE<<60) | (VMID<<44) | PPN = 0x1000_5000_0000_0008 */
	li	t0, 0x1000500000000008
	csrw	hgatp, t0

	/* 3. read back and inspect PPN and VMID */
	csrr	t0, hgatp

	/* PPN = bits [43:0]; expect 8 */
	li	t1, 0xfffffffffffffff	/* 44 ones */
	and	t2, t0, t1
	li	t3, 8
	bne	t2, t3, fail_ppn

	/* VMID = bits [57:44]; extract by >>44 and keep 14 bits; expect 5 */
	srl	t0, t0, 44
	li	t1, 0x3fff
	and	t2, t0, t1
	li	t3, 5
	bne	t2, t3, fail_vmid

	/* PPN and VMID were updated despite the unsupported MODE: correct */
	PASS

fail_init:
	FAIL(10)
fail_ppn:
	FAIL(11)
fail_vmid:
	FAIL(12)
