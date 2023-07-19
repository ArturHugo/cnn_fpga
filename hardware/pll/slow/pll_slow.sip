set_global_assignment -entity "pll_slow" -library "lib_pll_slow" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "pll_slow" -library "lib_pll_slow" -name IP_TOOL_VERSION "21.1"
set_global_assignment -entity "pll_slow" -library "lib_pll_slow" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_pll_slow" -name SPD_FILE [file join $::quartus(sip_path) "pll_slow.spd"]

set_global_assignment -library "lib_pll_slow" -name MISC_FILE [file join $::quartus(sip_path) "pll_slow_sim/pll_slow.vo"]
