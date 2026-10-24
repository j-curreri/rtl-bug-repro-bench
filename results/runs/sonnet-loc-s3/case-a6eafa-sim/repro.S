#include "test.h"
  .option norvc
  .globl test_main
  .globl trap_handler
#define V 0x01
#define R 0x02
#define W 0x04
#define X 0x08
#define U 0x10
#define A 0x40
#define D 0x80
#define PTE(pa, f) (((pa) >> 12 << 10) | (f))

  .text
test_main:
  la t0, prot
  srli t0, t0, 2
  ori t0, t0, 0x1ff
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  li t0, (0x1f<<8)|0x18
  csrw pmpcfg0, t0
  la t0, trap_handler
  csrw mtvec, t0
  # sentinels
  li t0, 0x80200008
  li t1, 0x1111
  sd t1, 0(t0)
  li t0, 0x80323008
  li t1, 0x2222
  sd t1, 0(t0)
  la t0, dpage
  li t1, 0x3333
  sd t1, 0(t0)
  # root: idx0 -> l1, idx1 misaligned 1G, idx2 identity, idx3 1G leaf
  la t0, root
  la t1, l1
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, V
  sd t1, 0(t0)
  li t1, PTE(0x80001000, V|R|W|A|D)
  sd t1, 8(t0)
  li t1, PTE(0x80000000, V|R|W|X|A|D)
  sd t1, 16(t0)
  sd t1, 24(t0)
  la t1, prot
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, V
  sd t1, 32(t0)
  # l1: idx0 -> l2, idx1 2M leaf ok, idx2 misaligned 2M, idx3 nonleaf with A
  la t0, l1
  la t1, l2
  srli t1, t1, 12
  slli t1, t1, 10
  ori t2, t1, V
  sd t2, 0(t0)
  li t2, PTE(0x80200000, V|R|W|A|D)
  sd t2, 8(t0)
  li t2, PTE(0x80201000, V|R|W|A|D)
  sd t2, 16(t0)
  ori t2, t1, V|A
  sd t2, 24(t0)
  # l2 entries
  la t0, l2
  la t3, dpage
  srli t3, t3, 12
  slli t3, t3, 10
  .macro L2 idx, f
  li t1, \f
  or t1, t1, t3
  sd t1, (\idx*8)(t0)
  .endm
  L2 0, V|R|W|A|D
  L2 1, V|R
  L2 2, V|R|W|A
  L2 3, V|X|A
  L2 4, V|X|A
  L2 5, V|W|A|D
  L2 6, V|R|W|A|D|(1<<54)
  L2 7, V|R|W|U|A|D
  L2 8, V|R|W|U|A|D
  L2 9, V|R|W|A|D|(1<<63)
  L2 10, V|R|W|A|D|(1<<61)
  L2 11, R|W|A|D
  L2 12, V|X|A
  L2 13, V|X
  L2 14, V|R|A
  L2 15, V|X|U|A
  L2 16, V|R|W|X|A|D
  L2 24, V|R|A|D
  L2 25, V|R|X|A
  L2 26, V|X|A|D
  L2 27, V|R|X|A|D
  L2 17, V|R|W|A|D|(1<<55)
  L2 18, V|R|W|A|D|(1<<56)
  L2 19, V|R|W|A|D|(1<<57)
  L2 20, V|R|W|A|D|(1<<58)
  L2 21, V|R|W|A|D|(1<<59)
  L2 22, V|R|W|A|D|(1<<60)
  L2 23, V|R|W|A|D|(1<<62)
  li t0, 8<<60
  la t1, root
  srli t1, t1, 12
  or t0, t0, t1
  csrw satp, t0
  ENTER_MODE(1, smode)

