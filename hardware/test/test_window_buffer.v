module test_window_buffer (
    input  wire CLOCK_50,
    input  wire [9:0] SW,
    input  wire [3:0] KEY,
    output wire [9:0] LEDR,
    output wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
);

    localparam DATA_WIDTH  = 8;
    localparam LINE_LENGTH = 4;
    localparam WINDOW_SIZE = 3;

    wire test_clock;
    wire [DATA_WIDTH-1:0] test_data;
    assign test_data  = SW[7:0];
    assign test_clock = ~KEY[0];

    wire [DATA_WIDTH-1:0] test_window [0:WINDOW_SIZE*WINDOW_SIZE-1];
    wire test_buffer_full, test_window_valid;

    window_buffer #(
        .DATA_WIDTH  (DATA_WIDTH),
        .LINE_LENGTH (LINE_LENGTH),
        .WINDOW_SIZE (WINDOW_SIZE)
    ) WINDOW_BUFFER_0 (
        .clk_i    (test_clk),
        .data_i   (test_data),
        .enable_i (1'b1),
        .window_o (test_window)
    );

    assign LEDR[0] = test_clk;
    assign LEDR[2] = test_buffer_full;
    assign LEDR[4] = test_window_valid;

    wire [7:0] display_line [0:2];

    always @(*) begin
        case (SW[9:8])
        0: begin
            display_line[0] <= test_window[0];
            display_line[1] <= test_window[1];
            display_line[2] <= test_window[2];
        end
        1: begin
            display_line[0] <= test_window[3];
            display_line[1] <= test_window[4];
            display_line[2] <= test_window[5];
        end
        2: begin
            display_line[0] <= test_window[6];
            display_line[1] <= test_window[7];
            display_line[2] <= test_window[8];
        end
        default: begin
            display_line[0] <= 0;
            display_line[1] <= 0;
            display_line[2] <= 0;
        end
        endcase
    end

    decoder7 D5 (
        .In (display_line[0][7:4]),
        .Out(HEX5)
    );
    decoder7 D4 (
        .In (display_line[0][3:0]),
        .Out(HEX4)
    );
    decoder7 D3 (
        .In (display_line[1][7:4]),
        .Out(HEX3)
    );
    decoder7 D2 (
        .In (display_line[1][3:0]),
        .Out(HEX2)
    );
    decoder7 D1 (
        .In (display_line[2][7:4]),
        .Out(HEX1)
    );
    decoder7 D0 (
        .In (display_line[2][3:0]),
        .Out(HEX0)
    );
endmodule