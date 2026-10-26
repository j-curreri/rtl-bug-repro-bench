/* PMP sweep over privilege modes. entry0 is a NAPOT 4 KiB region with permissions RWX = p,
 * entry1 is off, entry2 allows everything. Row: pmpcfg0, page (0 = scratch, 1 = exec), op
 * (0 ld, 1 sd, 2 amoswap.d, 3 exec), mode (0 = U, 1 = S, 3 = M with MPRV and MPP = U), expect.
 * expect is the trap cause: 8 or 9 when allowed (ecall), 5 load fault, 7 store/AMO fault,
 * 1 instruction fetch fault. */
#include "test.h"

#define MSTATUS_MPRV (1 << 17)

  .section .data
  .align 3
trap_cause: .dword 0

  .align 12
scratch_page:
  .space 4096

  .align 12
exec_page:
  ecall
  .space 4092

  .align 3
table:
  .dword 2031640, 0, 0, 0, 5
  .dword 2031640, 0, 1, 0, 7
  .dword 2031640, 0, 2, 0, 7
  .dword 2031640, 1, 3, 0, 1
  .dword 2031641, 0, 0, 0, 8
  .dword 2031641, 0, 1, 0, 7
  .dword 2031641, 0, 2, 0, 7
  .dword 2031641, 1, 3, 0, 1
  .dword 2031643, 0, 0, 0, 8
  .dword 2031643, 0, 1, 0, 8
  .dword 2031643, 0, 2, 0, 8
  .dword 2031643, 1, 3, 0, 1
  .dword 2031644, 0, 0, 0, 5
  .dword 2031644, 0, 1, 0, 7
  .dword 2031644, 0, 2, 0, 7
  .dword 2031644, 1, 3, 0, 8
  .dword 2031645, 0, 0, 0, 8
  .dword 2031645, 0, 1, 0, 7
  .dword 2031645, 0, 2, 0, 7
  .dword 2031645, 1, 3, 0, 8
  .dword 2031647, 0, 0, 0, 8
  .dword 2031647, 0, 1, 0, 8
  .dword 2031647, 0, 2, 0, 8
  .dword 2031647, 1, 3, 0, 8
  .dword 2031640, 0, 0, 1, 5
  .dword 2031640, 0, 1, 1, 7
  .dword 2031640, 0, 2, 1, 7
  .dword 2031640, 1, 3, 1, 1
  .dword 2031641, 0, 0, 1, 9
  .dword 2031641, 0, 1, 1, 7
  .dword 2031641, 0, 2, 1, 7
  .dword 2031641, 1, 3, 1, 1
  .dword 2031643, 0, 0, 1, 9
  .dword 2031643, 0, 1, 1, 9
  .dword 2031643, 0, 2, 1, 9
  .dword 2031643, 1, 3, 1, 1
  .dword 2031644, 0, 0, 1, 5
  .dword 2031644, 0, 1, 1, 7
  .dword 2031644, 0, 2, 1, 7
  .dword 2031644, 1, 3, 1, 9
  .dword 2031645, 0, 0, 1, 9
  .dword 2031645, 0, 1, 1, 7
  .dword 2031645, 0, 2, 1, 7
  .dword 2031645, 1, 3, 1, 9
  .dword 2031647, 0, 0, 1, 9
  .dword 2031647, 0, 1, 1, 9
  .dword 2031647, 0, 2, 1, 9
  .dword 2031647, 1, 3, 1, 9
  .dword 2031640, 0, 0, 3, 5
  .dword 2031640, 0, 1, 3, 7
  .dword 2031640, 0, 2, 3, 7
  .dword 2031641, 0, 0, 3, 8
  .dword 2031641, 0, 1, 3, 7
  .dword 2031641, 0, 2, 3, 7
  .dword 2031643, 0, 0, 3, 8
  .dword 2031643, 0, 1, 3, 8
  .dword 2031643, 0, 2, 3, 8
  .dword 2031644, 0, 0, 3, 5
  .dword 2031644, 0, 1, 3, 7
  .dword 2031644, 0, 2, 3, 7
  .dword 2031645, 0, 0, 3, 8
  .dword 2031645, 0, 1, 3, 7
  .dword 2031645, 0, 2, 3, 7
  .dword 2031647, 0, 0, 3, 8
  .dword 2031647, 0, 1, 3, 8
  .dword 2031647, 0, 2, 3, 8
