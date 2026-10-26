#include "test.h"
#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* The VS root maps VA 0x40000000 to GPA 0x80000000 with execute
     permission, which is the permission HLVX needs at the VS stage. */
  RAW_PTE(vs_root, 1, ((0x80000000 >> 12) << 10) | VS_RWX)

  /* Build a G-stage path for the first 2 MiB of DRAM.  Use 4 KiB
     leaves so the VS root page can be execute-only while the HLVX
     target remains readable and executable. */
  la t0, g_root
  li t1, (2 * 8)
  add t0, t0, t1
  la t1, g_l2
  srli t1, t1, 2
  ori t1, t1, PTE_V
  sd t1, 0(t0)

  la t0, g_l2
  la t1, g_l1
  srli t1, t1, 2
  ori t1, t1, PTE_V
  sd t1, 0(t0)

  /* Identity-map GPA 0x80000000..0x801fffff as RWX. */
  la t0, g_l1
  li t1, 0x80000000
  li t2, G_RWX
  li t3, 512
  li t5, 4096
1:
  srli t4, t1, 2
  or t4, t4, t2
  sd t4, 0(t0)
  addi t0, t0, 8
  add t1, t1, t5
  addi t3, t3, -1
  bnez t3, 1b

  /* G-stage must permit instruction fetches from vs_root but deny the
     implicit read used to fetch its VS-stage PTE. */
  la t0, vs_root
  srli t0, t0, 12
  andi t0, t0, 511
  slli t0, t0, 3
  la t1, g_l1
  add t0, t0, t1
  la t1, vs_root
  srli t1, t1, 2
  li t2, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
  or t1, t1, t2
  sd t1, 0(t0)

  /* Turn on both translation stages. */
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* HLVX.HU treats the VS mapping as an instruction fetch.  Correct
     hardware faults while reading vs_root through the execute-only
     G-stage mapping.  If the buggy core completes the walk, fail. */
  li a1, 0x40000000
  ENTER_MODE(1, do_hlvx)

  .align 2
do_hlvx:
  hlvx.hu a0, (a1)
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21                 /* Load guest-page fault */
  beq t0, t1, expected_fault
  FAIL(3)
expected_fault:
  PASS

  HYP_TABLES
  .align 12
g_l2: .space 4096
  .align 12
g_l1: .space 4096
