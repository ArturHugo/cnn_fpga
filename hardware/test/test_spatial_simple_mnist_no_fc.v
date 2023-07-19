// verilog_lint: waive-start explicit-parameter-storage-type
`timescale 1 ps / 1 ps
module test_spatial_simple_mnist_no_fc (
    input wire CLOCK_50,
    input wire [9:0] SW,
    input wire [3:0] KEY,
    output wire [9:0] LEDR,
    output wire [6:0] HEX0,
    HEX1,
    HEX2,
    HEX3,
    HEX4,
    HEX5

    // ,output wire [DATA_WIDTH-1:0] conv_result_o[N_KERNELS_1]
);

  // verilog_lint: waive-start parameter-name-style
  localparam ADDR_WIDTH = 16;
  localparam DATA_WIDTH = 32;
  localparam FRAC_WIDTH = 16;
  localparam N_ROWS = 28;  // Imagem original: 214. Imagem redimensionada: 100
  localparam N_COLS = 28;  // Imagem original: 320. Imagem redimensionada: 100
  localparam N_CHANNELS_0 = 3;
  localparam N_KERNELS_0 = 32;
  localparam N_CHANNELS_1 = 32;
  localparam N_KERNELS_1 = 64;
  localparam KERNEL_SIZE = 3;
  localparam CONV_STRIDE = 1;
  localparam POOL_SIZE = 2;
  localparam POOL_STRIDE = 2;

  localparam OUTPUT_N_ROWS_0 = (N_ROWS - KERNEL_SIZE + 1) / POOL_SIZE;
  localparam OUTPUT_N_COLS_0 = (N_COLS - KERNEL_SIZE + 1) / POOL_SIZE;
  localparam OUTPUT_N_ROWS_1 = (OUTPUT_N_ROWS_0 - KERNEL_SIZE + 1) / POOL_SIZE;
  localparam OUTPUT_N_COLS_1 = (OUTPUT_N_COLS_0 - KERNEL_SIZE + 1) / POOL_SIZE;
  localparam OUTPUT_SIZE = (OUTPUT_N_ROWS_1) * (OUTPUT_N_COLS_1);

  localparam BUFFER_SIZE_0 = (KERNEL_SIZE - 1) * N_COLS + KERNEL_SIZE;
  localparam BUFFER_SIZE_1 = (KERNEL_SIZE - 1) * OUTPUT_N_COLS_0 + KERNEL_SIZE;

  localparam RKW0_BASE_ADDR = 0;
  localparam RKW1_BASE_ADDR = 0;

  localparam N_OUTPUTS_LAYER_1 = OUTPUT_SIZE * N_KERNELS_1;

  localparam FC_ADDR_WIDTH = 16;
  localparam FC_BASE_ADDR = 0;
  localparam N_NEURONS = 10;

  localparam HPS_STATE_WIDTH = 8;
  localparam [HPS_STATE_WIDTH-1:0]  // HPS states
  HPS_WAIT_DATA_S = 0, HPS_WRITE_DATA_S = 1, HPS_WAIT_CONV_S = 2, HPS_CONV_DONE_S = 3;

  localparam STATE_WIDTH = 4;
  localparam [STATE_WIDTH-1:0]  // States
  WAIT_CHANNEL_SWITCH_S = 0, DATA_VALID_S = 1, WAIT_NOT_HOLD_S = 2;
  // verilog_lint: waive-stop parameter-name-style

  reg [STATE_WIDTH-1:0] curr_state = 0;
  reg [HPS_STATE_WIDTH-1:0] hps_state = 0;

  reg waiting_first_data[N_CHANNELS_0] = '{default: 0};

  reg data_valid_0[N_CHANNELS_0] = '{default: 0};
  reg data_valid_1[N_CHANNELS_1] = '{default: 0};

  reg ramo_wren[N_KERNELS_1] = '{default: 0};
  reg rami_wren = 0;
  wire [DATA_WIDTH-1:0] ramo_data_in, rami_data_out;
  reg [DATA_WIDTH-1:0] rami_data_in;
  reg [ADDR_WIDTH-1:0] rami_wraddress = 0;
  reg [ADDR_WIDTH-1:0] rami_rdaddress[N_CHANNELS_0] = '{0, N_ROWS * N_COLS, 2 * N_ROWS * N_COLS};
  reg [ADDR_WIDTH-1:0] ramo_wraddress[N_KERNELS_1];

  reg [$clog2(N_CHANNELS_0):0] curr_channel = 0;

  reg [DATA_WIDTH-1:0] conv_kernel_0[N_CHANNELS_0][KERNEL_SIZE*KERNEL_SIZE];
  reg [DATA_WIDTH-1:0] conv_kernel_1[N_CHANNELS_1][KERNEL_SIZE*KERNEL_SIZE];

  reg kernel_valid_0[N_CHANNELS_0];
  reg kernel_valid_1[N_CHANNELS_1];

  wire [DATA_WIDTH-1:0] conv_result_0[N_KERNELS_0];
  wire result_valid_0[N_KERNELS_0];
  wire hold_kernel_0[N_CHANNELS_0];
  wire hold_data_0[N_CHANNELS_0];
  wire conv_overflow_0;

  wire [DATA_WIDTH-1:0] conv_result_1[N_KERNELS_1];
  logic result_valid_1[N_KERNELS_1];
  wire hold_kernel_1[N_CHANNELS_1];
  wire hold_data_1[N_CHANNELS_1];
  wire conv_overflow_1;

  wire [DATA_WIDTH-1:0] biases[N_NEURONS];

  assign biases = '{
          0: 32'h0000_0654,
          1: 32'h0000_2bd9,
          2: 32'hffff_faa6,
          3: 32'hffff_efba,
          4: 32'hffff_edcb,
          5: 32'hffff_f75a,
          6: 32'hffff_f8f2,
          7: 32'h0000_08c6,
          8: 32'h0000_00f7,
          9: 32'h0000_01da
      };

  wire fc_overflow;

  wire signed [DATA_WIDTH-1:0] logits[N_NEURONS];
  wire hold_data_fc;

  reg [DATA_WIDTH-1:0] data_reg[N_CHANNELS_0] = '{default: 32'habababab};

  wire [DATA_WIDTH-1:0] rkw0_data_out;
  reg [ADDR_WIDTH-1:0] rkw0_rdaddress;

  wire [DATA_WIDTH-1:0] bias_conv_0;

  wire [DATA_WIDTH-1:0] rkw1_data_out;
  reg [ADDR_WIDTH-1:0] rkw1_rdaddress;

  wire [DATA_WIDTH-1:0] bias_conv_1;

  wire [DATA_WIDTH-1:0] rfc0_data_out;
  reg [ADDR_WIDTH-1:0] rfc0_rdaddress;

  reg kernel_buffer_enable = 0;
  reg fully_connected_enable = 0;

  reg [$clog2(N_KERNELS_0):0] curr_kernel = 0;

  reg [$clog2(OUTPUT_SIZE * N_KERNELS_1):0] output_values_to_process = OUTPUT_SIZE * N_KERNELS_1;

  reg ramo_logit_wren = 0;
  reg [DATA_WIDTH-1:0] logit_reg = 32'habababab;
  reg [ADDR_WIDTH-1:0] ramo_logit_wraddress = 0;

  reg [DATA_WIDTH-1:0] total_cycles = 0;
  reg write_total_cycles = 1;

  reg signed [$clog2(10):0] logit_i = -1;

  wire system_clock;

  reg clock_driver = 0;

  wire global_reset = ~KEY[0];

  wire pll_clock, pll_locked;

  // assign conv_result_o = conv_result_1;

  pll PLL_0 (
      .refclk  (CLOCK_50),      // refclk.clk
      .rst     (1'b0),          // reset.reset
      .outclk_0(pll_clock),     // outclk0.clk
      .outclk_1(system_clock),
      .locked  (pll_locked)     // locked.export
  );


  ram_input_image RAMI (
      .address(rami_rdaddress[curr_channel]),
      .clock  (pll_clock),
      .data   (),
      .wren   (0),
      .q      (rami_data_out)
  );

  wire [ADDR_WIDTH-1:0] ramo_wraddress_final;
  wire ramo_wren_final;
  ram_output_image RAMO (
      .address(ramo_wraddress_final),
      .clock  (pll_clock),
      .data   (ramo_data_in),
      .wren   (ramo_wren_final),
      .q      ()
  );

  assign ramo_data_in = (output_values_to_process == 0) ?
                          total_cycles :
                          conv_result_1[curr_kernel];

  assign ramo_wraddress_final = (output_values_to_process == 0) ?
                                  0 :
                                  ramo_wraddress[curr_kernel];

  assign ramo_wren_final = (output_values_to_process == 0) ?
                              1 :
                              ramo_wren[curr_kernel];

  genvar kernel;
  generate
    for (kernel = 0; kernel < N_KERNELS_1; kernel = kernel + 1) begin : g_kernel_loop
      assign ramo_wren[kernel] =
                result_valid_1[kernel] &&
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

  always @(posedge system_clock, posedge global_reset) begin
    if (global_reset) begin
      total_cycles <= 0;
    end else begin
      if (output_values_to_process != 0) begin
        total_cycles = total_cycles + 1;
      end
    end
  end

  spatial_conv_core #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .FRAC_WIDTH(FRAC_WIDTH),

      .N_ROWS    (N_ROWS),
      .N_COLS    (N_COLS),
      .N_CHANNELS(N_CHANNELS_0),
      .N_KERNELS (N_KERNELS_0),

      .KERNEL_SIZE(KERNEL_SIZE),
      .CONV_STRIDE(CONV_STRIDE),

      .POOL_SIZE  (POOL_SIZE),
      .POOL_STRIDE(POOL_STRIDE)
  ) SPATIAL_CONV_CORE_0 (
      .clock_i       (system_clock),
      .reset_i       (global_reset),
      .data_valid_i  (data_valid_0),
      .kernel_valid_i(kernel_valid_0),
      .hold_data_i   (hold_data_1),
      .data_i        (data_reg),
      .kernel_i      (conv_kernel_0),
      .bias_i        (bias_conv_0),
      .data_o        (conv_result_0),
      .data_valid_o  (result_valid_0),
      .hold_kernel_o (hold_kernel_0),
      .hold_data_o   (hold_data_0),
      .conv_overflow (conv_overflow_0)
  );

  rom_kernel_weights_0 RKW0 (
      .address(rkw0_rdaddress),
      .clock  (pll_clock),
      .q      (rkw0_data_out)
  );

  kernel_buffer #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),

      .N_CHANNELS (N_CHANNELS_0),
      .N_KERNELS  (N_KERNELS_0),
      .KERNEL_SIZE(KERNEL_SIZE),

      .KERNEL_BASE_ADDR(RKW0_BASE_ADDR)
  ) KERNEL_BUFFER_0 (
      .clock_i           (system_clock),
      .reset_i           (global_reset),
      .enable_i          (kernel_buffer_enable),
      .hold_kernel_i     (hold_kernel_0),
      .data_i            (rkw0_data_out),
      .bias_o            (bias_conv_0),
      .kernel_rdaddress_o(rkw0_rdaddress),
      .kernel_o          (conv_kernel_0),
      .kernel_valid_o    (kernel_valid_0)
  );

  spatial_conv_core #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .FRAC_WIDTH(FRAC_WIDTH),

      .N_ROWS    (OUTPUT_N_ROWS_0),
      .N_COLS    (OUTPUT_N_COLS_0),
      .N_CHANNELS(N_CHANNELS_1),
      .N_KERNELS (N_KERNELS_1),

      .KERNEL_SIZE(KERNEL_SIZE),
      .CONV_STRIDE(CONV_STRIDE),

      .POOL_SIZE  (POOL_SIZE),
      .POOL_STRIDE(POOL_STRIDE)
  ) SPATIAL_CONV_CORE_1 (
      .clock_i       (system_clock),
      .reset_i       (global_reset),
      .data_valid_i  (result_valid_0),
      .kernel_valid_i(kernel_valid_1),
      .hold_data_i   ('{default: 1'b0}),
      .data_i        (conv_result_0),
      .kernel_i      (conv_kernel_1),
      .bias_i        (bias_conv_1),
      .data_o        (conv_result_1),
      .data_valid_o  (result_valid_1),
      .hold_kernel_o (hold_kernel_1),
      .hold_data_o   (hold_data_1),
      .conv_overflow (conv_overflow_1)
  );

  rom_kernel_weights_1 RKW1 (
      .address(rkw1_rdaddress),
      .clock  (pll_clock),
      .q      (rkw1_data_out)
  );

  kernel_buffer #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),

      .N_CHANNELS (N_CHANNELS_1),
      .N_KERNELS  (N_KERNELS_1),
      .KERNEL_SIZE(KERNEL_SIZE),

      .KERNEL_BASE_ADDR(RKW1_BASE_ADDR)
  ) KERNEL_BUFFER_1 (
      .clock_i           (system_clock),
      .reset_i           (global_reset),
      .enable_i          (kernel_buffer_enable),
      .hold_kernel_i     (hold_kernel_1),
      .data_i            (rkw1_data_out),
      .bias_o            (bias_conv_1),
      .kernel_rdaddress_o(rkw1_rdaddress),
      .kernel_o          (conv_kernel_1),
      .kernel_valid_o    (kernel_valid_1)
  );

  always @(posedge system_clock, posedge global_reset) begin
    if (global_reset) begin
      for (curr_channel = 0; curr_channel < N_CHANNELS_0; curr_channel = curr_channel + 1) begin
        rami_rdaddress[curr_channel] <= curr_channel * N_ROWS * N_COLS;
      end
      curr_state               <= 0;
      curr_kernel              <= 0;
      curr_channel             <= 0;
      data_reg                 <= '{default: 32'habababab};
      data_valid_0             <= '{default: 0};
      waiting_first_data       <= '{default: 1};
      kernel_buffer_enable     <= 0;
      output_values_to_process <= OUTPUT_SIZE * N_KERNELS_1;
    end else begin
      if (pll_locked) begin
        kernel_buffer_enable <= 1;

        /**** Channel sequencing control ****/
        case (curr_state)
          WAIT_CHANNEL_SWITCH_S: begin
            data_valid_0[curr_channel] <= 1;
            if (waiting_first_data[curr_channel]) begin
              rami_rdaddress[curr_channel] <= rami_rdaddress[curr_channel] + 1;
              data_reg[curr_channel] <= rami_data_out;
              waiting_first_data[curr_channel] <= 0;
            end
            curr_state <= DATA_VALID_S;
          end

          DATA_VALID_S: begin
            if (hold_data_0[curr_channel]) begin
              data_valid_0[curr_channel] <= 0;
              curr_channel = curr_channel + 1;
              if (curr_channel == N_CHANNELS_0) begin
                curr_channel = 0;
              end
              curr_state <= WAIT_NOT_HOLD_S;
            end else begin
              rami_rdaddress[curr_channel] <= rami_rdaddress[curr_channel] + 1;
              data_reg[curr_channel] <= rami_data_out;
            end
          end

          WAIT_NOT_HOLD_S: begin
            if (!hold_data_0[curr_channel]) begin
              curr_state <= WAIT_CHANNEL_SWITCH_S;
            end
          end

          default: curr_state <= WAIT_CHANNEL_SWITCH_S;
        endcase
        /************************************/

        /**** Kernel sequencing control ****/
        if (output_values_to_process) begin
          if (result_valid_1[curr_kernel]) begin
            output_values_to_process = output_values_to_process - 1;
            curr_kernel = curr_kernel + 1;
            if (curr_kernel == N_KERNELS_1) begin
              curr_kernel = 0;
            end
          end
        end
        /***********************************/
      end
    end
  end
endmodule

