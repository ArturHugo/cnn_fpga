// verilog_lint: waive-start explicit-parameter-storage-type
`timescale 1 ps / 1 ps
module test_kernel_buffer_bias_tb ();

  // verilog_lint: waive-start parameter-name-style
  localparam ADDR_WIDTH = 16;
  localparam DATA_WIDTH = 32;
  localparam FRAC_WIDTH = 16;
  localparam N_ROWS = 28;  // Imagem original: 214. Imagem redimensionada: 100
  localparam N_COLS = 28;  // Imagem original: 320. Imagem redimensionada: 100
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

  localparam FC_ADDR_WIDTH = 16;
  localparam FC_BASE_ADDR = 0;
  localparam N_NEURONS = 10;

  localparam STATE_WIDTH = 4;
  localparam [STATE_WIDTH-1:0]  // States
  WAIT_CHANNEL_SWITCH_S = 0, DATA_VALID_S = 1, WAIT_NOT_HOLD_S = 2;
  // verilog_lint: waive-stop parameter-name-style

  reg [$clog2(N_CHANNELS_0):0] curr_channel = 0;

  reg [DATA_WIDTH-1:0] conv_kernel_0[N_CHANNELS_0][KERNEL_SIZE*KERNEL_SIZE];

  reg kernel_valid_0[N_CHANNELS_0];
  reg hold_kernel_0[N_CHANNELS_0];

  wire [DATA_WIDTH-1:0] rkw0_data_out;
  reg [ADDR_WIDTH-1:0] rkw0_rdaddress;

  wire [DATA_WIDTH-1:0] bias_conv_0;

  reg kernel_buffer_enable = 0;

  reg system_clock = 0;

  reg clock_driver = 0;

  reg global_reset = 0;

  reg release_kernel = 0;

  ram_kernel_weights_0 RKW0 (
      .address(rkw0_rdaddress),
      .clock  (clock_driver),
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
      .bias_o            (bias_conv_0),
      .kernel_rdaddress_o(rkw0_rdaddress),
      .kernel_o          (conv_kernel_0),
      .kernel_valid_o    (kernel_valid_0)
  );

  always @(posedge system_clock, posedge global_reset) begin
    if (global_reset) begin
      kernel_buffer_enable <= 0;
      hold_kernel_0 <= '{default: 0};
      curr_channel <= 0;

    end else begin
      kernel_buffer_enable <= 1;

      if (release_kernel) begin
        release_kernel = 0;
        hold_kernel_0  = '{default: 0};
      end

      if (kernel_valid_0[curr_channel] == 1) begin
        hold_kernel_0[curr_channel] = 1;
        curr_channel = curr_channel + 1;
        if (curr_channel == N_CHANNELS_0) begin
          curr_channel   = 0;
          release_kernel = 1;
        end
      end
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

    for (i = 0; i < 500; i = i + 1) begin
      #10 clock_driver <= !clock_driver;
    end
  end

  /*******************/
endmodule

