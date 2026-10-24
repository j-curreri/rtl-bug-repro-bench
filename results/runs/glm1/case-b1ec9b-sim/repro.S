/* repro.S -- reproducer for "MRET returning M -> S fails to clear MPRV".
 *
 * The privileged spec requires that an xRET returning to a privilege mode less
 * privileged than M clears MPRV.  On this core the clear sits inside an
 * `if (CVA6Cfg.RVH)` block and the config has RVH = 0, so MPRV survives the
 * mret and subsequent M-mode loads/stores get translated and permission
 * checked through satp/MPP as if MPRV were still set.
 *
 * Flow:
 *   1. In M-mode set MPRV=1 and MPP=S, then mret into S-mode.
 *      A spec-correct core clears MPRV here; the buggy core does not.
 *   2. The S-mode stub immediately traps back to M-mode with an ECALL.
 *      The handler checks that MPP == S (so this is the expected ECALL),
 *      rewires mepc and returns to M-mode with MPP = M.  (xRET with xPP = M
 *      leaves MPRV unchanged, so the stale MPRV is preserved on the buggy
 *      core and nothing else changes on the correct core.)
 *   3. Back in M-mode:
 *        a) mstatus.MPRV must read 0.
 *        b) Enable Sv39 with root[2] (which covers VA 0x80000000.., where the
 *           data segment lives) marked invalid, then load `victim`.
 *           With MPRV cleared the load is plain untranslated M-mode and must
 *           return the stored magic.  With stale MPRV (MPP is U after the
 *           mrets) the load is translated and permission checked as U-mode and
 *           faults on the invalid PTE -> trap -> FAIL.
 */

#include "test.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* crt.S's `la trap_handler` binds to its own weak copy, so point mtvec at
   * our handler ourselves. */
  la t0, trap_handler
  csrw mtvec, t0

  /* Store the magic value into `victim` (plain M-mode, untranslated). */
  la t0, victim
  li t1, 0x472A888215BE7A51
  sd t1, 0(t0)

  /* Explicitly clear root[2], the 1 GiB leaf covering VA 0x80000000.., so a
   * translated access in that range faults.  Everything is translated only
   * through MPRV (fetched/executed M-mode code never touches the MMU). */
  la t0, s_root
  sd zero, 16(t0)

  /* Stage 1: raise MPRV while still in M-mode, then mret back to S-mode. */
  li t0, (1 << 17)
  csrs mstatus, t0                    /* MPRV = 1               */
  ENTER_MODE(1, smode_stub)           /* MPP = S, mret          */

  /* Stage 2: S-mode stub -- trap straight back into M-mode. */
  .align 2
smode_stub:
  ecall

  /* M-mode trap handler. */
  .align 2
trap_handler:
  csrr t0, mstatus
  srli t0, t0, 11
  andi t0, t0, 3                      /* MPP at trap time       */
  li t1, 1
  bne t0, t1, .Lbad_trap              /* expected: ECALL from S */
  la t0, mmode_resume
  csrw mepc, t0
  li t1, (3 << 11)
  csrs mstatus, t1                    /* MPP = M for the return */
  mret
.Lbad_trap:
  FAIL(1)

  /* Stage 3: back in M-mode. */
  .align 2
mmode_resume:
  /* (a) An mret that returned to S-mode must have cleared MPRV. */
  csrr t0, mstatus
  srli t0, t0, 17
  andi t0, t0, 1
  bnez t0, .Lbad_mprv

  /* (b) Turn on Sv39 and make `victim` readable only untranslated. */
  la t0, s_root
  srli t0, t0, 12
  li t1, (8 << 60)                    /* satp.mode = Sv39       */
  or t0, t0, t1
  csrw satp, t0
  sfence.vma zero, zero

  la t0, victim
  ld t1, 0(t0)                        /* must be untranslated   */
  li t2, 0x472A888215BE7A51
  bne t1, t2, .Lbad_value

  PASS

.Lbad_mprv:
  FAIL(4)
.Lbad_value:
  FAIL(3)

  .data
  .align 12
  .globl s_root
s_root:
  .space 4096                         /* no valid leaves at all */
victim:
  .dword 0