# Reproducer for: plain HLV succeeds on a G-stage execute-only page after an
# HLVX populated the DTLB for that page.
#
# Setup: hgatp (Sv39x4) maps the 1 GiB DRAM region 0x80000000..0xBFFFFFFF with an
# execute-only G-stage leaf (V|X|U|A|D, no R, no W). vsatp is bare, so guest
# virtual address == guest physical address. The HLV/HLVX are executed in M-mode;
# the core then performs the access as if in VS-mode at hstatus.SPVP privilege
# (S here) with two-stage translation (VS stage bare -> G stage only).
#
# Sequence across the same guest page (DATA):
#   1. HLV  cold  (DTLB miss - PTW walk): must fault (load guest-page fault)
#                 - identical on fixed and buggy core, sanity/canary phases.
#   2. HLVX       : must succeed (HLVX may use execute-only pages).
#   3. HLV  warm  (DTLB hit on entry cached by the HLVX): must fault
#                 (only HLVX may treat execute as read). This is the point of
#                 the bug: on the buggy core this load also succeeds.
#
# FAIL codes: 2 plain HLV did not trap, 3 HLVX returned the wrong data,
#             4 phase-2 sanity, 7 canary trap cause, 8 trap during HLVX,
#             64 canary phase did not trap.

#include "hyp.h"

  .text
  .globl test_main
test_main:
  # let U/S-mode (and hypervisor page-table walkers) touch everything
  PMP_ALLOW_ALL

  # put a known 32-bit word in DRAM (normal M-mode store, satp is bare here)
  la t1, DATA
  li t2, 0x12345678
  sw t2, 0(t1)

  # G-stage (Sv39x4): leaf 2 covers 0x80000000..0xBFFFFFFF, execute-only (no R).
  # must be readable through the G stage, so make leaf 0 unmapped for the canary
  GIGA_LEAF(g_root, 2, 0x80000000, PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
  RAW_PTE(g_root, 0, 0)
  RAW_PTE(g_root, 1, 0)

  HGATP_ON

  # HLV/HSV/HLVX accesses run at hstatus.SPVP privilege (S)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  # ---- phase 1 (s0 = 0): HLV to an unmapped GPA must trap ----
  li s0, 0
  li t1, 0x10000000          # inside 1 GiB leaf 0, which has V=0
  hlv.wu t4, 0(t1)
  FAIL(64)                   # not reached on a working core

resume1:
  # ---- phase 2 (s0 = 1): cold HLV on the execute-only page must trap ----
  li s0, 1
  la t1, DATA                # guest page mapped X-only by G-stage leaf 2
  hlv.wu t4, 0(t1)           # DTLB miss: the PTW check rejects the load
  FAIL(4)                    # not reached on any core

resume2:
  # ---- phase 3 (s0 = 2): HLVX on the execute-only page must succeed ----
  li s0, 2
  hlvx.wu t3, 0(t1)          # populates the DTLB for this page
  li t2, 0x12345678
  bne t3, t2, 2f
  # ---- phase 4 (s0 = 3): plain HLV on the now-hot page must trap ----
  li s0, 3
  hlv.wu t4, 0(t1)           # reliable on a correct core: load guest-page fault
  FAIL(2)                    # reached only on the buggy core
2:FAIL(3)                    # HLVX read back the wrong value

# our own trap handler (overrides the weak default in crt.S). s0 carries the
# phase in which the trap was expected.
  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t2, 0
  beq s0, t2, 10f
  li t2, 1
  beq s0, t2, 11f
  li t2, 3
  beq s0, t2, 12f
  FAIL(8)                    # trap during the HLVX itself
10:li t2, 21                 # canary: expect load guest-page fault
  bne t6, t2, 13f
14:la t0, resume1
  csrw mepc, t0
  mret
11:li t2, 21
  bne t6, t2, 13f
  la t0, resume2
  csrw mepc, t0
  mret
12:PASS                      # a trap in phase 4 means the plain HLV no
                             # longer inherits execute-as-read: bug fixed.
13:FAIL(7)                   # a sanity phase trapped for the wrong reason

  HYP_TABLES

  .align 4
  .globl DATA
DATA:
  .word 0x12345678