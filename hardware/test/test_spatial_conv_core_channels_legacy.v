module test_spatial_conv_core_channels (
    input  wire CLOCK_50,
    input  wire [9:0] SW,
    input  wire [3:0] KEY,
    output wire [9:0] LEDR,
    output wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
);

    localparam ADDR_WIDTH  = 16;
    localparam DATA_WIDTH  = 32;
    localparam FRAC_WIDTH  = 16;
    localparam N_ROWS      = 28;
    localparam N_COLS      = 28;
    localparam N_CHANNELS  = 3; 
    localparam N_KERNELS   = 1;
    localparam KERNEL_SIZE = 3;
    localparam CONV_STRIDE = 1;
    localparam POOL_SIZE   = 2;
    localparam POOL_STRIDE = 2;
    localparam OUTPUT_WINDOW_SIZE = 3;

    localparam BUFFER_SIZE = (KERNEL_SIZE-1)*N_COLS + KERNEL_SIZE;

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
    reg  [ADDR_WIDTH-1:0] ram_rdaddress [0:N_CHANNELS-1] = '{
        0, N_ROWS*N_COLS, 2*N_ROWS*N_COLS 
    };
    reg  [ADDR_WIDTH-1:0] ram_wraddress = 0;

    assign ram_wren    = result_valid[curr_channel];
    assign ram_data_in = conv_result[0][0];

    ram_input_image RAMI (
        .address (ram_rdaddress[curr_channel]),
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

    always @(posedge system_clock, posedge global_reset) begin
        if(global_reset) begin
            ram_wraddress <= 0;
        end else if(ram_wren) begin
            ram_wraddress <= ram_wraddress + 1;
        end
    end

    wire [DATA_WIDTH-1:0] buffered_input_window [0:N_CHANNELS-1][0:KERNEL_SIZE*KERNEL_SIZE-1];

    reg [$clog2(N_CHANNELS):0] curr_channel = 0;

    genvar channel;
    generate
        for(channel = 0; channel < N_CHANNELS; channel = channel + 1) begin : channel_loop
            window_buffer #(
                .DATA_WIDTH  (DATA_WIDTH),
                .LINE_LENGTH (N_COLS),
                .WINDOW_SIZE (KERNEL_SIZE)
            ) INPUT_WINDOW_BUFFER (
                .clk_i    (system_clock),
                .data_i   (ram_data_out),
                .enable_i (!hold_window[channel]),
                .window_o (
                    buffered_input_window[
                        channel
                    ]
                )
            );
        end
    endgenerate

    reg [DATA_WIDTH-1:0] conv_kernel [0:N_CHANNELS-1][0:KERNEL_SIZE*KERNEL_SIZE-1] = '{
        '{
            32'hffff0000, 32'hffff0000, 32'hffff0000,
            32'h00020000, 32'h00020000, 32'h00020000,
            32'hffff0000, 32'hffff0000, 32'hffff0000
        },
        '{
            32'hffff0000, 32'hffff0000, 32'hffff0000,
            32'h00020000, 32'h00020000, 32'h00020000,
            32'hffff0000, 32'hffff0000, 32'hffff0000
        },
        '{
            32'hffff0000, 32'hffff0000, 32'hffff0000,
            32'h00020000, 32'h00020000, 32'h00020000,
            32'hffff0000, 32'hffff0000, 32'hffff0000
        }
    };

    wire [DATA_WIDTH-1:0] conv_result [0:N_KERNELS-1][0:OUTPUT_WINDOW_SIZE*OUTPUT_WINDOW_SIZE-1];
    wire result_valid [0:N_CHANNELS-1];
    wire hold_kernel  [0:N_CHANNELS-1];
    wire hold_window  [0:N_CHANNELS-1];
    wire conv_overflow;

    spatial_conv_core #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .FRAC_WIDTH (FRAC_WIDTH),

        .N_ROWS     (N_ROWS),
        .N_COLS     (N_COLS),
        .N_CHANNELS (N_CHANNELS),
        .N_KERNELS  (N_KERNELS),

        .KERNEL_SIZE(KERNEL_SIZE),
        .CONV_STRIDE(CONV_STRIDE),

        .POOL_SIZE  (POOL_SIZE),
        .POOL_STRIDE(POOL_STRIDE),

        .OUTPUT_WINDOW_SIZE(OUTPUT_WINDOW_SIZE)
    ) SPATIAL_CONV_KERNEL_0 (
        // TODO usando apenas para debug
        .debug_conv_valid(debug_conv_valid),
        .debug_pool_valid(debug_pool_valid),
        .debug_acc(debug_acc),
        

        .clock_i       (system_clock),
        .reset_i       (global_reset),
        .window_valid_i(window_valid),
        .kernel_valid_i('{default: 1'b1}),
        .hold_window_i ('{default: 1'b0}),
        .window_i      (buffered_input_window),
        .kernel_i      (conv_kernel),
        .bias_i        ({(DATA_WIDTH){1'b0}}),
        .window_o      (conv_result),
        .window_valid_o(result_valid),
        .hold_kernel_o (hold_kernel),
        .hold_window_o (hold_window),
        .conv_overflow (conv_overflow)
    );

    // TODO usando apenas para debug
    logic debug_conv_valid [0:N_KERNELS-1];
    logic debug_pool_valid [0:N_KERNELS-1];
    logic [DATA_WIDTH-1:0] debug_acc;

    reg [$clog2(N_COLS-2):0] conv_cols_left [0:N_CHANNELS-1] = '{default: N_COLS - 2};
    reg [$clog2(N_ROWS-2):0] conv_rows_left [0:N_CHANNELS-1] = '{default: N_ROWS - 2};

    reg window_valid [0:N_CHANNELS-1] = '{default: 0};

    reg [$clog2(KERNEL_SIZE):0] cycles_to_align [0:N_CHANNELS-1] = '{default: 0};
    reg [$clog2(BUFFER_SIZE):0] cycles_to_first_window [0:N_CHANNELS-1] = '{default: BUFFER_SIZE};

    localparam [2:0]  // States
    READ_DATA_S = 0,
    HOLD_DATA_S = 1,
    NEXT_CHANNEL_S = 2,
    READ_DONE_S = 3;

    reg [4:0] curr_state = 0;

    wire system_clock;

    reg [$clog2(BUFFER_SIZE+N_COLS-KERNEL_SIZE):0] buffered_elements [0:N_CHANNELS-1] = '{default: 0};

    reg [$clog2(OUTPUT_WINDOW_SIZE-1):0] alignment_counter = 0;

    always @(posedge system_clock, posedge global_reset) begin
        if(global_reset) begin
            for(curr_channel = 0; curr_channel < N_CHANNELS; curr_channel = curr_channel+1) begin
                ram_rdaddress[curr_channel] <= curr_channel*N_ROWS*N_COLS;
            end
            curr_channel      <= 0;
            alignment_counter <= 0;
            buffered_elements <= '{default: 0};
            window_valid      <= '{default: 0};
            conv_rows_left    <= '{default: N_ROWS - 2};

            curr_state <= 0;

            debug_led[6:0] <= 0;
        end else if(pll_locked) begin
            case(curr_state)
                READ_DATA_S: begin
                    if(hold_window[curr_channel]) begin
                        curr_state <= HOLD_DATA_S;

                        debug_led[0] <= 1;
                    end else begin
                        ram_rdaddress[curr_channel] <= ram_rdaddress[curr_channel] + 1;
                        buffered_elements[curr_channel] = buffered_elements[curr_channel] + 1;

                        if(buffered_elements[curr_channel] == BUFFER_SIZE+N_COLS-KERNEL_SIZE) begin
                            window_valid[curr_channel]      <= 0;
                            buffered_elements[curr_channel]  = BUFFER_SIZE-1-KERNEL_SIZE;
                            conv_rows_left[curr_channel]     = conv_rows_left[curr_channel] - 1;
                            
                            curr_state <= NEXT_CHANNEL_S;

                            debug_led[1] <= 1;
                        end else
                        if(buffered_elements[curr_channel] >= BUFFER_SIZE-1) begin
                            window_valid[curr_channel] <= 1;

                            debug_led[2] <= 1;
                        end
                    end
                end

                HOLD_DATA_S: begin
                    if(hold_window[curr_channel]) begin
                        curr_state <= NEXT_CHANNEL_S;

                        debug_led[3] <= 1;
                    end else begin
                        curr_state <= READ_DATA_S;

                        debug_led[4] <= 1;
                    end
                end

                NEXT_CHANNEL_S: begin
                    curr_channel = curr_channel + 1;
                    if(curr_channel == N_CHANNELS) begin
                        curr_channel = 0;
                    end

                    if(conv_rows_left[curr_channel] == 0) begin
                        curr_state <= NEXT_CHANNEL_S;
                    end else begin
                        curr_state <= READ_DATA_S;
                    end

                    debug_led[5] <= 1;
                end

                READ_DONE_S: begin
                    curr_state   <= READ_DONE_S;

                    debug_led[6] <= 1;
                end

                default: curr_state <= READ_DONE_S;
            endcase
        end
    end

    // always @(posedge system_clock, posedge global_reset) begin
    //     if(global_reset) begin
    //         for(curr_channel = 0; curr_channel < N_CHANNELS; curr_channel = curr_channel+1) begin
    //             ram_rdaddress[curr_channel] <= curr_channel*N_ROWS*N_COLS;
    //         end
    //         curr_channel      <= 0;
    //         alignment_counter <= 0;
    //         buffered_elements <= '{default: 0};
    //         window_valid      <= '{default: 0};
    //         conv_rows_left    <= '{default: N_ROWS - 2};

    //         // TODO debug
    //         debug_led[6:0] <= 0;
    //     end else if(pll_locked) begin
    //         // TODO debug
    //         debug_led[0] <= 1;
    //         if(conv_rows_left[curr_channel] != 0) begin
    //             if(hold_window[curr_channel]) begin
    //                 if(buffered_elements[curr_channel] == BUFFER_SIZE + N_COLS - KERNEL_SIZE) begin
    //                     // TODO tirar debug
    //                     debug_led[4] <= 1;

    //                     window_valid[curr_channel]      <= 0;
    //                     buffered_elements[curr_channel]  = BUFFER_SIZE-KERNEL_SIZE;
    //                     // alignment_counter = KERNEL_SIZE; //TODO acho que nao precisa mais

    //                     conv_rows_left[curr_channel] = conv_rows_left[curr_channel] - 1;

    //                     //BUG fica preso no estado 1 depois da primeira linha
    //                 end
                
    //                 // If current channel is holding, go to next
    //                 curr_channel = curr_channel + 1;
    //                 if(curr_channel == N_CHANNELS) begin
    //                     curr_channel <= 0;
    //                     debug_led[1] <= 1; // TODO deletar depois
    //                 end

    //                 // TODO apagar depois, usando apenas para debug
    //                 curr_state <= 1;
    //                 debug_led[2] <= 1;
    //             end else begin
    //                 // TODO tirar debug
    //                 debug_led[3] <= 1;

    //                 ram_rdaddress[curr_channel] <= ram_rdaddress[curr_channel] + 1;
    //                 buffered_elements[curr_channel] = buffered_elements[curr_channel] + 1;
    //                 // if(alignment_counter > 0) begin
    //                 //     alignment_counter = alignment_counter - 1;
    //                 // end else //TODO acho que nao precisa mais. O proprio buffer elements cuida do alinhamento
    //                 // TODO testar buffer size -1 para garantir que nao seja feita mais uma leitura
    //                 // depois de chegar em uma janela valida

    //                 // if(buffered_elements[curr_channel] == BUFFER_SIZE + N_COLS - KERNEL_SIZE -1) begin
    //                 //     window_valid[curr_channel]      <= 0;
    //                 //     debug_led[6] <= 1;
    //                 // end else
    //                 // if(buffered_elements[curr_channel] == BUFFER_SIZE + N_COLS - KERNEL_SIZE) begin
    //                 //     // TODO tirar debug
    //                 //     debug_led[4] <= 1;

    //                 //     window_valid[curr_channel]      <= 0;
    //                 //     buffered_elements[curr_channel]  = BUFFER_SIZE-1-KERNEL_SIZE;
    //                 //     // alignment_counter = KERNEL_SIZE; //TODO acho que nao precisa mais

    //                 //     conv_rows_left[curr_channel] = conv_rows_left[curr_channel] - 1;

    //                 //     //BUG fica preso no estado 1 depois da primeira linha
    //                 // end else 
    //                 if(buffered_elements[curr_channel] >= BUFFER_SIZE-1) begin
    //                     // TODO tirar debug
    //                     debug_led[5] <= 1;
                        
    //                     window_valid[curr_channel] <= 1;
    //                 end

    //                 // TODO apagar depois, usando apenas para debug
    //                 curr_state <= 2;
    //             end
    //         end
    //     end
    // end

    /**** Debug signals ****/
    wire global_reset = ~KEY[3];

    wire debug_clock;
    // assign system_clock = ~KEY[0];
    // assign system_clock = debug_clock;
    // assign system_clock = CLOCK_50;
    
    assign system_clock = SW[1] ? ~KEY[0] : (SW[0] ? debug_clock : CLOCK_50);

    fdiv FDIV_0 (
        .clkin(CLOCK_50),
        .div(SW[3:2]),
        .reset(~KEY[3]),
        .clkout(debug_clock)
    );

    reg [9:0] debug_led = 0;

    // always @(posedge system_clock, posedge global_reset) begin
    //     if(global_reset) begin
    //         debug_led[5:3] <= 0;
    //         debug_led[1:0] <= 0;
    //     end else if(pll_locked) begin
    //         debug_led[0] <= 1;
    //         if(hold_window[curr_channel]) begin
    //             debug_led[1] <= 1;
    //             if(curr_channel == N_CHANNELS) begin
    //                 // debug_led[2] <= 1;
    //             end
    //         end else begin
    //             debug_led[3] <= 1;
    //             if(alignment_counter > 0) begin
    //                 debug_led[4] <= 1;
    //             end else if(buffered_elements[curr_channel] >= BUFFER_SIZE) begin
    //                 debug_led[5] <= 1;
    //             end

    //             if(buffered_elements[curr_channel] == BUFFER_SIZE + N_COLS - KERNEL_SIZE) begin
    //                 // debug_led[6] <= 1;
    //             end
    //         end
    //     end
    // end

    assign debug_led[9] = system_clock;
    assign debug_led[8] = conv_overflow;
    // assign debug_led[7] = conv_valid;
    // assign debug_led[6] = pool_valid;

    assign LEDR = debug_led;

    wire [1:0] debug_channel = SW[5:4];

    reg [15:0] debug_hex_display;
    always @(*) begin
        case(SW[9:6])
            0:  debug_hex_display <= curr_channel;
            1:  debug_hex_display <= ram_rdaddress[debug_channel];
            2:  debug_hex_display <= ram_wraddress;
            3:  debug_hex_display <= buffered_elements[debug_channel];
            4:  debug_hex_display <= alignment_counter;
            5:  debug_hex_display <= hold_window[debug_channel];
            6:  debug_hex_display <= window_valid[debug_channel];
            7:  debug_hex_display <= result_valid[debug_channel];
            8:  debug_hex_display <= debug_conv_valid[0];
            9:  debug_hex_display <= debug_pool_valid[0];
            10: debug_hex_display <= debug_acc[31:16];
            11: debug_hex_display <= ram_data_out[31:16];
            12: debug_hex_display <= conv_rows_left[debug_channel];
            13: debug_hex_display <= buffered_input_window[debug_channel][0][31:16];
            15: debug_hex_display <= conv_result[0][0][31:16];
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
