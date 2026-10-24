#include "hyp.h"

  /* 4K diagnostic: root[0]->table1[0]->table2[x] 4K leaves.
     table0@0x80003000, table1@0x80004000, table2@0x80005000, data@0x80006000.
     Maps: VA 0x1000->PA 0x80001000 (tohost), VA 0x2000->PA 0x80002000 (code),
           VA 0x6000->PA 0x80006000 (data).  VA = PA - 0x80000000. */
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Prepare test data */
  la t0, data_word
  li t1, 0x1122334455667788
  sd t1, 0(t0)

  /* table0[0] = pointer to table1 (0x80004000, PPN 0x80004) */
  RAW_PTE(table0, 0, 0x20001001)
  /* table1[0] = pointer to table2 (0x80005000, PPN 0x80005) */
  RAW_PTE(table1, 0, 0x20002001)
  /* table2[1] = 4K leaf tohost PA 0x80001000 (PPN 0x80001) */
  RAW_PTE(table2, 1, 0x200004df)
  /* table2[2] = 4K leaf code PA 0x80002000 (PPN 0x80002) */
  RAW_PTE(table2, 2, 0x200008df)
  /* table2[6] = 4K leaf data PA 0x80006000 (PPN 0x80006) */
  RAW_PTE(table2, 6, 0x200018df)

  fence rw, rw

  la t0, table0
  srli t0, t0, 12
  li t1, SATP_SV39
  or t0, t0, t1
  csrw satp, t0

  /* mret to S-mode at VA of s_entry */
  la s2, s_entry
  li s1, 0x80000000
  sub s2, s2, s1
  li t0, 3 << 11
  csrc mstatus, t0
  li t0, 1 << 11
  csrs mstatus, t0
  csrw mepc, s2
  mret

s_entry:
  .align 2
  li s1, 0x80000000
  la t0, s_trap
  sub t0, t0, s1
  csrw stvec, t0
  la t0, data_word
  sub t0, t0, s1
  ld t1, 0(t0)
  li t2, 0x1122334455667788
  bne t1, t2, s_fail
  jal x0, s_pass

s_fail:
  li a0, (100 << 1) | 1
  jal x0, s_halt

s_pass:
  li a0, 1
s_halt:
  la t0, tohost
  sub t0, t0, s1
  sd a0, 0(t0)
1: j 1b

s_trap:
  li a0, (101 << 1) | 1
  jal x0, s_halt

  .data
  .align 12
table0: .space 4096
  .align 12
table1: .space 4096
  .align 12
table2: .space 4096
  .align 12
data_word: .space 4096
