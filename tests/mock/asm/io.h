/* SPDX-License-Identifier: GPL-2.0+ */
#ifndef STUB_TEST_IO_H
#define STUB_TEST_IO_H
u32 test_readl(unsigned long reg);
void test_writel(u32 value, unsigned long reg);
#define readl(reg) test_readl((unsigned long)(reg))
#define writel(value, reg) test_writel((value), (unsigned long)(reg))
#define setbits_le32(reg, bits) writel(readl(reg) | (bits), reg)
#define clrbits_le32(reg, bits) writel(readl(reg) & ~(bits), reg)
#define clrsetbits_le32(reg, clear, set) writel((readl(reg) & ~(clear)) | (set), reg)
#endif
