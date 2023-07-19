set_global_assignment -entity "pll_ram" -library "lib_pll_ram" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "pll_ram" -library "lib_pll_ram" -name IP_TOOL_VERSION "21.1"
set_global_assignment -entity "pll_ram" -library "lib_pll_ram" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_pll_ram" -name SPD_FILE [file join $::quartus(sip_path) "pll_ram.spd"]

set_global_assignment -library "lib_pll_ram" -name MISC_FILE [file join $::quartus(sip_path) "pll_ram_sim/pll_ram.vo"]
