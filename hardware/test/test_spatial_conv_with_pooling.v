module test_spatial_conv_with_pooling (
    input  wire CLOCK_50,
    input  wire [9:0] SW,
    input  wire [3:0] KEY,
    output wire [9:0] LEDR,
    output wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
);

    localparam ADDR_WIDTH  = 16;
    localparam DATA_WIDTH  = 32;
    localparam FRAC_WIDTH  = 16;
    localparam N_ROWS      = 108; // Imagem original: 2014. Imagem redimensionada: 108
    localparam N_COLS      = 160; // Imagem original: 320. Imagem redimensionada: 160
    localparam KERNEL_SIZE = 3;
    localparam STEP_SIZE   = 1;
    localparam BUFFER_SIZE = (KERNEL_SIZE-1)*N_COLS + KERNEL_SIZE;
    localparam POOL_SIZE   = 2;
    
    wire pll_clock, pll_locked;

    pll PLL_0 (
        .refclk  (CLOCK_50),  // refclk.clk
        .rst     (1'b0),      // reset.reset
        .outclk_0(pll_clock), // outclk0.clk
        .outclk_1(),
        .locked  (pll_locked) // locked.export
    );

    wire ram_wren;
    wire [DATA_WIDTH-1:0] ram_data_in, ram_data_out;
    reg  [ADDR_WIDTH-1:0] ram_rdaddress = 0;
    reg  [ADDR_WIDTH-1:0] ram_wraddress = 0;

    assign ram_wren    = pool_valid;
    assign ram_data_in = pool_result;

    ram_input_image RAMI (
        .address (ram_rdaddress),
        .clock   (pll_clock),
        .data    (),
        .wren    (1'b0),
        .q       (ram_data_out)
    );

    ram_output_image RAMO (
        .address (ram_wraddress),
        .clock   (pll_clock),
        .data    (ram_data_in),
        .wren    (ram_wren),
        .q       ()
    );

    wire [DATA_WIDTH-1:0] buffered_input_window [0:KERNEL_SIZE*KERNEL_SIZE-1];

    window_buffer #(
        .DATA_WIDTH  (DATA_WIDTH),
        .LINE_LENGTH (N_COLS),
        .WINDOW_SIZE (KERNEL_SIZE)
    ) INPUT_WINDOW_BUFFER (
        .clk_i    (system_clock),
        .data_i   (ram_data_out),
        .enable_i (1'b1),
        .window_o (buffered_input_window)
    );

    reg [DATA_WIDTH-1:0] conv_kernel [0:KERNEL_SIZE*KERNEL_SIZE-1] = '{
        32'hffff0000, 32'hffff0000, 32'hffff0000,
        32'h00020000, 32'h00020000, 32'h00020000,
        32'hffff0000, 32'hffff0000, 32'hffff0000
    };
    wire [DATA_WIDTH-1:0] conv_result;
    wire conv_overflow; 

    spatial_conv_kernel #(
        .DATA_WIDTH  (DATA_WIDTH),
        .FRAC_WIDTH  (FRAC_WIDTH),
        .KERNEL_SIZE (KERNEL_SIZE)
    ) SPATIAL_CONV_KERNEL_0 (
        .window   (buffered_input_window),
        .kernel   (conv_kernel),
        .result   (conv_result),
        .overflow (conv_overflow),
    );

    wire [DATA_WIDTH-1:0] buffered_pool_window [0:POOL_SIZE*POOL_SIZE-1];

    window_buffer #(
        .DATA_WIDTH  (DATA_WIDTH),
        .LINE_LENGTH (N_COLS-2),
        .WINDOW_SIZE (POOL_SIZE)
    ) POOL_WINDOW_BUFFER (
        .clk_i    (system_clock),
        .data_i   (conv_result),
        .enable_i (conv_valid),
        .window_o (buffered_pool_window)
    );

    wire [DATA_WIDTH-1:0] pool_result;

    max_pool_2x2 #(
        .DATA_WIDTH (DATA_WIDTH)
    ) POOL_2x2_0 (
        .data_i   (buffered_pool_window),
        .result_o (pool_result)
    );

    reg [$clog2(N_COLS-2):0] conv_cols_left = N_COLS - 2;
    reg [$clog2(N_ROWS-3):0] conv_rows_left = N_ROWS - 3;

    reg conv_valid = 0;

    wire pool_valid;
    reg  pool_valid_sel = 0;

    reg [$clog2(2*(N_COLS-2)):0] pool_elements = 0; 

    always @(posedge system_clock) begin
        if(conv_valid) begin
            pool_elements = pool_elements + 1;
            if(pool_elements == N_COLS) begin
                pool_valid_sel <= 1;
            end
        end else if(pool_elements == 2*(N_COLS-2)) begin
            pool_valid_sel <= 0;
            pool_elements  <= 0;
        end
        if(pool_valid) begin
            ram_wraddress = ram_wraddress + 1;
        end
    end

    assign pool_valid = pool_valid_sel ? ((pool_elements-N_COLS) % 2 == 0) : 0;

    reg [$clog2(KERNEL_SIZE):0] cycles_to_align = 0;
    reg [$clog2(BUFFER_SIZE):0] cycles_to_first_window = BUFFER_SIZE;

    localparam [4:0]  // States
    WAIT_PLL_LOCKED_S   = 0,
    WAIT_FIRST_WINDOW_S = 1,
    VALID_CONV_S        = 2,
    WAIT_ALIGNMENT_S    = 3,
    CONVOLUTION_DONE_S  = 4;

    reg [4:0] curr_state = 0;

    wire system_clock;

    /**** Convolution control ****/
    always @(posedge system_clock) begin
        case(curr_state)
            WAIT_PLL_LOCKED_S: begin
                if(pll_locked) begin
                    curr_state <= WAIT_FIRST_WINDOW_S;
                end else begin
                    curr_state <= WAIT_PLL_LOCKED_S;
                end
            end

            WAIT_FIRST_WINDOW_S: begin
                ram_rdaddress <= ram_rdaddress + 1;
                cycles_to_first_window = cycles_to_first_window - 1;
                if(cycles_to_first_window == 0) begin
                    conv_valid <= 1;
                    curr_state <= VALID_CONV_S;
                end else begin
                    curr_state <= WAIT_FIRST_WINDOW_S;
                end
            end

            VALID_CONV_S: begin
                ram_rdaddress  <= ram_rdaddress + 1;
                conv_cols_left  = conv_cols_left - 1;
                if(conv_cols_left == 0) begin
                    conv_valid <= 0;
                    if(conv_rows_left == 0) begin
                        curr_state <= CONVOLUTION_DONE_S;
                    end else begin
                        cycles_to_align <= KERNEL_SIZE - 1;
                        conv_rows_left  <= conv_rows_left - 1;
                        curr_state      <= WAIT_ALIGNMENT_S;
                    end
                end else begin
                    curr_state <= VALID_CONV_S;
                end
            end

            WAIT_ALIGNMENT_S: begin
                conv_cols_left  <= N_COLS - 2;
                ram_rdaddress   <= ram_rdaddress + 1;
                cycles_to_align  = cycles_to_align - 1;
                if(cycles_to_align == 0) begin
                    conv_valid <= 1;
                    curr_state <= VALID_CONV_S;
                end else begin
                    curr_state <= WAIT_ALIGNMENT_S;
                end
            end

            CONVOLUTION_DONE_S: begin
                curr_state <= CONVOLUTION_DONE_S;
            end

            default: begin
                curr_state <= CONVOLUTION_DONE_S;
            end
        endcase
    end
    /**************************/

    /**** Debug signals ****/
    wire debug_clock;
    assign system_clock = CLOCK_50;

    fdiv FDIV_0 (
        .clkin(CLOCK_50),
        .div(SW[3:0]),
        .reset(~KEY[3]),
        .clkout(debug_clock)
    );

    reg [9:0] debug_led = 0;

    always @(posedge system_clock) begin
        case(curr_state)
            WAIT_PLL_LOCKED_S   : debug_led[0] <= 1;
            WAIT_FIRST_WINDOW_S : debug_led[1] <= 1;
            VALID_CONV_S        : debug_led[2] <= 1;
            WAIT_ALIGNMENT_S    : debug_led[3] <= 1;
            CONVOLUTION_DONE_S  : debug_led[4] <= 1;
            default             : debug_led[5] <= 1;
        endcase
    end

    assign debug_led[9] = system_clock;
    assign debug_led[8] = conv_overflow;
    assign debug_led[7] = conv_valid;
    assign debug_led[6] = pool_valid;

    assign LEDR = debug_led;

    reg [15:0] debug_hex_display;
    always @(*) begin
        case(SW[9:6])
            0:  debug_hex_display <= buffered_input_window[0][31:16];
            1:  debug_hex_display <= buffered_input_window[1][31:16];
            2:  debug_hex_display <= buffered_input_window[2][31:16];
            3:  debug_hex_display <= buffered_input_window[3][31:16];
            4:  debug_hex_display <= buffered_input_window[4][31:16];
            5:  debug_hex_display <= buffered_input_window[5][31:16];
            6:  debug_hex_display <= buffered_input_window[6][31:16];
            7:  debug_hex_display <= buffered_input_window[7][31:16];
            8:  debug_hex_display <= buffered_input_window[8][31:16];
            15: debug_hex_display <= conv_result[31:16];
            default: debug_hex_display <= 16'habab;
        endcase
    end

    decoder7 D4 (
        .In  (curr_state),
        .Out (HEX4)
    );
    decoder7 D3 (
        .In  (debug_hex_display[15:12]),
        .Out (HEX3)
    );
    decoder7 D2 (
        .In  (debug_hex_display[11:8]),
        .Out (HEX2)
    );
    decoder7 D1 (
        .In  (debug_hex_display[7:4]),
        .Out (HEX1)
    );
    decoder7 D0 (
        .In  (debug_hex_display[3:0]),
        .Out (HEX0)
    );
    /***************************/
endmodule
