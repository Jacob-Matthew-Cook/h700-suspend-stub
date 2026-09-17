# SPDX-License-Identifier: GPL-2.0-or-later
# Builds one suspend stub. Expects SRC_DIR, UBOOT_DIR, ATF_DIR, DEFCONFIG,
# OUT and CROSS_COMPILE from the caller; run with -C in a per-variant dir.

CC := $(CROSS_COMPILE)gcc
OBJCOPY := $(CROSS_COMPILE)objcopy
KCONFIG := $(UBOOT_DIR)/arch/arm/mach-sunxi/Kconfig

CFLAGS := -I$(ATF_DIR)/plat/allwinner/sun50i_h616/include -I$(SRC_DIR)/compat -Iboards \
	-I$(UBOOT_DIR)/arch/arm/include/asm/arch-sunxi \
	-include $(SRC_DIR)/compat/stub_compat.h -include boards/board.h \
	-Os -std=gnu11 -march=armv8-a -mgeneral-regs-only -mstrict-align -mcmodel=small \
	-ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-common \
	-ffunction-sections -fdata-sections -Wall -Wno-unused-function
LDFLAGS := -march=armv8-a -mgeneral-regs-only -ffreestanding -nostdlib -static -no-pie \
	-Wl,--gc-sections -Wl,-T,$(SRC_DIR)/stub.lds -Wl,--build-id=none

DRAM_KCONFIG := $(shell grep -oE 'CONFIG_SUNXI_DRAM_H616_[A-Z0-9_]+' $(DEFCONFIG) | head -1)
ifeq ($(DRAM_KCONFIG),CONFIG_SUNXI_DRAM_H616_LPDDR4)
  DRAM_TYPE := 8
  DRAM_MSTR := (1 << 5)
  TIMINGS := h616_lpddr4_2133.c
else ifeq ($(DRAM_KCONFIG),CONFIG_SUNXI_DRAM_H616_LPDDR3)
  DRAM_TYPE := 7
  DRAM_MSTR := (1 << 3)
  TIMINGS := h616_lpddr3.c
else
  $(error suspend-stub: no known DRAM type in $(DEFCONFIG))
endif

OBJS := src/start.o src/main.o src/lib.o src/clock.o src/dram_sr.o \
	src/dram/dram_sun50i_h616.o src/dram/dram_dw_helpers.o src/dram/dram_timing.o

$(SRC_DIR)/$(OUT): stub.elf
	$(OBJCOPY) -O binary $< $@

stub.elf: $(OBJS) $(SRC_DIR)/stub.lds
	$(CC) $(LDFLAGS) $(OBJS) -o $@

src/start.o: $(SRC_DIR)/src/start.S boards/board.h | src
	$(CC) -march=armv8-a -D__ASSEMBLY__ -c $< -o $@

src/%.o: $(SRC_DIR)/src/%.c boards/board.h | src
	$(CC) $(CFLAGS) -c $< -o $@

src/dram/%.o: src/dram/%.c boards/board.h
	$(CC) $(CFLAGS) -c $< -o $@

# U-Boot's DRAM driver, with the resume path patched in; never the bootloader's own copy
src/dram/.patched: $(SRC_DIR)/dram-resume.patch | src/dram
	cp $(UBOOT_DIR)/arch/arm/mach-sunxi/dram_sun50i_h616.c \
	   $(UBOOT_DIR)/arch/arm/mach-sunxi/dram_dw_helpers.c src/dram/
	patch -d src/dram -p1 < $<
	@touch $@

src/dram/dram_sun50i_h616.c src/dram/dram_dw_helpers.c: src/dram/.patched

src/dram/dram_timing.c: $(UBOOT_DIR)/arch/arm/mach-sunxi/dram_timings/$(TIMINGS) | src/dram
	cp $< $@

src src/dram boards:
	@mkdir -p $@

# Kconfig entry for symbol s: prints "bool" for a bool, the value of an
# unconditional numeric default, or nothing. "default X if Y" is per-SoC
# and would bake in another chip's value.
define KCONFIG_DEFAULT
$$0 == "config " s { f = 1; next } \
f && /^config / { exit } \
f && /^\tbool/ { print "bool"; exit } \
f && /^\tdefault / { if ($$0 !~ / if / && $$2 ~ /^(0x[0-9a-fA-F]+|[0-9]+)$$/) print $$2; exit }
endef

# DRAM parameters: the defconfig's values, else the Kconfig default of every
# symbol the DRAM code reads. Bools are tested with #ifdef.
boards/board.h: $(DEFCONFIG) src/dram/dram_sun50i_h616.c src/dram/dram_dw_helpers.c src/dram/dram_timing.c | boards
	@grep -E '^CONFIG_(DRAM_|SUNXI_DRAM_H616_)' $< | sed -e 's/=y$$/ 1/' -e 's/=/ /' -e 's/^/#define /' > $@
	@grep -q '^#define CONFIG_DRAM_CLK ' $@ || { echo "suspend-stub: no CONFIG_DRAM_CLK in $<" >&2; exit 1; }
	@for sym in $$(grep -ohE 'CONFIG_DRAM_[A-Z0-9_]+' $(SRC_DIR)/src/*.[ch] src/dram/*.c | sort -u); do \
	  grep -q "^#define $$sym " $@ && continue; \
	  val="$$(awk -v s="$${sym#CONFIG_}" '$(KCONFIG_DEFAULT)' $(KCONFIG))"; \
	  [ "$$val" = bool ] && continue; \
	  [ -n "$$val" ] || { echo "suspend-stub: $$sym is read by the DRAM code but $(notdir $<) does not set it and its Kconfig default is not usable" >&2; exit 1; }; \
	  echo "#define $$sym $$val" >> $@; \
	done
	@echo '#define STUB_DRAM_TYPE $(DRAM_TYPE)' >> $@
	@echo '#define STUB_MSTR_DEVICETYPE $(DRAM_MSTR)' >> $@
