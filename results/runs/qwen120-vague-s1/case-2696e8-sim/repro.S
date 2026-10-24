/* Repro: G-stage load permission check on the DTLB-hit path.
 *
 * The buggy CVA6 re-checks G-stage permissions when an LSU load hits
 * the DTLB using the U bit of the cached G PTE (!dtlb_gpte_q.u)
 * instead of the R bit the spec requires.  A G-stage PTE that is
 * readable (R=1) but not user-accessible (U=0) must therefore allow
 * an HLV load; on the buggy core it faults with a load
 * guest-page-fault (mcause 25) instead.
 *
 * The test runs in M-mode with vsatp bare, so an HLV performs a pure
 * G-stage translation of its address:
 *   g_root[0] = 1GiB leaf  GVA [0x00000000, 0x40000000) -> HPA 0x80000000
 *   g_root[2] = 1GiB leaf  GVA [0x80000000, 0xC0000000) -> HPA 0x80000000
 *   both PTEs: V|R|A|D, U=0, X=0
 *
 * Two HLW loads are issued.  This core's LSU drives the load address
 * of hypervisor loads to 0, so the exercised GVA is 0 (g_root[0]);
 * on a core that reads the rs1 operand the GVA is 0x800xxxxx
 * (g_root[2]).  Either way the accessed G PTE has R=1 and U=0:
 *   - correct core: G-stage walk and DTLB-hit re-check require R ->
 *     both loads complete -> PASS.
 *   - buggy core: DTLB-hit re-check requires U -> load
 *     guest-page-fault -> trap handler -> FAIL.
 */
#include "test.h"
#include "hyp.h"

  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 0, 0x80000000, PTE_V | PTE_R | PTE_A | PTE_D)
  GIGA_LEAF(g_root, 2, 0x80000000, PTE_V | PTE_R | PTE_A | PTE_D)
  HGATP_ON
  la t1, probe_word
  /* CVA6 encodes hypervisor loads with opcode 0x73, funct3 4,
     funct7 0110100 (HLW): 0x68000000 | rs1<<15 | 4<<12 | rd<<7 | 0x73.
     The standard RVH load opcode (0x03, funct3 4) decodes as illegal
     on this core, so the raw encoding is used. */
  .word 0x680C42F3  /* HLW x5, (x6) */
  .word 0x680C42F3  /* HLW x5, (x6) - second load to guarantee a DTLB hit */
  PASS

  .globl trap_handler
  .align 2
trap_handler:
  /* Any unexpected trap (including the load guest-page-fault raised
     by the buggy core) fails the test, reporting mcause in a0. */
  csrr t6, mcause
  slli t6, t6, 1
  ori  a0, t6, 1
  j _halt

HYP_TABLES
probe_word: .word 0x12345678
