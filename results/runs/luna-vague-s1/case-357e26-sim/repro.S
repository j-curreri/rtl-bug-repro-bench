#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* Allow every byte below the middle of protected_word.  The following TOR
   * entry covers the rest of physical address space and grants no access. */
  la t0, protected_word
  addi t0, t0, 4
  srli t0, t0, 2
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  li t0, 0x080f              /* pmp0: TOR/RWX, pmp1: TOR/no permissions */
  csrw pmpcfg0, t0

  /* An eight-byte store starts in pmp0's allowed range and ends in pmp1's
   * denied range.  The whole access must fault on a conforming PMP. */
  ENTER_MODE(0, user_store)

user_store:
  la t0, protected_word
  li t1, 0x1122334455667788
  sd t1, 0(t0)
  FAIL(1)                    /* The buggy checker may inspect only the first byte. */

  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 7                   /* Store/AMO access fault */
  beq t0, t1, expected_fault
  FAIL(2)
expected_fault:
  PASS

  .section .data
  .align 3
protected_word:
  .dword 0
