module avg_pool_2x2 #(
    parameter DATA_WIDTH = 32
)(
    input  wire signed [DATA_WIDTH-1:0] data_i [0:3],
    output wire signed [DATA_WIDTH-1:0] result_o
);
    assign result_o = (data_i[0] + data_i[1] + data_i[2] + data_i[3]) >> 2;
endmodule