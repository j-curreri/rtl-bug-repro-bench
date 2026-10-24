#include "test.h"
  .option norvc

#define NAPOT(base, size) (((base) | ((size)/2 - 1)) >> 2)
#define A_TOR   (1<<3)
#define A_NAPOT (3<<3)
#define CFG_ALL (0x1f << 56)

/* program entry i with address value in t3 and cfg byte c; entry 7 allows all */
#define SETPMP(i, c)                \
  csrw pmpaddr##i, t3;              \
  li t0, -1; csrw pmpaddr7, t0;     \
  li t0, (((c) << (8*(i))) | CFG_ALL); \
  csrw pmpcfg0, t0

#define CHECK(n, addrexpr, op, exp) \
  la a1, addrexpr; li a2, op; call probe; li t2, exp; li a3, n; bne a0, t2, fail

  .text
  .globl test_main
test_main:
  csrw pmpcfg0, zero
  /* Case 1: NAPOT 8B at buf+0x100 no perms, entry 0 */
  la t3, buf+0x100; srli t3, t3, 2
  SETPMP(0, A_NAPOT)
  CHECK(1, buf+0x100, 0, 5)
  CHECK(2, buf+0x108, 0, 0)
  CHECK(3, buf+0xf8, 0, 0)
  CHECK(4, buf+0x104, 4, 7)
  CHECK(5, buf+0x104, 3, 5)
  /* Case: NAPOT 4K at buf, R only, entry 3 */
  la t3, buf; li t0, 0x7ff; or t3, t3, t0; srli t3, t3, 2
  SETPMP(3, A_NAPOT|1)
  CHECK(10, buf+0x800, 0, 0)
  CHECK(11, buf+0xff8, 1, 7)
  CHECK(12, buf+0x1000, 1, 0)
  CHECK(13, buf, 1, 7)
  /* NAPOT 64K at buf, no perms, entry 5 */
  la t3, buf; li t0, 0x7fff; or t3, t3, t0; srli t3, t3, 2
  SETPMP(5, A_NAPOT)
  CHECK(20, buf+0xfff8, 0, 5)
  CHECK(21, buf+0x8000, 1, 7)
  CHECK(22, buf+0x10000, 0, 0)
  /* TOR [buf+0x1000, buf+0x3000) no perms: entries 1,2 */
  la t3, buf+0x1000; srli t3, t3, 2; csrw pmpaddr1, t3
  la t3, buf+0x3000; srli t3, t3, 2
  SETPMP(2, A_TOR)
  CHECK(30, buf+0x1000, 0, 5)
  CHECK(31, buf+0x2ff8, 1, 7)
  CHECK(32, buf+0x3000, 0, 0)
  CHECK(33, buf+0xff8, 0, 0)
  /* TOR entry 0 from 0 to buf+0x2000, RX only */
  la t3, buf+0x2000; srli t3, t3, 2
  SETPMP(0, A_TOR|5)
  CHECK(40, buf+0x1ff8, 0, 0)
  CHECK(41, buf+0x1ff8, 1, 7)
  CHECK(42, buf+0x2000, 1, 0)
  /* exec: NAPOT 4K over xpage, RW only, entry 6 */
  la t3, xpage; li t0, 0x7ff; or t3, t3, t0; srli t3, t3, 2
  SETPMP(6, A_NAPOT|3)
  CHECK(50, xpage, 2, 1)
  CHECK(51, xpage2, 2, 0)
#include "big.inc"
#include "sweep.inc"
#include "vm.inc"
#include "amo.inc"
#include "hi.inc"

#include "lock.inc"
#include "lock2.inc"
  PASS
fail:
  mv a0, a3
  slli a0, a0, 1; ori a0, a0, 1; j _halt

/* a1 = addr, a2 = op (0 ld, 1 sd, 2 jump) -> a0 = mcause or 0 */
probe:
  sfence.vma
  mv s9, ra
  la s10, 1f
  li s11, 0
  ENTER_MODE(0, uprobe)
1:
  mv a0, s11
  mv ra, s9
  ret


uprobe:
  li t0, 1
  beq a2, t0, 2f
  li t0, 2
  beq a2, t0, 3f
  li t0, 3
  beq a2, t0, 4f
  li t0, 4
  beq a2, t0, 5f
  li t0, 5
  beq a2, t0, 6f
  li t0, 6
  beq a2, t0, 7f
  li t0, 7
  beq a2, t0, 8f
  ld t1, 0(a1)
  ecall
2: sd zero, 0(a1)
  ecall
3: jr a1
4: lw t1, 0(a1)
  ecall
6: amoadd.d t1, a2, (a1)
  ecall
7: la t1, buf+0x5000
  sd zero, 0(t1)
  sd zero, 0(a1)
  ecall
8: amoswap.w t1, a2, (a1)
  ecall
5: sw zero, 0(a1)
  ecall

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 10
  beq t0, t1, 1f
  li t1, 9
  beq t0, t1, 1f
  li t1, 8
  beq t0, t1, 1f
  mv s11, t0
1: jr s10

  .align 12
xpage:
  ecall
  .align 12
xpage2:
  ecall

  .data
  .align 17
buf: .zero 0x30000
  .align 12
pt_root: .zero 4096
pt_l1: .zero 4096
pt_l0: .zero 4096

