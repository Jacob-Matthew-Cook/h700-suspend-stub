/* SPDX-License-Identifier: GPL-2.0+ */
/*
 * DRAM parameters of the Anbernic H700 LPDDR4 boards, taken from ROCKNIX's
 * anbernic_rg35xx_h700_lpddr4_defconfig (U-Boot v2026.01). They must match
 * the SPL that brought DRAM up at boot, otherwise resume re-trains DRAM
 * with different settings.
 */

#define CONFIG_DRAM_CLK				672
#define CONFIG_SUNXI_DRAM_H616_LPDDR4		1
#define CONFIG_DRAM_SUNXI_PHY_ADDR_MAP_1	1
#define CONFIG_DRAM_SUNXI_DX_ODT		0x08080808
#define CONFIG_DRAM_SUNXI_DX_DRI		0x0e0e0e0e
#define CONFIG_DRAM_SUNXI_CA_DRI		0x0e0e
#define CONFIG_DRAM_SUNXI_ODT_EN		0x7887bbbb
#define CONFIG_DRAM_SUNXI_TPR0			0x0
#define CONFIG_DRAM_SUNXI_TPR2			0x1
#define CONFIG_DRAM_SUNXI_TPR6			0x40808080
#define CONFIG_DRAM_SUNXI_TPR10			0x402f6633
#define CONFIG_DRAM_SUNXI_TPR11			0x1b1f1e1c
#define CONFIG_DRAM_SUNXI_TPR12			0x06060606

/* SUNXI_DRAM_TYPE_LPDDR4 */
#define STUB_DRAM_TYPE				8
/* uMCTL2 MSTR device type bit for this memory (MSTR_DEVICETYPE_LPDDR4) */
#define STUB_MSTR_DEVICETYPE			(1 << 5)
