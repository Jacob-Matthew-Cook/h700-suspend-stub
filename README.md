# h700-suspend-stub

The SRAM program that Trusted Firmware-A runs for PSCI `SYSTEM_SUSPEND` on
the Allwinner H616/H700 (Anbernic RG35XX/RG34XX/RG40XX/RG28XX family). It puts
DRAM into self-refresh, gates the clocks, waits for the wake interrupt and
re-initialises DRAM without touching its contents, so Linux resumes the same
session.

Written by [kailashrs](https://github.com/kailashrs/H700_rocknix_enhancement);
this repository is the ROCKNIX packaging of that work. GPL-2.0-or-later, see
COPYING.

## Layout

- `src/` – the stub: entry and exception vectors (`start.S`), the suspend
  sequence (`main.c`), self-refresh entry (`dram_sr.c`), clocks (`clock.c`),
  helpers and the watchdog (`lib.c`).
- `compat/` – the freestanding environment U-Boot's DRAM driver needs.
- `dram-resume.patch` – the 28-line resume path applied to U-Boot's own
  `dram_sun50i_h616.c` at build time; the bootloader's copy is never touched.
- `stub.lds` – SRAM A1 layout.
- `Makefile` – builds one stub for one memory type.

## Building

The Makefile expects, from the caller:

| variable | meaning |
|---|---|
| `SRC_DIR` | this directory |
| `UBOOT_DIR` | an unpacked U-Boot tree (its DRAM driver and Kconfig are used) |
| `ATF_DIR` | an unpacked TF-A tree carrying `sunxi_suspend_params.h` |
| `DEFCONFIG` | the U-Boot defconfig the stub is built for |
| `OUT` | output file name, written to `SRC_DIR` |
| `CROSS_COMPILE` | aarch64 toolchain prefix |

Run it with `make -C <build dir> -f <SRC_DIR>/Makefile ...`, once per memory
type. TF-A embeds the resulting binaries and selects the one matching the
running DRAM at boot.
