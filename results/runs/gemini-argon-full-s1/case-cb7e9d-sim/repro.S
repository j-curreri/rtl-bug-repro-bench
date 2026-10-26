#include "test.h"

/* Sdtrig mcontrol6 (RV64) fields:
 *   [63:60] type   = 6 (mcontrol6)
 *   [21]    select = 0 (virtual address match)
 *   [18:16] size   = 0 (match accesses of any size)
 *   [15:12] action = 0 (raise breakpoint exception, mcause = 3)
 *   [10:7]  match  = 0 (equal) or 1 (NAPOT)
 *   [3]     u      = 1 (active in U-mode)
 *   [1]     store  = 1 (match store addresses)
 */
#define MC6_TYPE          (6ULL << 60)
#define MC6_MATCH_EQ      (0ULL << 7)
#define MC6_MATCH_NAPOT   (1ULL << 7)
#define MC6_U             (1ULL << 3)
#define MC6_STORE         (1ULL << 1)

#define MC6_DISABLE       (MC6_TYPE)
#define MC6_EQ_USTORE     (MC6_TYPE | MC6_MATCH_EQ | MC6_U | MC6_STORE)
#define MC6_NAPOT_USTORE  (MC6_TYPE | MC6_MATCH_NAPOT | MC6_U | MC6_STORE)

#define CAUSE_BREAKPOINT  3
#define MSTATUS_MPP_MASK  (3 << 11)
#define MSTATUS_MPIE      (1 << 7)

  .section .text
  .option norvc

  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw satp, zero

  la s2, watch_buf
  li s3, 1              /* Phase 1: exact-match (match=0) check */
  li s4, 0

  /* Trigger 0: exact store-address match at watch_buf + 8 in U-mode */
  csrw tselect, zero
  li t0, MC6_DISABLE
  csrw tdata1, t0
  addi t0, s2, 8
  csrw tdata2, t0
  li t0, MC6_EQ_USTORE
  csrw tdata1, t0

  li t0, MSTATUS_MPIE
  csrs mstatus, t0
  ENTER_MODE(0, u_phase1)

u_phase1:
  li t1, 0x11
  sw t1, 16(s2)         /* Outside exact target: must not trap */
  li s4, 1
  li t1, 0x22
  sw t1, 8(s2)          /* Exact match at watch_buf + 8: must trap */
  nop
  nop
  li s4, 2
  ecall

u_phase2:
  li t1, 0x33
  sw t1, 16(s2)         /* Outside [watch_buf, watch_buf + 15]: must not trap */
  li s4, 1
  li t1, 0x44
  sw t1, 8(s2)          /* Inside 16-byte NAPOT range: must trap with breakpoint */
  nop
  nop
  li s4, 2
  ecall                 /* Reached on buggy core when NAPOT trigger fails to fire */

  .globl trap_handler
  .balign 4
trap_handler:
  csrr t0, mcause
  li t1, 1
  beq s3, t1, handle_phase1
  li t1, 2
  beq s3, t1, handle_phase2
  FAIL(1)

handle_phase1:
  li t1, CAUSE_BREAKPOINT
  bne t0, t1, fail_phase1
  li t1, 1
  bne s4, t1, fail_phase1

  /* Phase 2: 16-byte NAPOT range [watch_buf, watch_buf + 15].
   * watch_buf is 64-byte aligned, so tdata2 = watch_buf | 0x7 has its least-significant
   * zero bit at index 3, matching top (XLEN - 1 - 3) = 60 bits [63:4]. */
  li s3, 2
  li s4, 0

  csrw tselect, zero
  li t0, MC6_DISABLE
  csrw tdata1, t0
  ori t0, s2, 7
  csrw tdata2, t0
  li t0, MC6_NAPOT_USTORE
  csrw tdata1, t0

  li t0, MSTATUS_MPP_MASK
  csrc mstatus, t0
  li t0, MSTATUS_MPIE
  csrs mstatus, t0
  la t0, u_phase2
  csrw mepc, t0
  mret

fail_phase1:
  FAIL(2)

handle_phase2:
  li t1, CAUSE_BREAKPOINT
  bne t0, t1, fail_napot_missed
  li t1, 1
  bne s4, t1, fail_napot_range

  csrw tselect, zero
  li t0, MC6_DISABLE
  csrw tdata1, t0
  PASS

fail_napot_range:
  FAIL(3)

fail_napot_missed:
  FAIL(4)

  .section .data
  .balign 64
watch_buf:
  .dword 0, 0, 0, 0, 0, 0, 0, 0
