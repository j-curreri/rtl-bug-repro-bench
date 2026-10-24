/* PMP TOR granularity bug.
 * This core has PMP granularity G=1 (8 bytes): in TOR mode pmpaddr[0] reads as
 * zero, and the region boundary is the effective (granule-aligned) address.
 * pmp_entry.sv compares against the raw pmpaddr << 2, so a TOR top bound with
 * bit 0 set extends the region by 4 bytes.
 *
 * Entry 0: TOR bottom = buf, entry 1: TOR top = (buf>>2)|... + 3 (bit 0 set),
 * no permissions -> effective region is [buf, buf+8). Entry 7 allows all.
 * A U-mode load at buf must fault; a load at buf+8 must not.
 */
#include "test.h"

  .text
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 8                 /* ecall from U: return to M-mode continuation */
  beq t0, t1, 1f
  li t1, 5                 /* load access fault: record and skip */
  bne t0, t1, 2f
  li s1, 1
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
1: jr s2
2: FAIL(100)

/* Load from buf+off in U-mode; expect a fault iff exp == 1. */
#define PROBE(off, exp, n)                         \
  la a0, buf; li t0, off; add a0, a0, t0;          \
  li s1, 0; la s2, 9f;                             \
  ENTER_MODE(0, ufn);                              \
9: li t0, exp; beq s1, t0, 8f; FAIL(n); 8:

ufn:
  ld t2, 0(a0)
  ecall

  .globl test_main
test_main:
  la t0, buf
  srli s3, t0, 2
  csrw pmpcfg0, zero
  li t0, -1
  csrw pmpaddr7, t0        /* entry 7: NAPOT, whole address space, RWX */
  csrw pmpaddr0, s3        /* entry 0: OFF, bottom of TOR range = buf */
  addi t0, s3, 3
  csrw pmpaddr1, t0        /* entry 1: TOR, top = buf + 12 raw, buf + 8 effective */
  li t0, (0x1f << 56) | (0x08 << 8)
  csrw pmpcfg0, t0
  sfence.vma

  /* sanity: TOR bit 0 reads as zero with G=1 */
  csrr t0, pmpaddr1
  addi t1, s3, 2
  bne t0, t1, fail_read

  PROBE(0, 1, 1)           /* inside region: access fault */
  PROBE(8, 0, 2)           /* outside effective region: allowed */
  PASS
fail_read:
  FAIL(3)

  .data
  .align 16
  .space 4096
buf:
  .space 8192
