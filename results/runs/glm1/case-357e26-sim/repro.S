// Bug reproducer: PMP TOR region top extends 4 bytes past the grain-correct
// boundary when pmpaddr is written odd (bit0 = 1). Grain is 8 bytes (G = 1),
// so the low grain bits of pmpaddr must not widen the region; a correct core
// makes the effective TOR top grain-aligned at 4*(pmpaddr & ~1), and U-mode
// accesses at/above that address fault. This core honors the stored bit0 in
// the TOR compare, so the 4-byte span [T, T+4) leaks to U-mode:
//
//   entry0 : TOR, RWX, unlocked, pmpaddr0 written 0x20002001 (bit0 = 1)
//   readback pmpaddr0 = 0x20002000  ->  spec top T = 4*0x20002000 = 0x80008000
//   correct: U-mode access at T matches no entry (entries 1..7 OFF)
//            -> access fault
//   buggy  : top = 4*0x20002001 = 0x80008004 -> word access at T is inside
//
// U-mode sequence:
//   lw  at T-8   (inside the region: must never trap on any correct core)
//   lw  at T     (must trap, cause 5 = load access fault)
//   sw  at T     (must trap, cause 7 = store access fault)
//
// PASS on a spec-correct core = all three expected behaviors observed.
// FAIL(1) load @T did not trap   /  FAIL(2) store @T did not trap  /
// FAIL(3) sanity load @T-8 trapped  /  FAIL(4) access fault from wrong PC  /
// FAIL(5) entry0 config readback != 0x0f
//      FAIL(n) -> tohost = (n<<1)|1; unexpected traps halt with that cause.

#include "test.h"

  .section .text.init
  .globl trap_handler
  .globl test_main

test_main:
  csrw satp, zero

  // entries 1..7 off so nothing else can match below the top
  li t0, 0
  csrw pmpaddr1, t0
  csrw pmpaddr2, t0
  csrw pmpaddr3, t0
  csrw pmpaddr4, t0
  csrw pmpaddr5, t0
  csrw pmpaddr6, t0
  csrw pmpaddr7, t0

  // entry0: TOR top written ODD (bit0 = 1)
  li t0, 0x20002001
  csrw pmpaddr0, t0
  li t0, 0x0f                     // R=1 W=1 X=1 A=TOR(01) L=0
  csrw pmpcfg0, t0

  // guard: config byte must read back exactly as written (no WARL ambiguity
  // is expected for R|W|X|TOR|L=0)
  csrr t1, pmpcfg0
  andi t1, t1, 0xff
  li t2, 0x0f
  bne t1, t2, .Lcfg_bad

  // enter U-mode
  ENTER_MODE(0, u_start)

u_start:
  li a1, 0x80008000               // T (grain-correct TOR top)
  la t3, flags

  // sanity: T-8 is inside the region, must not trap
  lw t2, -8(a1)                   // rd = x7 -> 4-byte encoding on purpose
sanity_done:
  li s1, 1
  sw s1, 0(t3)                    // sanity_ok = 1

  // decisive probes at T: outside the grain-correct region, inside on the
  // buggy core (leaky 4-byte span [T, T+4))
probe_t:
  lw t2, 0(a1)                    // correct core: load access fault (5)
after_probe_t:
probe_s:
  sw t2, 0(a1)                    // correct core: store access fault (7)
after_probe_s:
  ecall                           // back to M-mode for the verdict

// ---- verdict (M-mode) -----------------------------------------------------
m_end:
  la s0, flags
  lw t1, 0(s0)                    // sanity_ok
  lw t2, 4(s0)                    // t_fault
  lw t3, 8(s0)                    // s_fault
  seqz t4, t1
  seqz t5, t2
  seqz t6, t3
  or  t4, t4, t5
  or  t4, t4, t6
  beqz t4, .Lall_ok
  // failure: report which expectation broke
  beqz t1, .Lsanity_bad           // sanity load trapped -> FAIL(3)
  beqz t2, .Lload_bad             // load @T not trapped -> FAIL(1)
  FAIL(2)                         // store @T not trapped
.Lload_bad:
  FAIL(1)
.Lsanity_bad:
  FAIL(3)
.Lall_ok:
  PASS

// ---- trap handling --------------------------------------------------------
trap_handler:
  csrr t5, mcause
  li t4, 8
  beq t5, t4, .Lecall

  li t4, 5                        // load access fault
  beq t5, t4, .Lload_fault
  li t4, 7                        // store access fault
  beq t5, t4, .Lstore_fault
  // unexpected trap cause -> FAIL with the cause encoded in tohost
  slli a0, t5, 1
  ori a0, a0, 1
  j _halt

.Lload_fault:
  // load fault must come from the lw @T probe
  csrr t6, mepc
  la t4, probe_t
  bne t6, t4, .Lbad_mepc
  li t4, 1
  la t3, flags
  sw t4, 4(t3)                    // t_fault = 1
  csrr t4, mepc
  addi t4, t4, 4
  csrw mepc, t4
  mret

.Lstore_fault:
  // store fault must come from the sw @T probe
  csrr t6, mepc
  la t4, probe_s
  bne t6, t4, .Lbad_mepc
  li t4, 1
  la t3, flags
  sw t4, 8(t3)                    // s_fault = 1
  csrr t4, mepc
  addi t4, t4, 4
  csrw mepc, t4
  mret

.Lbad_mepc:
  // access fault from an unexpected PC -> FAIL(4)
  li a0, 9
  j _halt

.Lecall:
  la t4, m_end
  csrw mepc, t4
  li t3, (3 << 11)                // MPP = M
  csrs mstatus, t3
  mret

.Lcfg_bad:
  FAIL(5)

  .section .data
  .globl flags
  .balign 4
flags:
  .word 0                         // sanity_ok
  .word 0                         // t_fault
  .word 0                         // s_fault