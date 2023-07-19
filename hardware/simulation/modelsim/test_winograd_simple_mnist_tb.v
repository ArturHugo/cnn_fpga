// verilog_lint: waive-start explicit-parameter-storage-type
`timescale 1 ps / 1 ps
module test_winograd_simple_mnist_tb ();

  // verilog_lint: waive-start parameter-name-style
  localparam ADDR_WIDTH = 16;
  localparam DATA_WIDTH = 32;
  localparam FRAC_WIDTH = 16;
  localparam N_ROWS = 28;
  localparam N_COLS = 28;
  localparam N_CHANNELS_0 = 3;
  localparam N_KERNELS_0 = 32;
  localparam N_CHANNELS_1 = 32;
  localparam N_KERNELS_1 = 64;
  localparam KERNEL_SIZE = 4;
  localparam CONV_STRIDE = 2;
  localparam POOL_SIZE = 2;
  localparam POOL_STRIDE = 2;

  // Multiplying by 2 because winograd calculates 2x2 outputs per kernel position
  localparam OUTPUT_N_ROWS_0 = ((N_ROWS - KERNEL_SIZE)/CONV_STRIDE + 1)*2 / POOL_SIZE;
  localparam OUTPUT_N_COLS_0 = ((N_COLS - KERNEL_SIZE)/CONV_STRIDE + 1)*2 / POOL_SIZE;
  localparam OUTPUT_N_ROWS_1 = ((OUTPUT_N_ROWS_0 - KERNEL_SIZE)/CONV_STRIDE + 1)*2 / POOL_SIZE;
  localparam OUTPUT_N_COLS_1 = ((OUTPUT_N_COLS_0 - KERNEL_SIZE)/CONV_STRIDE + 1)*2 / POOL_SIZE;
  localparam OUTPUT_SIZE = (OUTPUT_N_ROWS_1) * (OUTPUT_N_COLS_1);

  localparam BUFFER_SIZE_0 = (KERNEL_SIZE - 1) * N_COLS + KERNEL_SIZE;
  localparam BUFFER_SIZE_1 = (KERNEL_SIZE - 1) * OUTPUT_N_COLS_0 + KERNEL_SIZE;


  localparam RKW0_BASE_ADDR = 0;
  localparam RKW1_BASE_ADDR = 0;

  localparam FC_ADDR_WIDTH = 16;
  localparam FC_BASE_ADDR = 0;
  localparam N_NEURONS = 10;

  localparam STATE_WIDTH = 4;
  localparam [STATE_WIDTH-1:0]  // States
  WAIT_CHANNEL_SWITCH_S = 0, DATA_VALID_S = 1, WAIT_NOT_HOLD_S = 2;
  // verilog_lint: waive-stop parameter-name-style

  reg [STATE_WIDTH-1:0] curr_state = 0;

  reg waiting_first_data[N_CHANNELS_0] = '{default: 0};

  reg data_valid_0[N_CHANNELS_0] = '{default: 0};
  reg data_valid_1[N_CHANNELS_1] = '{default: 0};

  reg ramo_wren[N_KERNELS_1] = '{default: 0};
  wire [DATA_WIDTH-1:0] ramo_data_in, rami_data_out;
  reg [ADDR_WIDTH-1:0] rami_rdaddress[N_CHANNELS_0] = '{0, N_ROWS * N_COLS, 2 * N_ROWS * N_COLS};
  // reg [ADDR_WIDTH-1:0] rami_rdaddress[N_CHANNELS_0] = '{0};
  // reg [ADDR_WIDTH-1:0] ramo_wraddress[N_KERNELS_1] = '{0, OUTPUT_SIZE, 2 * OUTPUT_SIZE};

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

  // ram_output_image RAMO (
  //     .address(ramo_wraddress[curr_kernel]),
  //     .clock  (clock_driver),
  //     .data   (ramo_data_in),
  //     .wren   (ramo_wren[curr_kernel]),
  //     .q      ()
  // );

  assign ramo_data_in = conv_result_1[curr_kernel];

  // genvar kernel;
  // generate
  //   for (kernel = 0; kernel < N_KERNELS_1; kernel = kernel + 1) begin : g_kernel_loop
  //     assign ramo_wren[kernel] =
  //               result_valid_1[kernel] &&
  //               (ramo_wraddress[kernel] < (kernel+1)*OUTPUT_SIZE);

  //     always @(posedge system_clock, posedge global_reset) begin
  //       if (global_reset) begin
  //         ramo_wraddress[kernel] <= kernel * OUTPUT_SIZE;
  //       end else if (ramo_wren[kernel]) begin
  //         ramo_wraddress[kernel] <= ramo_wraddress[kernel] + 1;
  //       end
  //     end
  //   end
  // endgenerate

  winograd_4x4_conv_core #(
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
  ) WINOGRAD_4x4_CONV_CORE_0 (
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
      .clock  (clock_driver),
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

  winograd_4x4_conv_core #(
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
  ) WINOGRAD_4x4_CONV_CORE_1 (
      .clock_i       (system_clock),
      .reset_i       (global_reset),
      .data_valid_i  (result_valid_0),
      .kernel_valid_i(kernel_valid_1),
      .hold_data_i   ('{default: hold_data_fc}),
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
      .clock  (clock_driver),
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

  fully_connected #(
      .ADDR_WIDTH(FC_ADDR_WIDTH),
      .BASE_ADDR (FC_BASE_ADDR),
      .DATA_WIDTH(DATA_WIDTH),
      .FRAC_WIDTH(FRAC_WIDTH),
      .N_NEURONS (N_NEURONS)
  ) FULLY_CONNECTED_0 (
      .clock_i        (system_clock),
      .reset_i        (global_reset),
      .enable_i       (fully_connected_enable),
      .data_valid_i   (result_valid_1.or()),
      .data_i         (conv_result_1[curr_kernel]),
      .ram_weight_i   (rfc0_data_out),
      .biases_i       (biases),
      .overflow_o     (fc_overflow),
      .hold_data_o    (hold_data_fc),
      .ram_rdaddress_o(rfc0_rdaddress),
      .logits_o       (logits)
  );

  rom_fully_connected_0 RFC0 (
      .address(rfc0_rdaddress),
      .clock  (clock_driver),
      .q      (rfc0_data_out)
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
      fully_connected_enable   <= 0;
      output_values_to_process <= OUTPUT_SIZE * N_KERNELS_1;
    end else begin
      kernel_buffer_enable   <= 1;
      fully_connected_enable <= 1;

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
      end else begin
        fully_connected_enable <= 0;
      end
      /***********************************/
    end
  end

  /**** Testbench ****/
  // CLock signals

  integer total_cycles;
  always @(posedge clock_driver, posedge global_reset) begin
    if (global_reset) begin
      system_clock <= 0;
      total_cycles <= 0;
    end else begin
      system_clock <= !system_clock;
      total_cycles <= total_cycles + 1;
    end
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

    #10 clock_driver = 1;
    #10 clock_driver = 0;
    #10 clock_driver = 1;
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

    for (i = 0; i < 5000000; i = i + 1) begin
      #10 clock_driver <= !clock_driver;
    end
  end

  /*******************/
endmodule

