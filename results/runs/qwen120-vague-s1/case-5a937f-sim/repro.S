/*
 * Bug: a field of the environment-configuration CSRs can hold a value the
 * spec does not allow.
 *
 * The CBIE field (bits [5:4] of menvcfg/senvcfg, Zicbom extension) is WARL
 * with three legal encodings: 2'b00, 2'b01, 2'b11. Encoding 2'b10 is
 * reserved: an implementation must never hold/read back a reserved value.
 * This core, however, stores it and returns it on read:
 *
 *     default: mcbie_d = riscv::CBIE_RSVD;   // csr_regfile.sv, menvcfg write
 *
 * so after `csrw menvcfg, 0x20` a read-back has bits [5:4] == 2'b10 on the
 * buggy core, while a correct core reads back one of the legal values
 * (00, 01 or 11). The same defective mapping exists for senvcfg.
 */
#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* Write the reserved CBIE encoding 2'b10 into menvcfg (bits [5:4] = 0x20). */
  li   t0, 0x20
  csrw menvcfg, t0              /* CSR 0x30a */
  csrr t1, menvcfg
  andi t3, t1, 0x30             /* isolate CBIE */
  li   t4, 0x20                 /* the reserved encoding */
  bne  t3, t4, check_senvcfg    /* not held: legal value */
  FAIL(1)

check_senvcfg:
  /* Same check on senvcfg (CSR 0x10a), which has the same field. */
  csrw senvcfg, t0
  csrr t1, senvcfg
  andi t3, t1, 0x30
  bne  t3, t4, pass_all
  FAIL(2)

pass_all:
  PASS

/* Fail fast on any unexpected trap (instead of the default fixed code 127);
 * the +100 offset guarantees the tohost code is never the PASS code 1. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr a0, mcause
  li   t0, 100
  add  a0, a0, t0
  slli a0, a0, 1
  ori  a0, a0, 1
  j    _halt
