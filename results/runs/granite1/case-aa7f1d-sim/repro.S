#include "test.h"
#include "hyp.h"

.global test_main

test_main:
  PMP_ALLOW_ALL
  ENTER_VS test_main
  mret
  PASS
