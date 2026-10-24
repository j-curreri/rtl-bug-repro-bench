    .global test_main
    .text
    test_main:
      # Enter VS-mode (sets MPV=1), mret back to S-mode
      ENTER_VS(enter_vs_handler)
      # From S-mode with MPV=1, set MPP=M and mret back to M-mode
      # On correct core: MPV should be ignored when returning to M-mode
      # On buggy core: MPV would not be ignored, leaving v=1 (inconsistent)
      PASS

    enter_vs_handler:
      # Enter mode 0 (M-mode) and return to test_main
      ENTER_MODE(0, test_main)
