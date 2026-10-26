#include "test.h"

/* NAPOT PMP with 8-byte granularity (G=1). In NAPOT mode pmpaddr bit 0 reads as 1, and the
 * region size is 2^(G+3+k) bytes, where k is the number of trailing ones above bit 0. So
 * pmpaddr = B>>2 (stored bit 0 = 0, reads back as 1) encodes a 16-byte region [B, B+16).
 * Entry 0 is the NAPOT deny region, entry 1 is OFF with address 0, entry 2 is TOR RWX over
 * all memory. Data accesses are checked as U-mode via MPRV, which is cleared before any
 * halt. Byte probes via lb.
 * Fail code = n for CHECK number n. */

.option norvc

.globl trap_handler
.align 2
trap_handler:
  csrr t6, mcause
  li t5, 5                 /* load access fault */
  bne t6, t5, unexpected
  csrr t5, mepc
  addi t5, t5, 4           /* skip the faulting load */
  csrw mepc, t5
  li s11, 1                /* record that the access faulted */
  mret
unexpected:
  li t0, (1 << 17)
  csrc mstatus, t0
  mv a0, t6
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt

/* a1 = address; s11 = 1 if the load faulted, 0 otherwise. */
probe:
  li s11, 0
  lb t2, 0(a1)
  ret

/* Probe addr; expect fault flag == want, else FAIL(code). */
#define CHECK(addr, want, code) \
  li a1, addr;                  \
  jal probe;                    \
  li t1, want;                  \
  li a0, (((code) << 1) | 1);   \
  bne s11, t1, do_fail

.globl test_main
.section .text
test_main:
  csrw pmpaddr1, zero
  li t0, -1
  csrw pmpaddr2, t0
  li t0, 0x0f0018
  csrw pmpcfg0, t0

  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 17)
  csrs mstatus, t0

  /* B = 0x80100000: pmpaddr = B>>2 with bit 0 clear, NAPOT -> 16-byte region */
  li t0, 0x20040000
  csrw pmpaddr0, t0
  CHECK(0x80100000, 1, 1)
  CHECK(0x80100008, 1, 2)
  CHECK(0x8010000f, 1, 3)
  CHECK(0x80100010, 0, 4)

  li t0, (1 << 17)
  csrc mstatus, t0
  PASS

do_fail:
  li t0, (1 << 17)
  csrc mstatus, t0
  j _halt
