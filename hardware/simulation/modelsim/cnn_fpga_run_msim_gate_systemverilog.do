transcript on
if {[file exists gate_work]} {
	vdel -lib gate_work -all
}
vlib gate_work
vmap work gate_work

vlog -sv -work work +incdir+. {cnn_fpga.svo}

vlog -vlog01compat -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/simulation/modelsim {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/simulation/modelsim/test_winograd_conv_with_pooling_tb.v}

vsim -t 1ps -L altera_ver -L altera_lnsim_ver -L cyclonev_ver -L lpm_ver -L sgate_ver -L cyclonev_hssi_ver -L altera_mf_ver -L cyclonev_pcie_hip_ver -L gate_work -L work -voptargs="+acc"  test_winograd_conv_with_pooling_tb

add wave *
view structure
view signals
run 500 ns
