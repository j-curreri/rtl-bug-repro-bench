#include "test.h"
#include "hyp.h"

.globl test_main
test_main:
    PMP_ALLOW_ALL

    // Enable G-stage translation
    la t0, g_root
    li t1, SATP_SV39
    or t0, t0, t1
    csrw hgatp, t0
    hfence.gvma

    // Map guest-physical 0x80000000 to guest-virtual 0
    GIGA_LEAF(g_root, 0, 0x80000000, PTE_V | PTE_R | PTE_W | PTE_X | PTE_U | PTE_A | PTE_D)

    // Enter VS-mode (vsatp stays Bare - default)
    ENTER_VS test_vs_main

    // PASS from M-mode
    PASS

test_vs_main:
    li a0, 1
    PASS
