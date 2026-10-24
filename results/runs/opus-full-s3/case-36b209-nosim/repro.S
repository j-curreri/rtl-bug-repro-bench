/* VS-stage non-leaf PTE pointing to a GPA >= 2^41 (outside Sv39x4 guest-physical
 * space) must raise a load guest-page fault (cause 21), not a load page fault (13). */
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: identity-map GPA 0x80000000..0xBFFFFFFF */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  /* VS-stage: identity leaf for code/data, non-leaf pointing to GPA 2^41 at VA 0xC0000000 */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  RAW_PTE(vs_root, 3, ((1 << 29) << 10) | PTE_V)
  la t2, vs_root
  VSATP_ON(t2)
  ENTER_VS(guest)

guest:
  li t0, 0xC0000000
faulting_load:
  ld t1, 0(t0)
  FAIL(1)          /* the load must trap */

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 21
  bne t6, t5, bad_cause
  csrr t4, mepc
  la t5, faulting_load
  bne t4, t5, bad_epc
  csrr t4, mstatus
  li t5, MSTATUS_MPV
  and t4, t4, t5
  beqz t4, bad_mpv
  PASS
bad_cause:
  FAIL(2)
bad_epc:
  FAIL(3)
bad_mpv:
  FAIL(4)

  HYP_TABLES
