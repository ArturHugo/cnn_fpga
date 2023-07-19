transcript on
if ![file isdirectory cnn_fpga_iputf_libs] {
	file mkdir cnn_fpga_iputf_libs
}

if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

###### Libraries for IPUTF cores 
###### End libraries for IPUTF cores 
###### MIF file copy and HDL compilation commands for IPUTF cores 


vlog "/home/artur/Documents/UNB/TG/cnn_fpga/hardware/pll/ram/pll_ram_sim/pll_ram.vo"   
vlog "/home/artur/Documents/UNB/TG/cnn_fpga/hardware/pll/slow/pll_slow_sim/pll_slow.vo"

vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/arithmetics {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/arithmetics/fixed_mult.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/buffers {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/buffers/kernel_buffer.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/buffers {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/buffers/window_buffer.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/conv_spatial {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/conv_spatial/spatial_conv_core.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/conv_spatial {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/conv_spatial/spatial_conv_kernel.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/pll {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/pll/pll.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/pooling {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/pooling/max_pool_2x2.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram/ram_input_image.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram/ram_kernel_weights_0.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram/ram_kernel_weights_1.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram/ram_output_image.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/utils {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/utils/decoder7.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/test {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/test/test_spatial_conv_core_kernels.v}

vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/simulation/modelsim {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/simulation/modelsim/test_spatial_conv_core_kernels_tb.v}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  test_spatial_conv_core_kernels_tb
add wave *

add wave -position insertpoint  \
sim:/test_spatial_conv_core_kernels_tb/ramo_wraddress
add wave -position insertpoint  \
sim:/test_spatial_conv_core_kernels_tb/data_valid

add wave -position insertpoint  \
sim:/test_spatial_conv_core_kernels_tb/SPATIAL_CONV_CORE_0/conv_rows_left
add wave -position insertpoint  \
sim:/test_spatial_conv_core_kernels_tb/SPATIAL_CONV_CORE_0/hold_data_internal
add wave -position insertpoint  \
sim:/test_spatial_conv_core_kernels_tb/SPATIAL_CONV_CORE_0/hold_data_aux
add wave -position insertpoint  \
sim:/test_spatial_conv_core_kernels_tb/SPATIAL_CONV_CORE_0/data_i
add wave -position insertpoint  \
sim:/test_spatial_conv_core_kernels_tb/SPATIAL_CONV_CORE_0/buffered_elements
add wave -position insertpoint  \
sim:/test_spatial_conv_core_kernels_tb/SPATIAL_CONV_CORE_0/input_window
add wave -position insertpoint  \
sim:/test_spatial_conv_core_kernels_tb/SPATIAL_CONV_CORE_0/pool_window
add wave -position insertpoint  \
sim:/test_spatial_conv_core_kernels_tb/SPATIAL_CONV_CORE_0/channel_accumulator
add wave -position insertpoint  \
sim:/test_spatial_conv_core_kernels_tb/SPATIAL_CONV_CORE_0/reset_accumulator

view structure
view signals
run -all