smode:
  sfence.vma
  li t0, 1<<18
  csrc sstatus, t0
  sfence.vma
  .macro OK n, va, op
  li t5, 0
  li a1, \va
  \op a2, 0(a1)
  bnez t5, bad\n
  .endm
  .macro NO n, va, op
  li t5, 0
  li a1, \va
  \op a2, 0(a1)
  beqz t5, bad\n
  .endm
  OK 1, 0x0000, ld
  li t0, 0x3333
  bne a2, t0, bad1
  OK 2, 0x0000, sd
  NO 3, 0x1000, ld
  OK 4, 0x2000, ld
  NO 5, 0x2000, sd
  NO 6, 0x3000, ld
  NO 7, 0x5000, ld
  NO 8, 0x6000, ld
  NO 9, 0x7000, ld
  NO 10, 0x9000, ld
  NO 11, 0xa000, ld
  NO 12, 0xb000, ld
  # 2M leaf
  OK 13, 0x200008, ld
  li t0, 0x1111
  bne a2, t0, bad13
  OK 14, 0x323008, ld
  li t0, 0x2222
  bne a2, t0, bad14
  NO 15, 0x400000, ld
  NO 16, 0x600000, ld
  NO 17, 0x40000000, ld
  OK 18, 0xC0000000, ld
  # MXR
  li t0, 1<<19
  csrs sstatus, t0
  OK 19, 0x4000, ld
  csrc sstatus, t0
  sfence.vma
  NO 20, 0x4000, ld
  # SUM
  li t0, 1<<18
  csrs sstatus, t0
  OK 21, 0x8000, ld
  csrc sstatus, t0
  sfence.vma
  NO 22, 0x8000, ld
  .macro FOK n, va
  li t5, 0
  li a1, \va
  jalr ra, 0(a1)
  bnez t5, bad\n
  .endm
  .macro FNO n, va
  li t5, 0
  li a1, \va
  jalr ra, 0(a1)
  beqz t5, bad\n
  .endm
  la t0, dpage
  li t1, 0x00008067
  sw t1, 0(t0)
  fence.i
  FOK 23, 0xc000
  FNO 24, 0xd000
  FNO 25, 0xe000
  FNO 26, 0xf000
  FOK 27, 0x10000
  li t0, 1<<18
  csrs sstatus, t0
  sfence.vma
  FNO 28, 0xf000
  NO 29, 0x11000, ld
  NO 30, 0x12000, ld
  NO 31, 0x13000, ld
  NO 32, 0x14000, ld
  NO 33, 0x15000, ld
  NO 34, 0x16000, ld
  NO 35, 0x17000, ld
  li t5, 0
  li a1, 0x100000000
  ld a2, 0(a1)
  li t0, 5
  bne t5, t0, badp
  li t5, 0
  li a1, 0x100000000
  la ra, 3f
  jr a1
3:
  li t0, 1
  bne t5, t0, badp2
  li s1, 12
1:
  li t1, 1
  sll t1, t1, s1
  li t2, 0x80000000
  add t1, t1, t2
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, V|R|W|A|D
  la t0, root
  sd t1, 8(t0)
  sfence.vma
  li t5, 0
  li a1, 0x40000000
  ld a2, 0(a1)
  beqz t5, badm1
  addi s1, s1, 1
  li t2, 30
  blt s1, t2, 1b
  li s1, 12
2:
  li t1, 1
  sll t1, t1, s1
  li t2, 0x80200000
  add t1, t1, t2
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, V|R|W|A|D
  la t0, l1
  sd t1, 16(t0)
  sfence.vma
  li t5, 0
  li a1, 0x400000
  ld a2, 0(a1)
  beqz t5, badm2
  addi s1, s1, 1
  li t2, 21
  blt s1, t2, 2b
  NO 50, 0x18000, sd
  OK 51, 0x18000, ld
  NO 52, 0x19000, sd
  OK 53, 0x19000, ld
  NO 54, 0x1a000, sd
  NO 55, 0x1b000, sd
  OK 56, 0x1b000, ld
  PASS
badm1: mv a0, s1; slli a0,a0,1; ori a0,a0,1; j _halt
badm2: addi a0, s1, 100; slli a0,a0,1; ori a0,a0,1; j _halt
bad1: FAIL(1)
bad2: FAIL(2)
bad3: FAIL(3)
bad4: FAIL(4)
bad5: FAIL(5)
bad6: FAIL(6)
bad7: FAIL(7)
bad8: FAIL(8)
bad9: FAIL(9)
bad10: FAIL(10)
bad11: FAIL(11)
bad12: FAIL(12)
bad13: FAIL(13)
bad14: FAIL(14)
bad15: FAIL(15)
bad16: FAIL(16)
bad17: FAIL(17)
bad18: FAIL(18)
bad19: FAIL(19)
bad20: FAIL(20)
bad21: FAIL(21)
bad22: FAIL(22)
bad50: FAIL(50)
bad51: FAIL(51)
bad52: FAIL(52)
bad53: FAIL(53)
bad54: FAIL(54)
bad55: FAIL(55)
bad56: FAIL(56)
badp: FAIL(40)
badp2: FAIL(41)
bad29: FAIL(29)
bad30: FAIL(30)
bad31: FAIL(31)
bad32: FAIL(32)
bad33: FAIL(33)
bad34: FAIL(34)
bad35: FAIL(35)
bad23: FAIL(23)
bad24: FAIL(24)
bad25: FAIL(25)
bad26: FAIL(26)
bad27: FAIL(27)
bad28: FAIL(28)

  .align 2
trap_handler:
  csrr t5, mcause
  csrr t4, mepc
  li t6, 12
  beq t5, t6, 4f
  li t6, 1
  bne t5, t6, 1f
4:
  mv t4, ra
  addi t4, t4, -4
1:
  addi t4, t4, 4
  csrw mepc, t4
  mret

  .data
  .align 12
root: .space 4096
  .align 12
l1: .space 4096
  .align 12
l2: .space 4096
  .align 12
dpage: .space 4096
  .align 12
prot: .space 4096
