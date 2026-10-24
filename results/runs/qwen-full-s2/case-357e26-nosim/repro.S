#include "test.h"

/* PMP TOR boundary bug reproducer (8-byte / G=1 PMP granularity).
 *
 * The pmpaddr registers hold the boundary address shifted right by 3 bits, so
 * a TOR entry i protects
 *       [ pmpaddr[i-1] << 3 , pmpaddr[i] << 3 )
 * The buggy core compares against (pmpaddr << 2) instead, so when a pmpaddr
 * value has its lowest bit set the upper bound of a TOR region lands at
 * pmpaddr << 2 (half of the intended address).  A U-mode access just at that
 * boundary is then checked against the *next* PMP entry instead of the entry
 * it belongs to.
 *
 * Configuration (pmpcfg byte layout of this core: [7]=L [6:5]=rsv
 * [4:3]=addr_mode [2]=X [1]=W [0]=R, TOR = 2'b01):
 *
 *   P0 = 0x20003001 (lowest bit set)
 *   P1 = 0x40006003 (lowest bit set)
 *   entry 0: TOR, RWX          entry 1: TOR, no access
 *
 * Correct core:  entry 0 = [0, 0x100018008)      (P0 << 3)
 *                entry 1 = [0x100018008, 0x200030018)
 * Buggy core:    entry 0 = [0, 0x8000C004)       (P0 << 2)
 *                entry 1 = [0x8000C004, 0x10001800C)
 *
 * The U-mode test address A = 0x90000000 (in DRAM) lies in [P0<<2, P0<<3):
 *   - correct core: A is inside entry 0 (RWX) -> the store succeeds and the
 *     program ends with PASS;
 *   - buggy core:   A is inside entry 1 (no access) -> the store raises a
 *     store access fault -> FAIL.
 *
 * The program code, .tohost and the stack (0x80000000-0x80008000) are inside
 * entry 0 on both cores, so only the store at A behaves differently.
 */

  .section .text
  .globl test_main
test_main:
  li  t0, 0x20003001            /* pmpaddr0 = P0, lowest bit set */
  csrw pmpaddr0, t0
  li  t0, 0x40006003            /* pmpaddr1 = P1, lowest bit set */
  csrw pmpaddr1, t0
  li  t0, 0x080f                /* entry 0: TOR RWX; entry 1: TOR, no access */
  csrw pmpcfg0, t0

  /* Perform the boundary access from U-mode; return via ecall (mcause 8). */
  ENTER_MODE(0, u_boundary)

u_boundary:
  li  a0, 0x90000000
  sd  zero, 0(a0)               /* boundary access: allowed on a correct core */
  ecall                         /* trap to M-mode */

m_done:                         /* runs in M-mode after the handler's mret */
  PASS

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li   t1, 8                    /* ecall from U-mode: the expected return */
  bne  t0, t1, trap_fail
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  li   t1, 0x1800               /* MPP = M */
  csrs mstatus, t1
  mret
trap_fail:
  /* PMP denied the U-mode store at the boundary: the bug is present. */
  FAIL(42)
