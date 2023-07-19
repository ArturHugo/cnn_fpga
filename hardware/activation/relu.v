// verilog_lint: waive-start explicit-parameter-storage-type
module relu #(
    parameter DATA_WIDTH = 32
) (
    input  [DATA_WIDTH-1:0] data_i,
    output [DATA_WIDTH-1:0] result_o
);

    assign result_o = data_i[DATA_WIDTH-1] ? 0 : data_i;

endmodule
