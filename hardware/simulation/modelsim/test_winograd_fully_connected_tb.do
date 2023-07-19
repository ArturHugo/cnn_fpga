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

vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/arithmetics {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/activation/relu.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/arithmetics {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/arithmetics/fixed_mult.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/buffers {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/buffers/kernel_buffer.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/buffers {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/buffers/window_buffer.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/conv_winograd {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/conv_winograd/winograd_4x4_conv_core.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/conv_winograd {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/conv_winograd/winograd_4x4_conv_kernel.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/conv_winograd {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/conv_winograd/winograd_4x4_data_transformation.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/pll {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/pll/pll.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/pooling {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/pooling/max_pool_2x2.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram/ram_input_image.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram/ram_kernel_weights_0.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram/ram_kernel_weights_1.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram/ram_kernel_bias_0.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram/ram_kernel_bias_1.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram/ram_fully_connected_0.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram/ram_output_image.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/utils {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/utils/decoder7.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/fully_connected {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/fully_connected/fully_connected.v}

vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/simulation/modelsim {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/simulation/modelsim/test_winograd_fully_connected_tb.v}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  test_winograd_fully_connected_tb
add wave *

add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/KERNEL_BUFFER_0/hold_kernel_i \
sim:/test_winograd_fully_connected_tb/KERNEL_BUFFER_0/kernel_valid_o \
sim:/test_winograd_fully_connected_tb/KERNEL_BUFFER_0/curr_kernel \
sim:/test_winograd_fully_connected_tb/KERNEL_BUFFER_0/kernel_o

add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/FULLY_CONNECTED_0/weights_valid \
sim:/test_winograd_fully_connected_tb/FULLY_CONNECTED_0/weight_counter \
sim:/test_winograd_fully_connected_tb/FULLY_CONNECTED_0/curr_state

add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/result_valid_0
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/result_valid_1

add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/hold_data_0
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/data_valid_0
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/data_reg
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_0/hold_data_internal
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_0/buffered_elements
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_0/conv_rows_left
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_1/conv_rows_left

add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_0/bias_i
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_0/kernel_i
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_0/conv_result
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_0/input_window
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_0/pool_window
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_0/channel_accumulator
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_0/reset_accumulator

add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_1/bias_i
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_1/kernel_i
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_1/conv_result
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_1/input_window
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_1/buffered_elements
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_1/channel_accumulator
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/WINOGRAD_4x4_CONV_CORE_1/reset_accumulator
add wave -position insertpoint  \
sim:/test_winograd_fully_connected_tb/logits


view structure
view signals
run -all
