#include "harness/hyp.h"

/* Sv39x4 accepts guest physical addresses below 2^41.  This valid
 * non-leaf VS PTE points to 2^41: PPN bit 29 becomes PTE bit 39.
 * Its reserved bits and R/W/X/U/A/D bits are all clear.
 */
#define OUT_OF_RANGE_POINTER ((1 << 39) | PTE_V)
#define LOAD_GUEST_PAGE_FAULT 21

  .section .text
  .balign 4
  .globl test_main
test_main:
  li s0, 0
  csrw mie, zero
  csrw medeleg, zero
  csrw mideleg, zero
  csrw hedeleg, zero
  csrw satp, zero
  PMP_ALLOW_ALL

  /* Both stages identity-map DRAM, including code and the VS root.
   * G-stage leaves require U=1; VS supervisor code uses U=0.
   * A/D are preset so the test needs no hardware PTE updates.
   */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /* VA 0x40000000 selects VS root entry 1.  Walking its next level
   * requires an out-of-range GPA and must raise a guest-page fault.
   */
  RAW_PTE(vs_root, 1, OUT_OF_RANGE_POINTER)
  fence rw, rw
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)
  ENTER_VS(vs_main)

  .balign 4
vs_main:
  li a1, 0x40000000
  li s0, 1
faulting_load:
  ld a2, 0(a1)

  /* A successful load is also a failure.  Return to M via a trap
   * rather than accessing tohost while still in VS mode.
   */
  li s0, 0
  ecall
1:
  j 1b

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t0, 1
  bne s0, t0, unexpected_trap
  csrr t1, mepc
  la t0, faulting_load
  bne t1, t0, unexpected_trap
  li t0, LOAD_GUEST_PAGE_FAULT
  bne t6, t0, wrong_cause
  PASS

wrong_cause:
  FAIL(1)
unexpected_trap:
  FAIL(2)

  HYP_TABLES
