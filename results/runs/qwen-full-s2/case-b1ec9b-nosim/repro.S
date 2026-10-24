/*
 * Bug: MRET that returns from M-mode to a less-privileged mode (MPP != M)
 * must clear mstatus.MPRV (RISC-V Privileged Spec, mret semantics).  In
 * this core that clear lives only in the hypervisor path of the mret
 * handler (csr_regfile.sv, guarded by CVA6Cfg.RVH), which is compiled out
 * for configuration cv64a6_imafdc_sv39 (RVH = 0).  MPRV therefore survives
 * an M -> S -> M round trip and later M-mode memory accesses are translated
 * and permission-checked through the S-mode satp table with MPP privilege.
 *
 * Test plan:
 *  1. Build an Sv39 S-mode page table:
 *       - the code page and the HTIF (tohost) page are mapped 1:1 (R|W|X|U),
 *       - one data page X is mapped to a DIFFERENT physical page Y.
 *    [X] holds SENT_A, [Y] holds SENT_B (SENT_A != SENT_B).
 *  2. Set MPRV = 1 and MRET into S-mode.  S-mode executes one instruction
 *    (ecall), which traps to M-mode with MPP = S; the trap handler returns
 *    to M-mode at m_check.  A spec-compliant core has cleared MPRV on the
 *    first mret; on the buggy core MPRV is still 1 and, after the return to
 *    M-mode, MPP = U (RVU), so M-mode accesses are translated by the S-mode
 *    table and checked at U privilege.
 *  3. In M-mode:
 *       (a) an M-mode load of X must read physical X (= SENT_A).  With MPRV
 *           still active the load is translated X -> Y and returns SENT_B.
 *       (b) mstatus.MPRV must read 0.
 *
 * A correct core reaches PASS; the buggy core fails with FAIL(1) (wrong
 * value from the M-mode load) or FAIL(2) (MPRV still set), or traps.
 */
#include "test.h"

#define PTE_INTR    0x43        /* A|R|V - intermediate page table entry */
#define PTE_LEAF    0xff        /* D|A|G|U|X|W|R|V - leaf entry, RSW = 0 */
#define MSTATUS_MPRV    0x00020000
#define MSTATUS_MPP_M   0x00001800
#define SATP_SV39       8

#define SENT_A  0x1122334455667788
#define SENT_B  0x99aabbccddeeff

/* Five 4 KiB pages: L3, L2, L1, sentinel page X, sentinel page Y. */
    .section .bss
    .align 12
bss_array:
    .space 0x3000
sentinel_x:                /* B + 0x3000 */
    .dword 0
    .space 0xff8
sentinel_y:                /* B + 0x4000 */
    .dword 0
    .space 0xff8

    .section .text
    .globl test_main
test_main:
    PMP_ALLOW_ALL

    la   t2, bss_array
    li   t0, -4096
    and  t2, t2, t0            /* t2 = B: 4 KiB base of the page table area */

    /* sentinel values: [X] = SENT_A, [Y] = SENT_B */
    li   t0, SENT_A
    la   t1, sentinel_x
    sd   t0, 0(t1)
    li   t0, SENT_B
    la   t1, sentinel_y
    sd   t0, 0(t1)

    /* Sv39 indices of virtual address X = &sentinel_x */
    la   a0, sentinel_x
    srli t3, a0, 38
    andi t3, t3, 511           /* vpn2: L3 index */
    srli t4, a0, 30
    andi t4, t4, 511           /* vpn1: L2 index */
    srli t5, a0, 12
    andi t5, t5, 511           /* vpn0: L1 index */

    /* PTE value = PPN | flags = (PA >> 12) << 10 | flags = PA >> 2 | flags.
     * L3[vpn2] = L2 | A|R|V */
    li   t0, PTE_INTR
    li   t1, 0x1000
    add  t1, t2, t1            /* t1 = L2 PA */
    srli t1, t1, 2
    or   t1, t1, t0
    slli t3, t3, 3
    add  t6, t2, t3            /* t6 = L3 base + vpn2*8 */
    sd   t1, 0(t6)

    /* L2[vpn1] = L1 | A|R|V */
    li   t0, PTE_INTR
    li   t1, 0x2000
    add  t1, t2, t1            /* t1 = L1 PA */
    srli t1, t1, 2
    or   t1, t1, t0
    li   t6, 0x1000
    add  t6, t2, t6            /* t6 = L2 base */
    slli t4, t4, 3
    add  t6, t6, t4
    sd   t1, 0(t6)

    /* L1[vpn0(X)] = Y | leaf - the only non-identity mapping */
    li   t0, PTE_LEAF
    li   t1, 0x4000
    add  t1, t2, t1            /* t1 = Y PA */
    srli t1, t1, 2
    or   t1, t1, t0
    li   t6, 0x2000
    add  t6, t2, t6            /* t6 = L1 base */
    slli t5, t5, 3
    add  t6, t6, t5
    sd   t1, 0(t6)

    /* L1[vpn0(code)] = code page | leaf - S-mode stub must be fetchable */
    la   t0, s_entry
    li   t1, -4096
    and  t0, t0, t1            /* t0 = code page base */
    srli t5, t0, 12
    andi t5, t5, 511
    li   t3, PTE_LEAF
    srli t0, t0, 2
    or   t0, t0, t3
    li   t6, 0x2000
    add  t6, t2, t6
    slli t5, t5, 3
    add  t6, t6, t5
    sd   t0, 0(t6)

    /* L1[vpn0(tohost)] = tohost page | leaf - _halt must be storable when
     * MPRV is (wrongly) active */
    la   t0, tohost
    and  t0, t0, t1            /* t1 still holds -4096 */
    srli t5, t0, 12
    andi t5, t5, 511
    li   t3, PTE_LEAF
    srli t0, t0, 2
    or   t0, t0, t3
    li   t6, 0x2000
    add  t6, t2, t6
    slli t5, t5, 3
    add  t6, t6, t5
    sd   t0, 0(t6)

    fence

    /* satp = Sv39, root at B: value = (B >> 12) << 10 | (8 << 60) */
    srli t0, t2, 2
    li   t1, SATP_SV39
    slli t1, t1, 60
    or   t0, t0, t1
    csrw satp, t0

    /* MPRV = 1: a spec-compliant mret to S must clear this */
    li   t0, MSTATUS_MPRV
    csrs mstatus, t0

    /* MRET into S-mode */
    ENTER_MODE(1, s_entry)

    .align 2
s_entry:
    ecall                      /* S-mode -> M-mode trap, mstatus.MPP = S */

    .align 2
    .globl trap_handler
trap_handler:
    csrr t5, mstatus
    srli t5, t5, 11
    andi t5, t5, 3             /* MPP */
    li   t0, 1
    bne  t5, t0, trap_fail     /* only the S-ecall is expected (MPP = S) */
    li   t0, MSTATUS_MPP_M
    csrs mstatus, t0           /* MPP = M */
    la   t0, m_check
    csrw mepc, t0
    mret
trap_fail:
    FAIL(127)

m_check:
    /* (a) behavioural: an M-mode load of X must read physical X.
     *     With MPRV still active, X is translated through the S-mode
     *     table to Y and the load returns SENT_B. */
    la   a0, sentinel_x
    ld   a0, 0(a0)
    li   a1, SENT_A
    bne  a0, a1, fail_mem

    /* (b) state: MPRV must have been cleared by the mret to S */
    csrr a0, mstatus
    li   a1, MSTATUS_MPRV
    and  a0, a0, a1
    bnez a0, fail_mprv

    PASS

fail_mprv:
    FAIL(2)
fail_mem:
    FAIL(1)
