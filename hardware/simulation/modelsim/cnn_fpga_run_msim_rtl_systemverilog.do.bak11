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

vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/activation {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/activation/relu.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/arithmetics {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/arithmetics/fixed_mult.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/buffers {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/buffers/kernel_buffer.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/buffers {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/buffers/window_buffer.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/conv_winograd {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/conv_winograd/winograd_4x4_conv_core.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/conv_winograd {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/conv_winograd/winograd_4x4_conv_kernel.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/conv_winograd {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/conv_winograd/winograd_4x4_data_transformation.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/fully_connected {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/fully_connected/fully_connected.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/memory {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/memory/rom_fully_connected_0.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/memory {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/memory/rom_kernel_weights_0.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/memory {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/memory/rom_kernel_weights_1.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/pll {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/pll/pll.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/pooling {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/pooling/max_pool_2x2.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram/ram_input_image.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/ram/ram_output_image.v}
vlog -sv -work work +incdir+/home/artur/Documents/UNB/TG/cnn_fpga/hardware/test {/home/artur/Documents/UNB/TG/cnn_fpga/hardware/test/test_winograd_simple_mnist.v}

do "/home/artur/Documents/UNB/TG/cnn_fpga/hardware/simulation/modelsim/test_winograd_fully_connected_tb.do"
