# SPDX-License-Identifier: GPL-2.0+
#
# H616/H700 SRAM suspend stub for TF-A SYSTEM_SUSPEND.
#
#   make UBOOT=../u-boot BOARD=rg34xxsp_lpddr4

UBOOT		?= ../u-boot
BOARD		?= rg34xxsp_lpddr4
CROSS_COMPILE	?=
BUILD		?= build
# 1: keep DRAM controller/PHY clocked in sleep, 0: shut them down and re-train
KEEP_PHY	?= 0

CC		:= $(CROSS_COMPILE)gcc
OBJCOPY		:= $(CROSS_COMPILE)objcopy
SIZE		:= $(CROSS_COMPILE)size

UBOOT_DRAM_INC	:= $(UBOOT)/arch/arm/include/asm/arch-sunxi

CPPFLAGS	:= -Iinclude -Icompat -I$(UBOOT_DRAM_INC) \
		   -include compat/stub_compat.h -include boards/$(BOARD).h \
		   -DSTUB_DRAM_KEEP_PHY=$(KEEP_PHY)
CFLAGS		:= -Os -g -std=gnu11 -march=armv8-a -mgeneral-regs-only \
		   -mstrict-align -mcmodel=small -ffreestanding -fno-builtin \
		   -fno-pic -fno-pie -fno-stack-protector -fno-common \
		   -ffunction-sections -fdata-sections -Wall -Wno-unused-function
ASFLAGS		:= -march=armv8-a -D__ASSEMBLY__
LDFLAGS		:= -nostdlib -static -no-pie -Wl,--gc-sections -Wl,-T,stub.lds \
		   -Wl,--build-id=none -Wl,-Map,$(BUILD)/stub.map

DRAM_SRCS	:= src/dram/dram_sun50i_h616.c src/dram/dram_dw_helpers.c \
		   src/dram/dram_timing.c
SRCS		:= src/main.c src/lib.c src/clock.c src/dram_sr.c
OBJS		:= $(BUILD)/start.o $(SRCS:src/%.c=$(BUILD)/%.o) \
		   $(DRAM_SRCS:src/%.c=$(BUILD)/%.o)

all: $(BUILD)/suspend_stub.bin

$(BUILD)/start.o: src/start.S
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD)/%.o: src/%.c src/stub.h include/sunxi_suspend_params.h boards/$(BOARD).h
	@mkdir -p $(dir $@)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(BUILD)/suspend_stub.elf: $(OBJS) stub.lds
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS) -o $@
	$(SIZE) $@

$(BUILD)/suspend_stub.bin: $(BUILD)/suspend_stub.elf
	$(OBJCOPY) -O binary $< $@
	@ls -l $@

clean:
	rm -rf $(BUILD)

HOSTCC ?= cc
test:
	@mkdir -p $(BUILD)/tests
	$(HOSTCC) -std=gnu11 -Wall -Wextra -Werror -Itests/mock -Isrc \
		$(CPPFLAGS) tests/test_transitions.c src/clock.c src/dram_sr.c \
		-o $(BUILD)/tests/test_transitions
	$(BUILD)/tests/test_transitions

.PHONY: all clean test