table_end:

  .section .text
  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  la t5, trap_cause
  sd t6, 0(t5)
  li t5, MSTATUS_MPRV
  csrc mstatus, t5
  la t5, u_done
  csrw mepc, t5
  li t5, (3 << 11)
  csrs mstatus, t5        /* return to M-mode at u_done */
  mret

  .globl test_main
test_main:
  la s0, table
  la s2, table_end
  li s1, 0
1:
  bgeu s0, s2, all_pass
  ld t0, 0(s0)
  csrw pmpcfg0, t0
  ld t3, 8(s0)            /* page select */
  la t1, scratch_page
  beqz t3, 2f
  la t1, exec_page
2:
  srli t2, t1, 2
  ori t2, t2, 511         /* NAPOT, 4 KiB */
  csrw pmpaddr0, t2
  li t2, 0
  csrw pmpaddr1, t2
  li t2, -1
  csrw pmpaddr2, t2
  mv a1, t1
  ld s4, 16(s0)           /* op */
  ld t4, 24(s0)           /* mode */
  ld s3, 32(s0)           /* expected trap cause */
  la t5, trap_cause
  sd zero, 0(t5)
  la t5, scratch_page
  sd zero, 0(t5)          /* a denied store must leave the scratch page zero */

  li t5, 1
  beq t4, t5, go_s
  li t5, 3
  beq t4, t5, go_mprv

go_u:
  la t0, u_entry
  j enter_u
go_s:
  la t0, u_entry
  li t5, (3 << 11)
  csrc mstatus, t5       /* MPP = S */
  li t5, (1 << 11)
  csrs mstatus, t5
  j set_mepc
go_mprv:
  /* M-mode with MPRV: loads and stores are checked as U-mode; no trap means allowed */
  li t5, MSTATUS_MPRV
  csrs mstatus, t5
  jal ra, run_probe
  li t5, MSTATUS_MPRV
  csrc mstatus, t5
  la t5, trap_cause
  li t0, 8
  sd t0, 0(t5)
  j u_done

enter_u:
  li t5, (3 << 11)
  csrc mstatus, t5       /* MPP = U */
set_mepc:
  csrw mepc, t0
  mret

u_entry:
  jal ra, run_probe
  ecall

u_done:
  la t0, trap_cause
  ld t1, 0(t0)
  bne t1, s3, row_fail
  /* a load or store/AMO fault must not have written the scratch page */
  li t2, 5
  beq s3, t2, 4f
  li t2, 7
  bne s3, t2, 5f
4:
  la t0, scratch_page
  ld t2, 0(t0)
  bnez t2, mem_fail
5:
  addi s0, s0, 40
  addi s1, s1, 1
  j 1b

mem_fail:
  li t1, 99
row_fail:
  addi a0, s1, 1
  li t2, 100
  mul a0, a0, t2
  add a0, a0, t1
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt

all_pass:
  PASS

/* One access to a1 selected by s4; ld/sd/amo return, exec jumps to a1. */
run_probe:
  beqz s4, rp_ld
  li t0, 1
  beq s4, t0, rp_st
  li t0, 2
  beq s4, t0, rp_amo
  jalr ra, 0(a1)
  ret
rp_ld:
  ld a2, 0(a1)
  ret
rp_st:
  sd a1, 0(a1)
  ret
rp_amo:
  amoswap.d a2, a1, (a1)
  ret
