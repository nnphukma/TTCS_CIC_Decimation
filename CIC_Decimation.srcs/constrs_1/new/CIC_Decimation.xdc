
# =========================================================
# CLOCK CONSTRAINTS - ARTY A7-100T
# =========================================================

# 100 MHz onboard clock
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk]

# Clock period = 10 ns (100 MHz)
create_clock -period 10.000 -name sys_clk [get_ports clk]
