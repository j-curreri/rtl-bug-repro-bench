/* Reproducer: two-stage translation, store to a VS-stage read-only page whose
 * translation is already cached in the DTLB, and whose G-stage mapping is also
 * read-only. The VS-stage permission check precedes the G-stage check, so the
 * expected cause is STORE_PAGE_FAULT (15), not STORE_GUEST_PAGE_FAULT (23).
 *
 * Each probe sets a6 = case number and a7 = expected mcause (0 = no trap).
 * The M-mode trap handler checks mcause against a7, skips the faulting
 * instruction and returns to VS-mode. A mismatch fails with code (case << 8) | mcause.
 */
#include "hyp.h"

#define G_RO  (PTE_V | PTE_R | PTE_U | PTE_A | PTE_D)
#define VS_RO (PTE_V | PTE_R | PTE_A | PTE_D)

  .option norvc

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: GPA gigapages 1..5 all map to the DRAM gigapage at PA 0x80000000. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 1, 0x80000000, G_RO)
  GIGA_LEAF(g_root, 3, 0x80000000, G_RO | PTE_W)
  GIGA_LEAF(g_root, 4, 0x80000000, G_RO)
  GIGA_LEAF(g_root, 5, 0x80000000, G_RO)

  /* VS-stage: VA gigapage i maps to GPA gigapage i. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  GIGA_LEAF(vs_root, 1, 0x40000000, VS_RO)
  GIGA_LEAF(vs_root, 3, 0xC0000000, VS_RO)
  GIGA_LEAF(vs_root, 4, 0x100000000, VS_RWX)
  GIGA_LEAF(vs_root, 5, 0x140000000, VS_RO)

  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)

  ENTER_VS(vs_code)

  .align 2
vs_code:
  /* Case 1: VS-RO, G-RO. The load fills the DTLB with the combined translation. */
  li a6, 1
  li a7, 0
  li t0, 0x40100000
  ld t1, 0(t0)

  /* Case 2: store to the same cached page. VS-stage fault must win: expect 15. */
  li a6, 2
  li a7, 15
  li t0, 0x40100000
  sd t1, 0(t0)

  /* Case 3: VS-RO, G-RW. Load fills, store faults at VS stage: expect 15. */
  li a6, 3
  li a7, 0
  li t0, 0xC0100000
  ld t1, 0(t0)

  li a6, 4
  li a7, 15
  li t0, 0xC0100000
  sd t1, 0(t0)

  /* Case 5: VS-RW, G-RO, store miss. Only the G-stage check fails: expect 23. */
  li a6, 5
  li a7, 23
  li t0, 0x100100000
  sd t1, 0(t0)

  /* Case 6: VS-RO, G-RO, store miss. VS-stage fails first: expect 15. */
  li a6, 6
  li a7, 15
  li t0, 0x140100000
  sd t1, 0(t0)

  li a6, 7
  li a7, 10
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 10
  beq t0, t1, 2f
  bne t0, a7, 1f
  csrr t1, mepc
  addi t1, t1, 4
  csrw mepc, t1
  mret
1:
  slli t1, a6, 8
  or t1, t1, t0
  slli t1, t1, 1
  ori a0, t1, 1
  j _halt
2:
  PASS

HYP_TABLES
