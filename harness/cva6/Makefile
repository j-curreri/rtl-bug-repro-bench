# Build a reproducer: make TEST=path/to/test.S  ->  build/<name>.elf
CC     := riscv-none-elf-gcc
ARCH   ?= rv64gc_zicsr_zifencei_h
ABI    ?= lp64d
TEST   ?=
NAME   := $(basename $(notdir $(TEST)))
HERE   := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

build/$(NAME).elf: $(TEST) $(HERE)crt.S $(HERE)test.h $(HERE)link.ld
	@mkdir -p build
	$(CC) -march=$(ARCH) -mabi=$(ABI) -mcmodel=medany -nostdlib -nostartfiles -static -Wl,--no-warn-rwx-segments \
	  -I$(HERE) -T$(HERE)link.ld $(HERE)crt.S $(TEST) -o $@
