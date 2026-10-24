/* Bug: G-stage translation of the implicit VS-stage page-table access does not
 * check the G-stage PTE U bit. All G-stage accesses are treated as U-mode accesses,
 * so a VS page table living in a guest-physical page whose G-stage leaf has U=0
 * must raise a load guest-page fault (cause 21). */
#include "hyp.h"
.option norvc

.text
.globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA 2 GiB -> PA 0x80000000 (RWXU); GPA 3 GiB -> PA 0x80000000 without U */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, G_RWX & ~PTE_U)
  /* VS-stage: VA 2 GiB -> GPA 2 GiB */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  HGATP_ON
  /* vsatp root = vs_root seen through the GPA 3 GiB alias (G-stage U=0) */
  la t0, vs_root
  li t1, 0x80000000
  sub t0, t0, t1
  li t1, (3 << 30)
  add t0, t0, t1
  VSATP_ON(t0)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  li s11, 0
  la t0, scratch
  hlv.d t3, (t0)
  li t2, 21
  bne s11, t2, fail
  PASS
fail:
  FAIL(1)

.align 2
.globl trap_handler
trap_handler:
  csrr s11, mcause
  csrr t6, mepc
  addi t6, t6, 4
  csrw mepc, t6
  mret

.data
.align 3
scratch: .dword 0
HYP_TABLES
