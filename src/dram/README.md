# Maintained DRAM resume sources

These are ordinary C files compiled directly by the stub Makefile. No build
script copies or rewrites the U-Boot DRAM driver.

They derive from U-Boot v2026.01 (127a42c7257a6ffbbd1575ed1cbaa8f5408a44b3):
`arch/arm/mach-sunxi/dram_sun50i_h616.c`, `dram_dw_helpers.c`, and
`dram_timings/h616_lpddr4_2133.c`. Original GPL notices are preserved.

Resume adaptations skip cold DRAM initialization, release pad retention at the
resume transition, bound calibration polling, retain RTC progress markers,
and use the known geometry instead of destructive size detection. MMIO access
semantics and barriers are supplied by the stub compatibility headers.

Compiling these directly maintained files produced the same 18,784-byte stub
hash as the validated implementation: 41991c392ab68ce1e6ca0185f485f261442945bf034ceb44baf9456b9bc3741a.
