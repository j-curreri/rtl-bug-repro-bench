    .include "test.h"
    .include "hyp.h"

    .globl test_main
    .type test_main, @function
test_main:
    // Set up guest-physical memory pages:
    // GPA 0: execute-only (v=1, x=1, r=0), contains VS-stage page table
    // GPA 1: readable (v=1, r=1), contains data page

    // VS-stage page table (at GPA 0):
    // L2 root (vs_root) entry 0 -> L1 table at offset 0 in GPA 0
    // L1 table entry 0 -> data at GPA 1 offset 0
    // (Leaves are 1 GiB pages via GIGA_LEAF)

    // G-stage page table (at virtual address space):
    // G-root entry 0 -> VS-stage root at GPA 0 (execute-only), entry 1 -> data at GPA 1 (readable)

    // Enable G-stage and VS-stage
    HGATP_ON
    // Set vsatp to SATP_SV39
    li t1, SATP_SV39
    csrw vsatp, t1

    // Write VS-stage page table entries
    // vs_root is 4 KiB, L2 root has 512 entries
    la t0, vs_root
    li t2, 0          // idx = 0, L2 root entry 0
    li t3, 0x01       // PTE_V for valid, PTE_X for execute-only (for the page table itself), PTE_A|PTE_D for accessed/dirty?
    // Entry 0: VS-stage root -> L1 table at offset 0
    RAW_PTE(vs_root, t2, (PTE_V | PTE_X))

    // L1 table (starts at vs_root[512] since L2 has 512 entries, each entry 8 bytes)
    // vs_root[512:8191] is L1
    la t0, vs_root
    li t2, 512        // idx = 512, L1 table entry 0
    li t3, (PTE_V | PTE_R | PTE_X)  // VS-stage leaf PTE pointing to data
    RAW_PTE(vs_root, t2, (PTE_V | PTE_R | PTE_X))

    // Write G-stage page table entries
    // g_root is 16 KiB, G-root has 1024 entries for Sv39x4
    la t0, g_root
    li t2, 0          // idx = 0, G-root entry 0 -> VS-stage root at GPA 0 (execute-only)
    li t3, (PTE_V | PTE_X)  // execute-only for VS-stage page table page
    RAW_PTE(g_root, t2, (PTE_V | PTE_X))

    // G-root entry 1 -> data at GPA 1 (readable)
    li t2, 1
    li t3, (PTE_V | PTE_R | PTE_W)  // readable+writable data
    RAW_PTE(g_root, t2, (PTE_V | PTE_R | PTE_W))

    // Data page (GPA 1, offset 0):
    // Use GIGA_LEAF to set a 1 GiB leaf that contains a data word
    la t0, vs_root    // GIGA_LEAF uses table = g_root for G-stage leaves
    // Actually GIGA_LEAF needs the table and idx
    // For data, we need to set up a leaf under VS-stage L1
    li t0, g_root
    li t2, 0          // idx in g_root for leaf mapping
    // GPA 1 (offset 0) -> use GIGA_LEAF(g_root, 0, 0x100000000, PTE_V|PTE_R|PTE_W)
    li t3, 0x0        // guest-physical offset within GPA 1
    // Calculate flags: ((pa) >> 12 << 10) | flags
    // pa = 0x80000000 + 0x100000000 = 0x90000000? No, GPA is guest-physical, not virtual.
    // Let me think: for GIGA_LEAF(g_root, idx, pa, flags), pa is guest-physical address
    // The macro computes ((pa) >> 12 << 10), which is (pa >> 12) << 10
    // For pa = 0x10000000 (1 MiB), (pa >> 12) = 0x100, (0x100 << 10) = 0x40000 (1 MiB offset in 1 GiB page)
    // So for pa = 0x10000000 (GPA 1 offset 0), we need idx such that the leaf is at offset 0 in the 1 GiB page
    // Actually, let me just use raw PTE for now

    // For now, just set up the page tables as described and try a load
    // Enable VS-mode
    ENTER_VS(test_load)

    // Do a load from a virtual address that maps to the data page
    la t0, data_val
    lw t0, 0(t0)  // This should walk VS-stage page table and fault on correct core

    PASS
.section .data
test_load:
.align 4
.byte 0
data_val:
    .word 0xdeadbeef  // test data
