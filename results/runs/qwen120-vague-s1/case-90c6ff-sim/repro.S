/* Reproducer: two-stage address translation rejects guest accesses the spec
 * allows.
 *
 * The G-stage (guest-physical) PTE used below has its U bit CLEAR, i.e. it
 * marks the page as host-supervisor-only.  A guest can only be active while
 * the host is in S-mode, and the U bit of a G PTE is checked against the
 * host privilege level, so the H extension requires all guest accesses
 * (fetch/load/store) translated through such a G PTE to succeed.
 *
 * On a spec-conformant core the guest below executes, does its loads/stores,
 * and reaches the ebreak; the M-mode trap handler then sees mcause == 3 and
 * the test ends with PASS.
 *
 * On the buggy core the DTLB/ITLB hit path treats a G PTE with U = 0 as an
 * access error, so the very first guest instruction fetch raises an
 * instruction guest page fault (mcause 20); the handler sees mcause != 3
 * and the test ends with FAIL.
 */
#include "test.h"
#include "hyp.h"

#define DRAM 0x80000000
#define IDX  0x2           /* Sv39 1 GiB index of 0x8000_0000 (VA[38:30]) */
#define G_FLAGS (PTE_V | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D)  /* U bit clear */

  HYP_TABLES

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: one 1 GiB leaf covering DRAM, host-supervisor page (U = 0). */
  GIGA_LEAF(g_root, IDX, DRAM, G_FLAGS)
  /* VS-stage: one 1 GiB leaf mapping 0x8000_0000 to itself (GPA = HPA here). */
  GIGA_LEAF(vs_root, IDX, DRAM, VS_RWX)
  fence rw, rw
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)
  la t1, data_word
  li t2, 0
  sw t2, 0(t1)
  ENTER_VS(vs_entry)
  /* unreachable */
  PASS

/* Runs in VS-mode: every instruction fetch, load and store here is
 * translated through both the VS-stage and the G-stage tables. */
vs_entry:
  la a0, data_word
  li a1, 0
  li a2, 4
.Lloop:
  addi a1, a1, 1
  sw a1, 0(a0)              /* guest store through two-stage translation */
  lw a3, 0(a0)              /* guest load  through two-stage translation */
  bne a3, a1, .Lfail
  addi a2, a2, -1
  bnez a2, .Lloop
  ebreak                   /* success: trap to M-mode */
.Lfail:
  ebreak

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 3
  bne t0, t1, .Lfail_mcause
  /* breakpoint from the guest: the guest store must have reached memory */
  la t2, data_word
  lw t3, 0(t2)
  li t4, 4
  bne t3, t4, .Lfail_data
  PASS
.Lfail_mcause:
  FAIL(2)
.Lfail_data:
  FAIL(3)

  .section .data
  .align 4
data_word: .dword 0
