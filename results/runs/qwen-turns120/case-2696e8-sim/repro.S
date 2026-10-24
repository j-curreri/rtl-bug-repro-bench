#include "hyp.h"

/*
 * Bug: after an HLVX read from a G-stage execute-only page, a plain HLV load
 * from the same page also succeeds.  The DTLB-hit load path in cva6_mmu.sv
 * computes g_load_access_ok (r || x&(mxr|hlvx)) but never uses it; it only
 * checks the G-PTE U bit (d_g_st_access_err).  The correct core must raise a
 * LOAD guest-page fault (mcause=21) for the plain load.
 *
 * G-stage-only setup (vsatp stays BARE): the single G page is the execute-only
 * 1G leaf covering DRAM, and the G root itself is read directly (HPA) so it is
 * not subject to that execute-only PTE.  This isolates the R/X bug: the G-PTE
 * U bit is set, so the buggy U-only check passes, while a plain load still lacks
 * read permission on an execute-only page.
 *
 *   - g_root[2]: 1G leaf, identity to 0x8000_0000, execute-only (X, no R), U set.
 *   - hlvx the page: allowed (execute treated as read for hlvx), populates the
 *     DTLB with the execute-only G PTE.
 *   - Plain hlv the same page:
 *       correct core -> LOAD guest-page fault (mcause 21) at hlv_w -> PASS
 *       buggy core   -> load succeeds -> fall through to FAIL
 */

HYP_TABLES

    .data
    .align 12
guest_data:
    .dword 0x55aa55aa55aa55aa

/* G-stage execute-only, user, accessed: V|X|U|A = 0x59 */
    .equ G_XOUL, (PTE_V | PTE_X | PTE_U | PTE_A)

    .text
    .global test_main
test_main:
    PMP_ALLOW_ALL
    /* G root[2]: 1G identity to 0x8000_0000, execute-only (buggy per PTE) */
    GIGA_LEAF(g_root, 2, 0x80000000, G_XOUL)
    HGATP_ON
    /* hstatus.SPVP = S (guest supervisor privilege) */
    li   t0, HSTATUS_SPVP
    csrs hstatus, t0

    la   t0, guest_data        /* GPA (identity-mapped to HPA) */
hlvx_insn:
    .word 0x6832c373          /* hlvx.w t1, 0(t0): legal, fills DTLB */
hlv_w:
    hlv.w  t2, 0(t0)          /* plain load: correct core faults here */

    /* Reached only if the plain load did NOT fault -> buggy core. */
    FAIL(1)

    .align 2
    .global trap_handler
trap_handler:
    csrr t0, mcause
    csrr t1, mepc
    li   t2, 21               /* LOAD_GUEST_PAGE_FAULT */
    bne  t0, t2, fail_trap
    la   t3, hlv_w
    bne  t1, t3, fail_trap
    PASS
fail_trap:
    FAIL(127)
