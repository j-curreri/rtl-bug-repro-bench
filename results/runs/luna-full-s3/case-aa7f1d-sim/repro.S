#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Prepare two distinct SRET destinations. */
  la t0, correct_path
  csrw sepc, t0
  la t0, buggy_path
  csrw vsepc, t0

  /* Make a VS-mode SRET return to supervisor mode. */
  li t0, (1 << 8)             /* vsstatus.SPP */
  csrw vsstatus, t0

  /* Ask MRET to return to M mode with MPV set.  The architecture requires
   * MPV to be ignored for this return, leaving virtualization disabled. */
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  ENTER_MODE(3, after_mret)

after_mret:
  /* With V=0, this uses sepc.  If MRET incorrectly enabled V, it uses
   * vsstatus/vsepc instead. */
  sret

correct_path:
  PASS

buggy_path:
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  FAIL(127)
