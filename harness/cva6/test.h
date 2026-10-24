/* Reproducer contract: on correct RTL the program ends with PASS; on buggy RTL it
 * ends with FAIL(n), traps unexpectedly, or hangs until the cycle limit. */
#ifndef TEST_H
#define TEST_H

/* HTIF: writing (code << 1) | 1 to tohost ends the simulation; code 0 is success. */
#define PASS            li a0, 1; j _halt
#define FAIL(n)         li a0, (((n) << 1) | 1); j _halt

/* Reproducers define test_main and may override trap_handler. Both run in M-mode. */
#endif

/* PMP entry 0 grants RWX over all memory so S/U-mode code can run. */
#define PMP_ALLOW_ALL           \
  li t0, -1;                    \
  csrw pmpaddr0, t0;            \
  li t0, 0x1f;                  \
  csrw pmpcfg0, t0

/* mret into privilege mode `mpp` (0=U, 1=S) at `target`. */
#define ENTER_MODE(mpp, target) \
  li t0, (3 << 11);             \
  csrc mstatus, t0;             \
  li t0, ((mpp) << 11);         \
  csrs mstatus, t0;             \
  la t0, target;                \
  csrw mepc, t0;                \
  mret
