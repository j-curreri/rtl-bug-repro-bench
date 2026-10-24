/* Bug reproducer: G-stage on + VS-stage Bare -> VS-mode instruction fetch at a
 * valid 41-bit guest-physical address must succeed.  The buggy core raises a
 * page fault (its IF canonical check only accepts < 2^38) so this FAILs there,
 * while a spec-compliant core executes the mapped code and PASSes.
 *
 * Setup:
 *   - One 1 GiB G-stage leaf in g_root maps GPA region [2^39, 2^39+1GiB)
 *     onto the HPA region [0x80000000, 0x80000000+1GiB) (where our code lives).
 *   - `land` sits at HPA L.  We fetch in VS-mode from GPA G = 2^39 | (L & 0x3FFFFFFF),
 *     which the G-stage maps to HPA L.
 *   - Correct core: fetch L (`mret`) -> VSRET to HS at hs_ecall -> ecall -> M-mode,
 *     marker==0 -> PASS.
 *   - Buggy core:   fetch G faults -> traps to HS at hstatus.htvec=fault_hs ->
 *     marker set -> ecall -> M-mode -> FAIL.
 */
#include "hyp.h"

  HYP_TABLES

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  # marker = 0 (cleared before we enter VS-mode)
  la   t0, marker
  li   t1, 0
  sd   t1, 0(t0)

  # G-stage: 1 GiB leaf, g_root[512]: GPA [2^39,2^39+1GiB) -> HPA [0x80000000,+1GiB)
  GIGA_LEAF(g_root, 512, 0x80000000, G_RWX)
  HGATP_ON

  # HS-mode landing / fault-handling addresses
  li   t0, HSTATUS_SPVP
  csrs hstatus, t0
  la   t0, hs_ecall
  csrw vsepc, t0
  la   t0, fault_hs
  csrw stvec, t0

  # G = 2^39 | (&land & 0x3FFFFFFF)  ->  G[29:0] == L[29:0], so G maps onto L
  la   t0, land
  li   t1, 0x3FFFFFFF
  and  t2, t0, t1
  li   t1, 0x8000000000
  add  t2, t1, t2

  # mret into VS-mode (V=1, S-priv) at PC = G
  li   t0, (3 << 11)
  csrc mstatus, t0
  li   t0, (1 << 11)
  csrs mstatus, t0
  li   t0, MSTATUS_MPV
  csrs mstatus, t0
  csrw mepc, t2
  mret

  .align 2
land:
  mret                 # VS-mode: VSRET -> HS-mode at vsepc (hs_ecall)

hs_ecall:
  ecall                # HS-mode: S-ecall -> M-mode  (success path)

fault_hs:              # HS-mode fault handler (hstatus.htvec target)
  la   t1, marker
  li   t0, 1
  sd   t0, 0(t1)       # record that we took a fault
  ecall                # -> M-mode  (fault path)

  .globl trap_handler
trap_handler:
  la   t1, marker
  ld   t0, 0(t1)
  beqz t0, pass_it
  FAIL(5)              # a guest fault occurred on the high-GPA fetch
pass_it:
  PASS

  .data
marker: .dword 0
