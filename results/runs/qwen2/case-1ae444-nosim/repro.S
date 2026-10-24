#include "test.h"

/*
 * Bug reproducer: machine-mode interrupts must write mtval = 0.
 *
 * On this core, when a machine-mode interrupt is taken, mtval is not
 * always cleared to zero. The interrupt is decoded like any exception,
 * and the decoder pre-loads ex.tval with the raw bits of the interrupted
 * instruction; the interrupt path sets ex.valid/ex.cause but never clears
 * ex.tval, so the value survives into mtval. A spec-compliant core writes
 * mtval = 0 for interrupts, so in the trap handler mtval reads as 0.
 *
 * The program arms an M-mode timer interrupt through the CLINT (writing 0
 * to MTIMECMP so that MTIME >= MTIMECMP holds immediately), enables it,
 * and then checks in its M-mode trap handler that mtval reads as 0.
 *
 *   correct core: mtval == 0  -> PASS
 *   buggy core:   mtval != 0  -> FAIL(11)
 */

        .section        .text
        .globl          test_main
test_main:
        /* Allow access to all memory (harmless; we stay in M-mode). */
        PMP_ALLOW_ALL

        /* ---- arm an M-mode timer interrupt ----
         * Write 0 to MTIMECMP[0] (0x0200_BFF8). MTIME is always >= 0, so
         * mip.MTIP is set immediately. */
        li              t0, 0x0200BFF8             /* MTIMECMP[0] */
        sd              zero, 0(t0)

        /* Enable the M timer interrupt: mie.MTIE (bit 7). */
        li              t0, 1 << 7
        csrs            mie, t0

        /* Enable M-mode interrupts: mstatus.MIE (bit 3). From here on the
         * interrupt is pending and globally enabled, so it is taken at the
         * next instruction boundary. */
        li              t0, 1 << 3
        csrs            mstatus, t0

        /* The interrupt preempts the next instruction; it is non-zero, so
         * on the buggy core mtval ends up equal to its raw bits (!= 0). */
        nop

        /* Reaching this point means no trap happened (environment issue). */
        FAIL(2)

/* M-mode trap handler (overrides the weak default from crt.S). */
        .align          2
        .globl          trap_handler
trap_handler:
        /* Sanity check: this must be the M-mode timer interrupt
         * (mcause = 0x8000_0000_0000_0007). */
        csrr            t1, mcause
        li              t2, 0x8000000000000007
        bne             t1, t2, bad_cause

        /* The check itself: mtval must read as 0 on an M-mode interrupt. */
        csrr            t1, mtval
        bnez            t1, bad_mtval

        /* Correct behaviour. */
        PASS

bad_cause:
        FAIL(10)

bad_mtval:
        FAIL(11)
