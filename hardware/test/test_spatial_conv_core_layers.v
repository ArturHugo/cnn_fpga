module test_spatial_conv_core_layers (
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
  localparam N_CHANNELS_0 = 3;
  localparam N_KERNELS_0 = 3;
  localparam N_CHANNELS_1 = 3;
  localparam N_KERNELS_1 = 3;
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

  localparam STATE_WIDTH = 4;
  localparam [STATE_WIDTH-1:0]  // States
  WAIT_CHANNEL_SWITCH_S = 0, DATA_VALID_S = 1, WAIT_NOT_HOLD_S = 2;

  reg [STATE_WIDTH-1:0] curr_state = 0;

  reg waiting_first_data[0:N_CHANNELS_0-1] = '{default: 0};

  reg data_valid_0[0:N_CHANNELS_0-1] = '{default: 0};
  reg data_valid_1[0:N_CHANNELS_1-1] = '{default: 0};

  reg ramo_wren[0:N_KERNELS_1-1] = '{default: 0};
  wire [DATA_WIDTH-1:0] ramo_data_in, rami_data_out;
  reg [ADDR_WIDTH-1:0] rami_rdaddress[0:N_CHANNELS_0-1] = '{
      0
      , N_ROWS * N_COLS
      , 2 * N_ROWS * N_COLS
  };
  reg [ADDR_WIDTH-1:0] ramo_wraddress[0:N_KERNELS_1-1] = '{0, OUTPUT_SIZE, 2 * OUTPUT_SIZE};

  reg [$clog2(N_CHANNELS_0):0] curr_channel = 0;

  reg [DATA_WIDTH-1:0] conv_kernel_0[0:N_CHANNELS_0-1][0:KERNEL_SIZE*KERNEL_SIZE-1];
  reg [DATA_WIDTH-1:0] conv_kernel_1[0:N_CHANNELS_1-1][0:KERNEL_SIZE*KERNEL_SIZE-1];

  reg kernel_valid_0[0:N_CHANNELS_0-1];
  reg kernel_valid_1[0:N_CHANNELS_1-1];

  wire [DATA_WIDTH-1:0] conv_result_0[0:N_KERNELS_0-1];
  wire result_valid_0[0:N_KERNELS_0-1];
  wire hold_kernel_0[0:N_CHANNELS_0-1];
  wire hold_data_0[0:N_CHANNELS_0-1];
  wire conv_overflow_0;

  wire [DATA_WIDTH-1:0] conv_result_1[0:N_KERNELS_1-1];
  wire result_valid_1[0:N_KERNELS_1-1];
  wire hold_kernel_1[0:N_CHANNELS_1-1];
  wire hold_data_1[0:N_CHANNELS_1-1];
  wire conv_overflow_1;

  reg [DATA_WIDTH-1:0] data_reg[0:N_CHANNELS_0-1] = '{default: 32'habababab};

  wire [DATA_WIDTH-1:0] rkw0_data_out;
  reg [ADDR_WIDTH-1:0] rkw0_rdaddress;

  wire [DATA_WIDTH-1:0] rkw1_data_out;
  reg [ADDR_WIDTH-1:0] rkw1_rdaddress;

  reg kernel_buffer_enable = 0;

  reg [$clog2(N_KERNELS_0):0] curr_kernel = 0;

  wire system_clock;

  wire pll_clock, pll_locked;

  /**** Debug signals ****/
  wire global_reset = ~KEY[3];

  wire debug_clock;
  wire fdiv_clock;

  fdiv FDIV_0 (
      .clkin(CLOCK_50),
      .div(SW[3:2]),
      .reset(~KEY[3]),
      .clkout(fdiv_clock)
  );

  assign system_clock = SW[0] ? ~KEY[0] : SW[1] ? fdiv_clock : debug_clock;

  reg [9:0] debug_led = 0;

  // assign debug_led[9] = system_clock;
  // assign debug_led[8] = conv_overflow;
  // assign debug_led[7] = conv_valid;
  // assign debug_led[6] = pool_valid;

  assign LEDR = debug_led;

  wire [ 1:0] debug_channel = SW[5:4];
  // wire [2:0] kernel_index  = SW[3:2];

  reg  [15:0] debug_hex_display;
  always @(*) begin
    case (SW[9:6])
      1: debug_hex_display <= rami_rdaddress[debug_channel];
      2: debug_hex_display <= ramo_wraddress[debug_channel];
      3: debug_hex_display <= ramo_wren[debug_channel];
      4: debug_hex_display <= curr_kernel;

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

  assign ramo_data_in = conv_result_1[curr_kernel];

  genvar kernel;
  generate
    for (kernel = 0; kernel < N_KERNELS_1; kernel = kernel + 1) begin : kernel_loop
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
      .bias_i        ({(DATA_WIDTH) {1'b0}}),
      .data_o        (conv_result_0),
      .data_valid_o  (result_valid_0),
      .hold_kernel_o (hold_kernel_0),
      .hold_data_o   (hold_data_0),
      .conv_overflow (conv_overflow_0)
  );

  ram_kernel_weights_0 RKW0 (
      .address(rkw0_rdaddress),
      .clock  (pll_clock),
      .data   (),
      .wren   (1'b0),
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
      .bias_i        ({(DATA_WIDTH) {1'b0}}),
      .data_o        (conv_result_1),
      .data_valid_o  (result_valid_1),
      .hold_kernel_o (hold_kernel_1),
      .hold_data_o   (hold_data_1),
      .conv_overflow (conv_overflow_1)
  );

  ram_kernel_weights_1 RKW1 (
      .address(rkw1_rdaddress),
      .clock  (pll_clock),
      .data   (),
      .wren   (1'b0),
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
      .kernel_rdaddress_o(rkw1_rdaddress),
      .kernel_o          (conv_kernel_1),
      .kernel_valid_o    (kernel_valid_1)
  );

  always @(posedge system_clock, posedge global_reset) begin
    if (global_reset) begin
      for (curr_channel = 0; curr_channel < N_CHANNELS_0; curr_channel = curr_channel + 1) begin
        rami_rdaddress[curr_channel] <= curr_channel * N_ROWS * N_COLS;
      end
      curr_state           <= 0;
      curr_kernel          <= 0;
      curr_channel         <= 0;
      data_reg             <= '{default: 0};
      data_valid_0         <= '{default: 0};
      waiting_first_data   <= '{default: 1};
      kernel_buffer_enable <= 0;
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
        if (result_valid_1[curr_kernel]) begin
          curr_kernel = curr_kernel + 1;
          if (curr_kernel == N_KERNELS_1) begin
            curr_kernel = 0;
          end
        end
        /***********************************/
      end
    end
  end
endmodule
