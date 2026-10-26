  .section .text
  .globl test_main
test_main:
  /* Configure an unlocked 16-byte NAPOT region around probe.  M-mode ignores
     unlocked entries, so the first call executes normally and warms I-cache. */
  la t0, probe
  srli t0, t0, 2
  ori t0, t0, 1
  csrw pmpaddr0, t0
  li t0, 0x1f                /* RWX, NAPOT, unlocked */
  csrw pmpcfg0, t0
  call probe

  /* Lock the same entry with execute permission clear.  The next fetch from
     probe must fault even if its instruction bytes are already cached. */
  li t0, 0x98                /* L=1, NAPOT, no permissions */
  csrw pmpcfg0, t0
  la t0, probe
  la ra, after_probe
  jr t0
after_probe:
  li a0, 3
  j _halt

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 1                   /* Instruction access fault */
  bne t0, t1, unexpected_trap
  csrr t0, mepc
  la t1, probe
  bne t0, t1, unexpected_trap
  li a0, 1
  j _halt

unexpected_trap:
  li a0, 5
  j _halt

  .section .text.probe, "ax"
  .balign 16
probe:
  ret
  .rept 3
  nop
  .endr
