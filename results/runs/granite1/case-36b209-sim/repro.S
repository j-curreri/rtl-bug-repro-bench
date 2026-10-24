.section .data
.align 14
g_root: .space 16384
vs_root: .space 4096

test_data:
    .word 0x12345678
    .zero 0x1000

.section .text
.globl test_main
test_main:
  # PMP_ALLOW_ALL
  li t0, -1
  csrw pmpaddr0, t0
  li t0, 0x1f
  csrw pmpcfg0, t0

  # SATP_SV39 = 0x8000000000000000
  li t1, 0x8000000000000000

  # HGATP_ON
  la t0, g_root
  srli t0, t0, 12
  or t0, t0, t1
  csrw hgatp, t0

  # VSATP_ON
  li t1, 0x8000000000000000
  or a0, a0, t1
  csrw vsatp, a0

  # ENTER_VS(test_main)
  li t0, 0x8000000000000000  # MSTATUS_MPV = 1 << 39
  csrs mstatus, t0
  li t0, 0x1800              # (3 << 11) = 6144
  csrc mstatus, t0
  li t0, 0x800                # (1 << 11) = 2048
  csrs mstatus, t0
  la t0, test_main
  csrw mepc, t0
  mret

  # GIGA_LEAF(g_root, 0, 0x8000_0000, G_RWX) - use sw for 32-bit store
  la t0, g_root
  li t1, 0
  add t0, t0, t1
  li t1, 0x800007F
  sw t1, 0(t0)

  # vs_root[0] as non-leaf pointing outside - use sw
  la t0, vs_root
  li t1, 0
  add t0, t0, t1
  li t1, 0x900007F
  sw t1, 0(t0)

  # Load from test_data at offset 0x1000
  la t0, test_data
  li t2, 0x1000
  add t1, t0, t2
  lw a0, 0(t1)

.globl trap_handler
trap_handler:
  csrr t6, mcause
  li t1, 21          # LOAD_GUEST_PAGE_FAULT = 21
  beq t6, t1, _halt_pass
  li a0, 255         # FAIL(127) = (127 << 1) | 1
  j _halt

_halt_pass:
  li a0, 1           # PASS = (0 << 1) | 1
  j _halt
