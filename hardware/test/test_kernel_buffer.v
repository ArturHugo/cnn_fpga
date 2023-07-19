module test_kernel_buffer (
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
  localparam N_CHANNELS = 3;
  localparam N_KERNELS = 3;
  localparam KERNEL_SIZE = 3;
  localparam BASE_ADDR = 0;

  wire pll_clock, pll_locked;

  pll PLL_0 (
      .refclk  (CLOCK_50),     // refclk.clk
      .rst     (1'b0),         // reset.reset
      .outclk_0(pll_clock),    // outclk0.clk
      .outclk_1(debug_clock),
      .locked  (pll_locked)    // locked.export
  );

  wire [DATA_WIDTH-1:0] ram_data_out;
  reg  [ADDR_WIDTH-1:0] ram_rdaddress;


  ram_kernel_weights_0 RKW0 (
      .address(ram_rdaddress),
      .clock  (pll_clock),
      .data   (),
      .wren   (1'b0),
      .q      (ram_data_out)
  );

  kernel_buffer #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),

      .N_CHANNELS (N_CHANNELS),
      .N_KERNELS  (N_KERNELS),
      .KERNEL_SIZE(KERNEL_SIZE),

      .KERNEL_BASE_ADDR(BASE_ADDR)
  ) KERNEL_BUFFER_0 (
      .clock_i           (system_clock),
      .reset_i           (global_reset),
      .enable_i          (kernel_buffer_enable),
      .hold_kernel_i     (hold_kernel),
      .data_i            (ram_data_out),
      .kernel_rdaddress_o(ram_rdaddress),
      .kernel_o          (conv_kernel),
      .kernel_valid_o    (kernel_valid)
  );

  reg kernel_buffer_enable = 0;

  reg [$clog2(N_CHANNELS):0] curr_channel = 0;

  reg [DATA_WIDTH-1:0] conv_kernel[0:N_CHANNELS-1][0:KERNEL_SIZE*KERNEL_SIZE-1];

  reg kernel_valid[0:N_CHANNELS-1];
  reg hold_kernel[0:N_CHANNELS-1];

  always @(posedge system_clock, posedge global_reset) begin
    if (global_reset) begin
      kernel_buffer_enable <= 0;
      hold_kernel <= '{default: 0};
      curr_channel <= 0;

      debug_led[3:0] <= 0;
    end else begin
      debug_led[0] <= 1;
      if (pll_locked) begin
        kernel_buffer_enable <= 1;

        if (kernel_valid[curr_channel] == 1) begin
          hold_kernel[curr_channel] <= 1;
          curr_channel <= curr_channel + 1;
        end

        if (~KEY[2]) begin
          hold_kernel[debug_channel] <= 0;
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

  assign system_clock = ~KEY[0];

  // fdiv FDIV_0 (
  //     .clkin(CLOCK_50),
  //     .div(SW[3:2]),
  //     .reset(~KEY[3]),
  //     .clkout(fdiv_clock)
  // );

  reg [9:0] debug_led = 0;

  assign debug_led[9] = system_clock;

  assign LEDR = debug_led;

  wire [ 1:0] debug_channel = SW[5:4];
  wire [ 3:0] kernel_index = SW[3:0];

  reg  [15:0] debug_hex_display;
  always @(*) begin
    case (SW[9:6])
      0: debug_hex_display <= curr_channel;
      1: debug_hex_display <= kernel_index;
      2: debug_hex_display <= ram_data_out[31:16];
      3: debug_hex_display <= ram_rdaddress;
      4: debug_hex_display <= hold_kernel[debug_channel];
      5: debug_hex_display <= kernel_valid[debug_channel];
      6: debug_hex_display <= conv_kernel[debug_channel][kernel_index][31:16];
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
endmodule
