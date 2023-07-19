// Copyright (C) 2021  Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions 
// and other software and tools, and any partner logic 
// functions, and any output files from any of the foregoing 
// (including device programming or simulation files), and any 
// associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License 
// Subscription Agreement, the Intel Quartus Prime License Agreement,
// the Intel FPGA IP License Agreement, or other applicable license
// agreement, including, without limitation, that your use is for
// the sole purpose of programming logic devices manufactured by
// Intel and sold by Intel or its authorized distributors.  Please
// refer to the applicable agreement for further details, at
// https://fpgasoftware.intel.com/eula.

// *****************************************************************************
// This file contains a Verilog test bench template that is freely editable to  
// suit user's needs .Comments are provided in each section to help the user    
// fill out necessary details.                                                  
// *****************************************************************************
// Generated on "02/15/2023 19:08:10"
                                                                                
// Verilog Test Bench template for design : test_winograd_conv_with_pooling
// 
// Simulation tool : Questa Intel FPGA (Verilog)
// 

`timescale 1 ps/ 1 ps
module test_winograd_conv_with_pooling_tb();

    localparam ADDR_WIDTH  = 16;
    localparam DATA_WIDTH  = 32;
    localparam FRAC_WIDTH  = 16;
    localparam N_ROWS      = 108; // Imagem original: 214. Imagem redimensionada: 108
    localparam N_COLS      = 160; // Imagem original: 320. Imagem redimensionada: 160
    localparam KERNEL_SIZE = 4;
    localparam RESULT_SIZE = KERNEL_SIZE - 2;
    localparam STEP_SIZE   = 2;
    localparam BUFFER_SIZE = (KERNEL_SIZE-1)*N_COLS + KERNEL_SIZE;

    wire [DATA_WIDTH-1:0] ram_data_in, ram_data_out;
    reg  [ADDR_WIDTH-1:0] ram_rdaddress = 0;
    reg  [ADDR_WIDTH-1:0] ram_wraddress = 0;
    wire ram_wren;

    reg result_valid = 0;

	wire ram_clock;

    assign ram_wren = result_valid;

    ram_input_image RAMI (
        .address (ram_rdaddress),
        .clock   (ram_clock),
        .data    (),
        .wren    (1'b0),
        .q       (ram_data_out)
    );

    ram_output_image RAMO (
        .address (ram_wraddress),
        .clock   (ram_clock),
        .data    (ram_data_in),
        .wren    (ram_wren),
        .q       ()
    );

    reg system_clock = 0;

    wire [DATA_WIDTH-1:0] buffered_window [0:KERNEL_SIZE*KERNEL_SIZE-1];

    window_buffer #(
        .DATA_WIDTH  (DATA_WIDTH),
        .LINE_LENGTH (N_COLS),
        .WINDOW_SIZE (KERNEL_SIZE)
    ) WINDOW_BUFFER_0 (
        .clk_i    (system_clock),
        .data_i   (ram_data_out),
        .enable_i (1'b1),
        .window_o (buffered_window)
    );

    /*
        [-1.  -1.5 -0.5 -1. ]
        [ 0.   0.   0.   0. ]
        [-2.  -3.  -1.  -2. ]
        [-1.  -1.5 -0.5 -1. ]
    */
    reg signed [DATA_WIDTH-1:0] conv_kernel [0:KERNEL_SIZE*KERNEL_SIZE-1] = '{
        32'hffff0000, 32'hfffe8000, 32'hffff8000, 32'hffff0000,
        32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
        32'hfffe0000, 32'hfffd0000, 32'hffff0000, 32'hfffe0000,
        32'hffff0000, 32'hfffe8000, 32'hffff8000, 32'hffff0000
    };
    wire [DATA_WIDTH-1:0] conv_result [0:RESULT_SIZE*RESULT_SIZE-1];
    wire conv_overflow; 

    winograd_4x4_conv_kernel #(
        .DATA_WIDTH (DATA_WIDTH),
        .FRAC_WIDTH (FRAC_WIDTH)
    ) WINOGRAD_4x4_CONV_KERNEL_0 (
        .window   (buffered_window),
        .kernel   (conv_kernel),
        .result   (conv_result),
        .overflow (conv_overflow)
    );

    wire [DATA_WIDTH-1:0] pool_result;

    max_pool_2x2 #(
        .DATA_WIDTH (DATA_WIDTH)
    ) POOL_2x2_0 (
        .data_i   (conv_result),
        .result_o (pool_result)
    );

    assign ram_data_in = pool_result;

    reg [$clog2(N_COLS-2):0] output_cols_left = N_COLS - 2;
    reg [$clog2(N_ROWS-2):0] output_rows_left = N_ROWS - 3;

    reg [$clog2(STEP_SIZE):0] steps_to_next_window = 0;

    reg [$clog2(N_COLS+KERNEL_SIZE-1):0] cycles_to_align = 0;
    reg [$clog2(BUFFER_SIZE):0] cycles_to_first_window = BUFFER_SIZE;

    localparam [4:0]  // States
    WAIT_PLL_LOCKED_S   = 0,
    WAIT_FIRST_WINDOW_S = 1,
    VALID_CONV_S        = 2,
    WAIT_STEP_SIZE_S    = 3,
    WAIT_ALIGNMENT_S    = 4,
    CONVOLUTION_DONE_S  = 5;

    reg [4:0] curr_state = 0;

    /**** Convolution control ****/
    always @(posedge system_clock) begin
        case(curr_state)
            WAIT_PLL_LOCKED_S: begin
                if(1'b1) begin
                    curr_state <= WAIT_FIRST_WINDOW_S;
                end else begin
                    curr_state <= WAIT_PLL_LOCKED_S;
                end
            end

            WAIT_FIRST_WINDOW_S: begin
                ram_rdaddress <= ram_rdaddress + 1;
                cycles_to_first_window = cycles_to_first_window - 1;
                if(cycles_to_first_window == 0) begin
                    result_valid <= 1;
                    curr_state   <= VALID_CONV_S;
                end else begin
                    curr_state <= WAIT_FIRST_WINDOW_S;
                end
            end

            VALID_CONV_S: begin
                ram_rdaddress <= ram_rdaddress + 1;
                ram_wraddress <= ram_wraddress + 1;
                result_valid  <= 0;
                steps_to_next_window <= STEP_SIZE - 1;
                curr_state <= WAIT_STEP_SIZE_S;
            end

            WAIT_STEP_SIZE_S: begin
                ram_rdaddress <= ram_rdaddress + 1;
                steps_to_next_window = steps_to_next_window - 1;
                if(steps_to_next_window == 0) begin
                    output_cols_left = output_cols_left - 2;
                    if(output_cols_left < 2) begin
                        if(output_rows_left < 2) begin
                            curr_state <= CONVOLUTION_DONE_S;
                        end else begin
                            cycles_to_align  <= N_COLS + KERNEL_SIZE - 2;
                            output_rows_left <= output_rows_left - 2;
                            curr_state       <= WAIT_ALIGNMENT_S;
                        end
                    end else begin
                        result_valid <= 1;
                        curr_state   <= VALID_CONV_S;
                    end
                end else begin
                    curr_state <= WAIT_STEP_SIZE_S;
                end
            end

            WAIT_ALIGNMENT_S: begin
                output_cols_left <= N_COLS - 2;
                ram_rdaddress    <= ram_rdaddress + 1;
                cycles_to_align   = cycles_to_align - 1;
                if(cycles_to_align == 0) begin
                    result_valid <= 1;
                    curr_state   <= VALID_CONV_S;
                end else begin
                    curr_state <= WAIT_ALIGNMENT_S;
                end
            end

            CONVOLUTION_DONE_S: begin
                result_valid <= 0;
                curr_state   <= CONVOLUTION_DONE_S;
            end

            default: begin
                curr_state <= CONVOLUTION_DONE_S;
            end
        endcase
    end
    /**************************/

	/**** Testbench ****/
	// CLock signals
	reg clock_driver = 0;
	assign ram_clock = clock_driver;
	always @(posedge clock_driver) begin
		system_clock <= !system_clock;
	end

	initial begin
		forever
            #10 clock_driver <= !clock_driver;
	end

	/*******************/
endmodule

