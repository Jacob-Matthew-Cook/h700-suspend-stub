/* SPDX-License-Identifier: GPL-2.0+ */
/* Fault injection against the actual clock.c and dram_sr.c, with mocked MMIO. */
#include <assert.h>
#include <setjmp.h>
#include <stdio.h>
#include "stub.h"
#include <asm/arch/clock.h>

struct reg_value { unsigned long reg; u32 value; } regs[128];
static unsigned int nr_regs, nr_waits, wait_index;
static bool waits[4];
static jmp_buf fatal_return;
static u32 fatal_kind, fatal_result, first_kind;
static unsigned long fatal_reg;
struct sunxi_suspend_params stub_params;

u32 test_readl(unsigned long reg)
{
	for (unsigned int i = 0; i < nr_regs; i++)
		if (regs[i].reg == reg)
			return regs[i].value;
	return 0;
}

void test_writel(u32 value, unsigned long reg)
{
	for (unsigned int i = 0; i < nr_regs; i++) {
		if (regs[i].reg == reg) {
			regs[i].value = value;
			return;
		}
	}
	assert(nr_regs < ARRAY_SIZE(regs));
	regs[nr_regs++] = (struct reg_value){reg, value};
}

bool wait_reg(unsigned long reg, u32 mask, u32 value, unsigned long timeout)
{
	(void)reg; (void)mask; (void)value;
	assert(timeout > 0 && wait_index < nr_waits);
	return waits[wait_index++];
}

void udelay(unsigned long us) { (void)us; }
void stub_fail_record(unsigned long reg, u32 kind)
{
	(void)reg;
	if (!first_kind)
		first_kind = kind;
}

__attribute__((noreturn)) void stub_fatal(unsigned long reg, u32 kind, u32 result)
{
	fatal_reg = reg;
	fatal_kind = kind;
	fatal_result = result;
	longjmp(fatal_return, 1);
}

static void reset_state(bool first, bool second)
{
	nr_regs = wait_index = fatal_kind = fatal_result = first_kind = 0;
	fatal_reg = 0;
	nr_waits = 2;
	waits[0] = first;
	waits[1] = second;
	test_writel(0x101, SUNXI_DRAM_CTL0_BASE + 0x30);
	test_writel(0xfeed, SUNXI_DRAM_CTL0_BASE + 0x0c);
	test_writel(0xf, SUNXI_DRAM_COM_BASE + 0x20);
	test_writel(0x7, SUNXI_DRAM_COM_BASE + 0x24);
	test_writel(0x3, SUNXI_DRAM_COM_BASE + 0x28);
	test_writel(CCM_PLL_CTRL_EN, SUNXI_CCM_BASE + CCU_H6_PLL5_CFG);
}

static void entry_success(void)
{
	reset_state(true, true);
	assert(dram_enter_selfrefresh());
	assert(wait_index == 2);
	assert(test_readl(SUNXI_DRAM_CTL0_BASE + 0x0c) == 0);
	assert(!(test_readl(SUNXI_CCM_BASE + CCU_H6_PLL5_CFG) & CCM_PLL_CTRL_EN));
	assert(test_readl(SUNXI_DRAM_COM_BASE + 0x20) == 0);
}

static void entry_abort(bool keep_phy)
{
	reset_state(false, true);
	assert(!(keep_phy ? dram_enter_selfrefresh_keep_phy() : dram_enter_selfrefresh()));
	assert(test_readl(SUNXI_DRAM_CTL0_BASE + 0x30) == 0x101);
	assert(test_readl(SUNXI_DRAM_COM_BASE + 0x20) == 0xf);
	assert(test_readl(SUNXI_DRAM_COM_BASE + 0x24) == 0x7);
	assert(test_readl(SUNXI_DRAM_COM_BASE + 0x28) == 0x3);
	assert(test_readl(SUNXI_DRAM_CTL0_BASE + 0x0c) == 0xfeed);
	assert(first_kind == FAIL_SR_ENTER_TIMEOUT);
}

static void rollback_fails(bool keep_phy)
{
	reset_state(false, false);
	if (setjmp(fatal_return) == 0) {
		if (keep_phy)
			dram_enter_selfrefresh_keep_phy();
		else
			dram_enter_selfrefresh();
		assert(!"unsafe return after failed rollback");
	}
	assert(fatal_kind == FAIL_SR_ROLLBACK_TIMEOUT);
	assert(fatal_result == STAGE_SR_FAILED);
	assert(test_readl(SUNXI_DRAM_COM_BASE + 0x20) == 0);
	assert(test_readl(SUNXI_DRAM_COM_BASE + 0x24) == 0);
	assert(test_readl(SUNXI_DRAM_COM_BASE + 0x28) == 0);
}

static void dfi_fails(void)
{
	reset_state(true, false);
	if (setjmp(fatal_return) == 0) {
		dram_enter_selfrefresh();
		assert(!"unsafe clock gating after failed DFI shutdown");
	}
	assert(fatal_kind == FAIL_DFI_OFF_TIMEOUT);
	assert(fatal_reg == SUNXI_DRAM_CTL0_BASE + 0x1bc);
	assert(test_readl(SUNXI_DRAM_CTL0_BASE + 0x0c) == 0xfeed);
	assert(test_readl(SUNXI_CCM_BASE + CCU_H6_PLL5_CFG) & CCM_PLL_CTRL_EN);
}

static void pll_transition(bool lock)
{
	reset_state(lock, true);
	test_writel(0x03000301, SUNXI_CCM_BASE + CCU_H6_CPU_AXI_CFG);
	test_writel(0x03000302, SUNXI_CCM_BASE + CCU_H6_APB1_CFG);
	test_writel(0x03000303, SUNXI_CCM_BASE + CCU_H6_APB2_CFG);
	clocks_down();
	if (setjmp(fatal_return) == 0) {
		clocks_up();
		assert(lock);
		cpu_clock_restore();
		assert(test_readl(SUNXI_CCM_BASE + CCU_H6_CPU_AXI_CFG) == 0x03000301);
		assert(test_readl(SUNXI_CCM_BASE + CCU_H6_APB1_CFG) == 0x03000302);
		assert(test_readl(SUNXI_CCM_BASE + CCU_H6_APB2_CFG) == 0x03000303);
	} else {
		assert(!lock && fatal_kind == FAIL_CPU_PLL_TIMEOUT);
		assert(fatal_result == STAGE_CLOCK_FAILED);
		assert((test_readl(SUNXI_CCM_BASE + CCU_H6_CPU_AXI_CFG) & (3U << 24)) == 0);
	}
}

int main(void)
{
	entry_success();
	entry_abort(false);
	entry_abort(true);
	rollback_fails(false);
	rollback_fails(true);
	dfi_fails();
	pll_transition(true);
	pll_transition(false);
	puts("8 SRAM transition and fault-injection scenarios passed");
	return 0;
}
