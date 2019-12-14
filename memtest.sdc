derive_pll_clocks
derive_clock_uncertainty

set_clock_groups -exclusive -group [get_clocks { *|vpll|vpll_inst|altera_pll_i|*[*].*|divclk}]
