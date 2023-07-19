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
    localparam N_ROWS      = 100; // Imagem original: 214. Imagem redimensionada: 100
    localparam N_COLS      = 100; // Imagem original: 320. Imagem redimensionada: 100
    localparam N_CHANNELS  = 3; 
    localparam N_KERNELS   = 1;
    localparam KERNEL_SIZE = 3;
    localparam CONV_STRIDE = 1;
    localparam POOL_SIZE   = 2;
    localparam POOL_STRIDE = 2;

    localparam OUTPUT_N_ROWS = N_ROWS-KERNEL_SIZE+1;
    localparam OUTPUT_N_COLS = N_COLS-KERNEL_SIZE+1;
    localparam OUTPUT_SIZE   = N_KERNELS*(OUTPUT_N_ROWS)*(OUTPUT_N_COLS)/(POOL_SIZE*POOL_SIZE);

    localparam BUFFER_SIZE = (KERNEL_SIZE-1)*N_COLS + KERNEL_SIZE;

    wire pll_clock, pll_locked;

    pll PLL_0 (
        .refclk  (CLOCK_50),  // refclk.clk
        .rst     (1'b0),      // reset.reset
        .outclk_0(pll_clock), // outclk0.clk
        .outclk_1(debug_clock),
        .locked  (pll_locked) // locked.export
    );

    wire ram_wren;
    wire [DATA_WIDTH-1:0] ram_data_in, ram_data_out;
    reg  [ADDR_WIDTH-1:0] ram_rdaddress [0:N_CHANNELS-1] = '{
        0
        , N_ROWS*N_COLS
        , 2*N_ROWS*N_COLS 
    };
    reg  [ADDR_WIDTH-1:0] ram_wraddress = 0;

    assign ram_wren    = result_valid[0] && (ram_wraddress < OUTPUT_SIZE);
    assign ram_data_in = conv_result[0];

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

    reg [$clog2(N_CHANNELS):0] curr_channel = 0;

    reg [DATA_WIDTH-1:0] conv_kernel [0:N_CHANNELS-1][0:KERNEL_SIZE*KERNEL_SIZE-1] = '{
        '{
            32'hffff0000, 32'hffff0000, 32'hffff0000,
            32'h00020000, 32'h00020000, 32'h00020000,
            32'hffff0000, 32'hffff0000, 32'hffff0000
        }
        ,'{
            32'hffff0000, 32'hffff0000, 32'hffff0000,
            32'h00020000, 32'h00020000, 32'h00020000,
            32'hffff0000, 32'hffff0000, 32'hffff0000
        }
        ,'{
            32'hffff0000, 32'hffff0000, 32'hffff0000,
            32'h00020000, 32'h00020000, 32'h00020000,
            32'hffff0000, 32'hffff0000, 32'hffff0000
        }
    };

    wire [DATA_WIDTH-1:0] conv_result [0:N_KERNELS-1];
    wire result_valid [0:N_KERNELS-1];
    wire hold_kernel  [0:N_CHANNELS-1];
    wire hold_data    [0:N_CHANNELS-1]; 
    wire conv_overflow;

    reg [DATA_WIDTH-1:0] data_reg [0:N_CHANNELS-1] = '{default: 0};

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
        .POOL_STRIDE(POOL_STRIDE)
    ) SPATIAL_CONV_KERNEL_0 (
        .clock_i       (system_clock),
        .reset_i       (global_reset),
        .data_valid_i  ('{default: 1'b1}),
        .kernel_valid_i('{default: 1'b1}),
        .hold_data_i   ('{default: 1'b0}),
        .data_i        (data_reg),
        .kernel_i      (conv_kernel),
        .bias_i        ({(DATA_WIDTH){1'b0}}),
        .data_o        (conv_result),
        .data_valid_o  (result_valid),
        .hold_kernel_o (hold_kernel),
        .hold_data_o   (hold_data),
        .conv_overflow (conv_overflow)
    );

    always @(posedge system_clock, posedge global_reset) begin
        if(global_reset) begin
            for(curr_channel = 0; curr_channel < N_CHANNELS; curr_channel = curr_channel+1) begin
                ram_rdaddress[curr_channel] <= curr_channel*N_ROWS*N_COLS;
            end
            curr_channel <= 0;
            data_reg     <= '{default: 0};

            debug_led[3:0] <= 0;
        end else begin
            debug_led[0] <= 1;
            if(pll_locked) begin
                if(hold_data[curr_channel]) begin
                    debug_led[1] <= 1;
                    curr_channel = curr_channel + 1;
                    if(curr_channel == N_CHANNELS) begin
                        debug_led[2] <= 1;
                        curr_channel = 0;
                    end
                end else begin
                    debug_led[3] <= 1;
                    ram_rdaddress[curr_channel] <= ram_rdaddress[curr_channel] + 1;
                    data_reg[curr_channel] <= ram_data_out;
                end
            end
        end
    end

/**** Debug signals ****/
    wire global_reset = ~KEY[3];

    wire debug_clock;
    wire fdiv_clock;
    // assign system_clock = ~KEY[0];
    // assign system_clock = debug_clock;
    // assign system_clock = CLOCK_50;
    
    assign system_clock = SW[0] ? ~KEY[0] : debug_clock;

    reg [9:0] debug_led = 0;

    assign debug_led[9] = system_clock;
    assign debug_led[8] = conv_overflow;
    // assign debug_led[7] = conv_valid;
    // assign debug_led[6] = pool_valid;

    assign LEDR = debug_led;

    wire [1:0] debug_channel = SW[5:4];
    wire [2:0] kernel_index  = SW[3:1];
    

    reg [15:0] debug_hex_display;
    always @(*) begin
        case(SW[9:6])
            0:  debug_hex_display <= curr_channel;
            1:  debug_hex_display <= ram_rdaddress[debug_channel];
            2:  debug_hex_display <= ram_wraddress;
            5:  debug_hex_display <= hold_data[debug_channel];
            7:  debug_hex_display <= result_valid[debug_channel];
            15: debug_hex_display <= conv_result[0][31:16];
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
