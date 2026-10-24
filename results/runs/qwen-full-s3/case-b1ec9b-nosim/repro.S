/* repro.S - bug reproducer: MRET returning to S-mode must clear MPRV.
 *
 * The privileged spec says MRET clears MPRV when the returned-to mode is less
 * privileged than M.  This core only clears it when RVH is configured, but this
 * build has the hypervisor extension disabled, so MPRV survives the MRET.
 *
 * Flow:
 *   M-mode: build an Sv39 table mapping only [0x80000000, 0x80100000) with
 *           supervisor permissions (U=0); enable Sv39; set MPRV=1 and MPP=S;
 *           MRET to S-mode.
 *   S-mode: ecall -> M-mode trap (mcause = 8).
 *   M-mode handler: the trap set MPP=M, so put MPP=S back.  Then do an M-mode
 *           load from physical address 0x80100000, which is *not* mapped in
 *           the page table:
 *             - correct core: MPRV was cleared by MRET -> M-mode access is
 *               untranslated -> plain physical load -> succeeds -> PASS.
 *             - buggy core: MPRV still 1 with MPP=S -> M-mode access is
 *               translated and permission-checked as S-mode -> page fault ->
 *               re-trap with mcause != 8 -> FAIL.
 */
#include "test.h"

    .text
    .globl test_main

    /* VA/PA 0x80100000: inside DRAM, just above the mapped 1 MiB window. */
    .equ UNMAPPED_VA, 0x80100000

test_main:
    PMP_ALLOW_ALL

    /* ---- Build Sv39 tables ----
     *   root[2]   -> pt_l1                     (non-leaf: V|X)
     *   pt_l1[0]  -> 1 MiB leaf, PA 0x80000000 (V|R|W|X|A|D, U=0)
     * 0x80000000 >> 30 = 2, 0x80000000 >> 21 = 0x400 (vpn1 = 0).
     */
    la   t0, pt_root
    addi t0, t0, 16            /* &root[2] */
    la   t1, pt_l1
    srli t1, t1, 12
    slli t1, t1, 10
    ori  t1, t1, 0x9           /* V|X */
    sd   t1, 0(t0)

    la   t0, pt_l1             /* &pt_l1[0] */
    li   t1, 0x80000           /* PPN of 0x80000000 */
    slli t1, t1, 10
    ori  t1, t1, 0xcf         /* V|R|W|X|A|D, U=0 */
    sd   t1, 0(t0)

    /* Enable Sv39 (satp mode = 8). */
    la   t0, pt_root
    srli t0, t0, 12
    li   t1, 8
    slli t1, t1, 60
    or   t0, t0, t1
    csrw satp, t0
    sfence.vma

    /* MRET to S-mode with MPRV=1.  The spec requires MRET to clear MPRV
     * because the returned-to mode (S) is less privileged than M. */
    li   t0, 0x1800
    csrc mstatus, t0          /* clear MPP */
    li   t0, 0x800
    csrs mstatus, t0          /* MPP = S */
    li   t0, 0x20000
    csrs mstatus, t0          /* MPRV = 1 */
    la   t0, s_stub
    csrw mepc, t0
    mret

s_stub:                       /* now running in S-mode */
    ecall                     /* trap to M-mode, mcause = 8 */

    .align 2
    .globl trap_handler
trap_handler:
    csrr t6, mcause
    li   t1, 8               /* expected: ecall from S-mode */
    bne  t6, t1, fail_trap   /* anything else (e.g. a page fault) -> FAIL */

    /* The S-mode ecall set MPP=M.  Restore MPP=S so that a stale MPRV would
     * pick S as the effective privilege for M-mode accesses.  On a correct
     * core MPRV is already 0, so this has no effect. */
    li   t0, 0x1000
    csrc mstatus, t0
    li   t0, 0x800
    csrs mstatus, t0

    /* M-mode access to a physical address that the page table does not map:
     * correct core: MPRV cleared -> no translation -> load succeeds.
     * buggy core:   MPRV still 1, MPP=S -> translation -> page fault ->
     *               re-trap (mcause = 5) -> fail_trap. */
    li   t0, UNMAPPED_VA
    ld   t1, 0(t0)

    /* Belt and braces: mstatus.MPRV must read 0 here. */
    csrr t0, mstatus
    li   t1, 0x20000
    and  t0, t0, t1
    bnez t0, fail_mprv
    PASS

fail_trap:
    FAIL(1)

fail_mprv:
    FAIL(2)

    .data
    .align 12
pt_root: .space 4096
pt_l1: .space 4096
