// verilog_lint: waive-start explicit-parameter-storage-type
module bias_buffer #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,

    parameter N_CHANNELS = 1,
    parameter N_KERNELS  = 32,

    parameter BASE_ADDR = 0
) (
    input logic clock_i,
    input logic reset_i,
    input logic enable_i,
    input logic hold_kernel_i[N_CHANNELS],

    input logic [DATA_WIDTH-1:0] data_i,

    output logic [ADDR_WIDTH-1:0] ram_rdaddress_o,
    output logic [DATA_WIDTH-1:0] bias_o
);


endmodule
