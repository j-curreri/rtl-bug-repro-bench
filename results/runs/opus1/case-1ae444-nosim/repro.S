/* mtval must read as zero when an interrupt traps to M-mode.
 * Buggy core: mtval gets the interrupted instruction's bits (decoder ex.tval). */
#include "test.h"

#define CLINT_MSIP      0x02000000
#define CLINT_MTIMECMP  0x02004000
#define CLINT_MTIME     0x0200BFF8

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw mideleg, zero
  csrw medeleg, zero
  li s0, 0                      /* interrupts taken */
  li t0, -1
  li t1, CLINT_MTIMECMP
  sd t0, 0(t1)

  /* ---- 1: machine software interrupt (CLINT msip), in M-mode ---- */
  li t0, -1
  csrw mtval, t0
  li t0, (1 << 3)               /* MSIE */
  csrw mie, t0
  csrsi mstatus, 8              /* MIE */
  li t1, CLINT_MSIP
  li t0, 1
  sw t0, 0(t1)
  li t2, 2000
1:addi t2, t2, -1
  xori t3, t2, 0x5a5
  bnez t2, 1b
  csrci mstatus, 8
  li t0, 1
  bne s0, t0, fail_noint

  /* ---- 2: supervisor software interrupt (mip.SSIP), not delegated ---- */
  li t0, -1
  csrw mtval, t0
  li t0, (1 << 1)               /* SSIE */
  csrw mie, t0
  csrsi mip, 2
  csrsi mstatus, 8
  addi t3, t3, 0x123
  li t2, 2000
1:addi t2, t2, -1
  xori t3, t2, 0x3c3
  bnez t2, 1b
  csrci mstatus, 8

  /* ---- 3: supervisor timer interrupt (mip.STIP), not delegated ---- */
  li t0, -1
  csrw mtval, t0
  li t0, (1 << 5)               /* STIE */
  csrw mie, t0
  li t0, (1 << 5)
  csrs mip, t0
  csrsi mstatus, 8
  addi t3, t3, 0x77
  li t2, 2000
1:addi t2, t2, -1
  xori t3, t2, 0x1e1
  bnez t2, 1b
  csrci mstatus, 8

  /* ---- 4: machine timer interrupt ---- */
  li t0, -1
  csrw mtval, t0
  li t0, (1 << 7)               /* MTIE */
  csrw mie, t0
  li t1, CLINT_MTIME
  ld t0, 0(t1)
  addi t0, t0, 20
  li t1, CLINT_MTIMECMP
  sd t0, 0(t1)
  csrsi mstatus, 8
  li t2, 200000
1:addi t2, t2, -1
  xori t3, t2, 0x2d2
  beqz t2, 2f
  li t0, 2
  bltu s0, t0, 1b               /* until at least the M-timer has been seen */
2:csrci mstatus, 8

  /* ---- 5: machine software interrupt taken from S-mode ---- */
  li t0, -1
  csrw mtval, t0
  li t0, (1 << 3)
  csrw mie, t0
  la s1, after_s
  ENTER_MODE(1, s_code)
s_code:
  li t1, CLINT_MSIP
  li t0, 1
  sw t0, 0(t1)
  li t2, 2000
1:addi t2, t2, -1
  xori t3, t2, 0x4b4
  bnez t2, 1b
  ecall
after_s:
  csrw mie, zero
  li t0, 2
  bltu s0, t0, fail_noint
  PASS

fail_noint:
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t5, mcause
  bltz t5, 1f
  li t6, 9                      /* ecall from S: resume in M at s1 */
  bne t5, t6, bad_trap
  li t6, (3 << 11)
  csrs mstatus, t6
  csrw mepc, s1
  mret
1:csrr t6, mtval
  bnez t6, bad_mtval
  addi s0, s0, 1
  slli t5, t5, 1
  srli t5, t5, 1
  li t6, 3
  beq t5, t6, clr_msip
  li t6, 7
  beq t5, t6, clr_mtip
  li t6, 1
  sll t6, t6, t5
  csrc mip, t6                  /* SSIP / STIP */
  csrc mie, t6
  mret
clr_msip:
  li t6, CLINT_MSIP
  sw zero, 0(t6)
  csrci mie, 8
  mret
clr_mtip:
  li t6, -1
  li t5, CLINT_MTIMECMP
  sd t6, 0(t5)
  li t6, (1 << 7)
  csrc mie, t6
  mret

bad_mtval:
  FAIL(1)
bad_trap:
  FAIL(3)
