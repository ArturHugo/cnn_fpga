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

`timescale 1 ps / 1 ps
module test_spatial_conv_core_kernels_tb ();

  localparam ADDR_WIDTH = 16;
  localparam DATA_WIDTH = 32;
  localparam FRAC_WIDTH = 16;
  localparam N_ROWS = 6;  // Imagem original: 214. Imagem redimensionada: 100
  localparam N_COLS = 6;  // Imagem original: 320. Imagem redimensionada: 100
  localparam N_CHANNELS = 3;
  localparam N_KERNELS = 3;
  localparam KERNEL_SIZE = 3;
  localparam CONV_STRIDE = 1;
  localparam POOL_SIZE = 2;
  localparam POOL_STRIDE = 2;

  localparam OUTPUT_N_ROWS = N_ROWS - KERNEL_SIZE + 1;
  localparam OUTPUT_N_COLS = N_COLS - KERNEL_SIZE + 1;
  localparam OUTPUT_SIZE = (OUTPUT_N_ROWS) * (OUTPUT_N_COLS) / (POOL_SIZE * POOL_SIZE);

  localparam BUFFER_SIZE = (KERNEL_SIZE - 1) * N_COLS + KERNEL_SIZE;

  localparam RAMW_BASE_ADDR = 0;

  localparam STATE_WIDTH = 4;
  localparam [STATE_WIDTH-1:0]  // States
  WAIT_CHANNEL_SWITCH_S = 0, DATA_VALID_S = 1, WAIT_NOT_HOLD_S = 2;

  reg [STATE_WIDTH-1:0] curr_state = 0;

  reg waiting_first_data[0:N_CHANNELS-1] = '{default: 0};

  reg data_valid[0:N_CHANNELS-1] = '{default: 0};

  reg ramo_wren[0:N_KERNELS-1] = '{default: 0};
  wire [DATA_WIDTH-1:0] ramo_data_in, rami_data_out;
  reg [ADDR_WIDTH-1:0] rami_rdaddress[0:N_CHANNELS-1] = '{
      0
      , N_ROWS * N_COLS
      , 2 * N_ROWS * N_COLS
  };
  reg [ADDR_WIDTH-1:0] ramo_wraddress[0:N_KERNELS-1] = '{0, OUTPUT_SIZE, 2 * OUTPUT_SIZE};

  reg [$clog2(N_CHANNELS):0] curr_channel = 0;

  reg [DATA_WIDTH-1:0] conv_kernel[0:N_CHANNELS-1][0:KERNEL_SIZE*KERNEL_SIZE-1];

  reg kernel_valid[0:N_CHANNELS-1];

  wire [DATA_WIDTH-1:0] conv_result[0:N_KERNELS-1];
  wire result_valid[0:N_KERNELS-1];
  wire hold_kernel[0:N_CHANNELS-1];
  wire hold_data[0:N_CHANNELS-1];
  wire conv_overflow;

  reg [DATA_WIDTH-1:0] data_reg[0:N_CHANNELS-1] = '{default: 32'habababab};

  wire [DATA_WIDTH-1:0] ramw_data_out;
  reg [ADDR_WIDTH-1:0] ramw_rdaddress;

  reg kernel_buffer_enable = 0;

  reg [$clog2(N_KERNELS):0] curr_kernel = 0;

  reg system_clock = 0;

  reg clock_driver = 0;

  reg global_reset = 0;


  ram_input_image RAMI (
      .address(rami_rdaddress[curr_channel]),
      .clock  (clock_driver),
      .data   (),
      .wren   (1'b0),
      .q      (rami_data_out)
  );

  ram_output_image RAMO (
      .address(ramo_wraddress[curr_kernel]),
      .clock  (clock_driver),
      .data   (ramo_data_in),
      .wren   (ramo_wren[curr_kernel]),
      .q      ()
  );

  assign ramo_data_in = conv_result[curr_kernel];

  genvar kernel;
  generate
    for (kernel = 0; kernel < N_KERNELS; kernel = kernel + 1) begin : kernel_loop
      assign ramo_wren[kernel] =
                result_valid[kernel] &&
                (ramo_wraddress[kernel] < (kernel+1)*OUTPUT_SIZE);

      always @(posedge system_clock, posedge global_reset) begin
        if (global_reset) begin
          ramo_wraddress[kernel] <= kernel * OUTPUT_SIZE;
        end else if (ramo_wren[kernel]) begin
          ramo_wraddress[kernel] <= ramo_wraddress[kernel] + 1;
        end
      end
    end
  endgenerate

  spatial_conv_core #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .FRAC_WIDTH(FRAC_WIDTH),

      .N_ROWS    (N_ROWS),
      .N_COLS    (N_COLS),
      .N_CHANNELS(N_CHANNELS),
      .N_KERNELS (N_KERNELS),

      .KERNEL_SIZE(KERNEL_SIZE),
      .CONV_STRIDE(CONV_STRIDE),

      .POOL_SIZE  (POOL_SIZE),
      .POOL_STRIDE(POOL_STRIDE)
  ) SPATIAL_CONV_CORE_0 (
      .clock_i       (system_clock),
      .reset_i       (global_reset),
      .data_valid_i  (data_valid),
      .kernel_valid_i(kernel_valid),
      .hold_data_i   ('{default: 1'b0}),
      .data_i        (data_reg),
      .kernel_i      (conv_kernel),
      .bias_i        ({(DATA_WIDTH) {1'b0}}),
      .data_o        (conv_result),
      .data_valid_o  (result_valid),
      .hold_kernel_o (hold_kernel),
      .hold_data_o   (hold_data),
      .conv_overflow (conv_overflow)
  );

  ram_kernel_weights_0 RKW0 (
      .address(ramw_rdaddress),
      .clock  (clock_driver),
      .data   (),
      .wren   (1'b0),
      .q      (ramw_data_out)
  );

  kernel_buffer #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),

      .N_CHANNELS (N_CHANNELS),
      .N_KERNELS  (N_KERNELS),
      .KERNEL_SIZE(KERNEL_SIZE),

      .KERNEL_BASE_ADDR(RAMW_BASE_ADDR)
  ) KERNEL_BUFFER_0 (
      .clock_i           (system_clock),
      .reset_i           (global_reset),
      .enable_i          (kernel_buffer_enable),
      .hold_kernel_i     (hold_kernel),
      .data_i            (ramw_data_out),
      .kernel_rdaddress_o(ramw_rdaddress),
      .kernel_o          (conv_kernel),
      .kernel_valid_o    (kernel_valid)
  );

  always @(posedge system_clock, posedge global_reset) begin
    if (global_reset) begin
      for (curr_channel = 0; curr_channel < N_CHANNELS; curr_channel = curr_channel + 1) begin
        rami_rdaddress[curr_channel] <= curr_channel * N_ROWS * N_COLS;
      end
      curr_state         <= 0;
      curr_kernel        <= 0;
      curr_channel       <= 0;
      data_reg           <= '{default: 0};
      data_valid         <= '{default: 0};
      waiting_first_data <= '{default: 1};
    end else begin
      kernel_buffer_enable <= 1;

      /**** Channel sequencing control ****/
      case (curr_state)
        WAIT_CHANNEL_SWITCH_S: begin
          data_valid[curr_channel] <= 1;
          if (waiting_first_data[curr_channel]) begin
            rami_rdaddress[curr_channel] <= rami_rdaddress[curr_channel] + 1;
            data_reg[curr_channel] <= rami_data_out;
            waiting_first_data[curr_channel] <= 0;
          end
          curr_state <= DATA_VALID_S;
        end

        DATA_VALID_S: begin
          if (hold_data[curr_channel]) begin
            data_valid[curr_channel] <= 0;
            curr_channel = curr_channel + 1;
            if (curr_channel == N_CHANNELS) begin
              curr_channel = 0;
            end
            curr_state <= WAIT_NOT_HOLD_S;
          end else begin
            rami_rdaddress[curr_channel] <= rami_rdaddress[curr_channel] + 1;
            data_reg[curr_channel] <= rami_data_out;
          end
        end

        WAIT_NOT_HOLD_S: begin
          if (!hold_data[curr_channel]) begin
            curr_state <= WAIT_CHANNEL_SWITCH_S;
          end
        end

        default: curr_state <= WAIT_CHANNEL_SWITCH_S;
      endcase
      /************************************/

      /**** Kernel sequencing control ****/
      if (result_valid[curr_kernel]) begin
        curr_kernel = curr_kernel + 1;
        if (curr_kernel == N_KERNELS) begin
          curr_kernel = 0;
        end
      end
      /***********************************/
    end
  end

  /**** Testbench ****/
  // CLock signals
  always @(posedge clock_driver) begin
    system_clock <= !system_clock;
  end

  integer i;
  initial begin
    #10 clock_driver = 0;

    global_reset = 1;

    #10 clock_driver = 1;
    #10 clock_driver = 0;
    #10 clock_driver = 1;
    #10 clock_driver = 0;

    global_reset = 0;

    // #10 clock_driver = 1;
    // #10 clock_driver = 0;
    // #10 clock_driver = 1;
    // #10 clock_driver = 0;

    // data_valid = 1;

    for (i = 0; i < 6500; i = i + 1) begin
      #10 clock_driver <= !clock_driver;
    end
  end

  /*******************/
endmodule

