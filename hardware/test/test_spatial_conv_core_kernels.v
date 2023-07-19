module test_spatial_conv_core_kernels (
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
);

  localparam ADDR_WIDTH = 16;
  localparam DATA_WIDTH = 32;
  localparam FRAC_WIDTH = 16;
  localparam N_ROWS = 100;  // Imagem original: 214. Imagem redimensionada: 100
  localparam N_COLS = 100;  // Imagem original: 320. Imagem redimensionada: 100
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

  wire system_clock;

  wire pll_clock;

  /**** Debug signals ****/
  wire global_reset = ~KEY[3];

  wire debug_clock;

  assign system_clock = SW[0] ? ~KEY[0] : debug_clock;

  reg [9:0] debug_led = 0;

  // assign debug_led[9] = system_clock;
  // assign debug_led[8] = conv_overflow;
  // assign debug_led[7] = conv_valid;
  // assign debug_led[6] = pool_valid;

  assign LEDR = debug_led;

  wire [ 1:0] debug_channel = SW[5:4];
  wire [ 2:0] kernel_index = SW[3:1];

  reg  [15:0] debug_hex_display;
  always @(*) begin
    case (SW[9:6])
      0:  debug_hex_display <= curr_channel;
      1:  debug_hex_display <= rami_rdaddress[debug_channel];
      2:  debug_hex_display <= ramo_wraddress[debug_channel];
      5:  debug_hex_display <= hold_kernel[debug_channel];
      7:  debug_hex_display <= kernel_valid[debug_channel];
      8:  debug_hex_display <= conv_kernel[debug_channel][kernel_index][31:16];
      12: debug_hex_display <= hold_data[debug_channel];
      15: debug_hex_display <= conv_result[debug_channel][31:16];

      default: debug_hex_display <= 16'habab;
    endcase
  end

  decoder7 D4 (
      .In (curr_state),
      .Out(HEX4)
  );
  decoder7 D3 (
      .In (debug_hex_display[15:12]),
      .Out(HEX3)
  );
  decoder7 D2 (
      .In (debug_hex_display[11:8]),
      .Out(HEX2)
  );
  decoder7 D1 (
      .In (debug_hex_display[7:4]),
      .Out(HEX1)
  );
  decoder7 D0 (
      .In (debug_hex_display[3:0]),
      .Out(HEX0)
  );
  /***************************/

  pll PLL_0 (
      .refclk  (CLOCK_50),     // refclk.clk
      .rst     (1'b0),         // reset.reset
      .outclk_0(pll_clock),    // outclk0.clk
      .outclk_1(debug_clock),
      .locked  (pll_locked)    // locked.export
  );

  ram_input_image RAMI (
      .address(rami_rdaddress[curr_channel]),
      .clock  (pll_clock),
      .data   (),
      .wren   (1'b0),
      .q      (rami_data_out)
  );

  ram_output_image RAMO (
      .address(ramo_wraddress[curr_kernel]),
      .clock  (pll_clock),
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
  ) SPATIAL_CONV_KERNEL_0 (
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
      .clock  (pll_clock),
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
endmodule
