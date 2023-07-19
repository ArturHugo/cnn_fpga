// verilog_lint: waive-start explicit-parameter-storage-type
module window_buffer #(
    parameter DATA_WIDTH  = 32,
    parameter LINE_LENGTH = 28,
    parameter WINDOW_SIZE = 3
)(
    input  logic clk_i,
    input  logic [DATA_WIDTH-1:0] data_i,
    input  logic enable_i,
    output logic [DATA_WIDTH-1:0] window_o [WINDOW_SIZE*WINDOW_SIZE]
);
    // verilog_lint: waive-start parameter-name-style
    localparam BUFFER_SIZE = (WINDOW_SIZE-1)*LINE_LENGTH + WINDOW_SIZE;
    // verilog_lint: waive-stop parameter-name-style

    reg [DATA_WIDTH-1:0] buffer [BUFFER_SIZE];
    reg [$clog2(WINDOW_SIZE):0] row, col;

    always_comb begin
        for(row = 0; row < WINDOW_SIZE; row = row+1) begin : window_row_loop
            for(col = 0; col < WINDOW_SIZE; col = col+1) begin : window_col_loop
                window_o[WINDOW_SIZE*row + col] = buffer[LINE_LENGTH*row + col];
            end
        end
    end

    always @(posedge clk_i) begin
        if(enable_i) begin
            buffer[0:BUFFER_SIZE-2] = buffer[1:BUFFER_SIZE-1];
            buffer[BUFFER_SIZE-1] = data_i;
        end
    end

endmodule
