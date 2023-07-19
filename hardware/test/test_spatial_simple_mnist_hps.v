// verilog_lint: waive-start explicit-parameter-storage-type
`timescale 1 ps / 1 ps
module test_spatial_simple_mnist_hps (
    input wire CLOCK_50,
    input wire [9:0] SW,
    input wire [3:0] KEY,
    output wire [9:0] LEDR,
    output wire [6:0] HEX0,
    HEX1,
    HEX2,
    HEX3,
    HEX4,
    HEX5,

    // HPS
    inout wire HPS_CONV_USB_N,
    output wire [14:0] HPS_DDR3_ADDR,
    output wire [2:0] HPS_DDR3_BA,
    output wire HPS_DDR3_CAS_N,
    output wire HPS_DDR3_CKE,
    output wire HPS_DDR3_CK_N,
    output wire HPS_DDR3_CK_P,
    output wire HPS_DDR3_CS_N,
    output wire [3:0] HPS_DDR3_DM,
    inout wire [31:0] HPS_DDR3_DQ,
    inout [3:0] HPS_DDR3_DQS_N,
    inout [3:0] HPS_DDR3_DQS_P,
    output wire HPS_DDR3_ODT,
    output wire HPS_DDR3_RAS_N,
    output wire HPS_DDR3_RESET_N,
    input wire HPS_DDR3_RZQ,
    output wire HPS_DDR3_WE_N,
    output wire HPS_ENET_GTX_CLK,
    inout wire HPS_ENET_INT_N,
    output wire HPS_ENET_MDC,
    inout wire HPS_ENET_MDIO,
    input wire HPS_ENET_RX_CLK,
    input wire [3:0] HPS_ENET_RX_DATA,
    input wire HPS_ENET_RX_DV,
    output wire [3:0] HPS_ENET_TX_DATA,
    output wire HPS_ENET_TX_EN,
    inout wire HPS_KEY,
    output wire HPS_SD_CLK,
    inout wire HPS_SD_CMD,
    inout wire [3:0] HPS_SD_DATA,
    input wire HPS_UART_RX,
    output wire HPS_UART_TX,
    input wire HPS_USB_CLKOUT,
    inout wire [7:0] HPS_USB_DATA,
    input wire HPS_USB_DIR,
    input wire HPS_USB_NXT,
    output wire HPS_USB_STP
);

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

  localparam N_OUTPUTS_LAYER_1 = OUTPUT_SIZE*N_KERNELS_1;

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
  reg [ADDR_WIDTH-1:0] ramo_wraddress[N_KERNELS_1] = '{0, OUTPUT_SIZE, 2 * OUTPUT_SIZE};

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

  wire system_clock;

  reg clock_driver = 0;

  reg global_reset = 0;

  wire pll_clock, pll_locked;

  pll PLL_0 (
      .refclk  (CLOCK_50),      // refclk.clk
      .rst     (1'b0),          // reset.reset
      .outclk_0(pll_clock),     // outclk0.clk
      .outclk_1(system_clock),
      .locked  (pll_locked)     // locked.export
  );

  wire rami_address = rami_wren ? rami_wraddress : rami_rdaddress[curr_channel];

  ram_input_image RAMI (
      .address(rami_address),
      .clock  (pll_clock),
      .data   (rami_data_in),
      .wren   (rami_wren),
      .q      (rami_data_out)
  );

  reg [DATA_WIDTH-1:0] hps_data;
  reg hps_data_valid, hps_start_conv, hps_logits_retrieved;

  hps HPS0 (
      .clk_clk      (system_clock),  //   clk.clk
      .reset_reset_n(1'b1),          // reset.reset_n

      .memory_mem_a      (HPS_DDR3_ADDR),     // memory.mem_a
      .memory_mem_ba     (HPS_DDR3_BA),       //       .mem_ba
      .memory_mem_ck     (HPS_DDR3_CK_P),     //       .mem_ck
      .memory_mem_ck_n   (HPS_DDR3_CK_N),     //       .mem_ck_n
      .memory_mem_cke    (HPS_DDR3_CKE),      //       .mem_cke
      .memory_mem_cs_n   (HPS_DDR3_CS_N),     //       .mem_cs_n
      .memory_mem_ras_n  (HPS_DDR3_RAS_N),    //       .mem_ras_n
      .memory_mem_cas_n  (HPS_DDR3_CAS_N),    //       .mem_cas_n
      .memory_mem_we_n   (HPS_DDR3_WE_N),     //       .mem_we_n
      .memory_mem_reset_n(HPS_DDR3_RESET_N),  //       .mem_reset_n
      .memory_mem_dq     (HPS_DDR3_DQ),       //       .mem_dq
      .memory_mem_dqs    (HPS_DDR3_DQS_P),    //       .mem_dqs
      .memory_mem_dqs_n  (HPS_DDR3_DQS_N),    //       .mem_dqs_n
      .memory_mem_odt    (HPS_DDR3_ODT),      //       .mem_odt
      .memory_mem_dm     (HPS_DDR3_DM),       //       .mem_dm
      .memory_oct_rzqin  (HPS_DDR3_RZQ),      //       .oct_rzqin

      .hps_io_hps_io_emac1_inst_TX_CLK(HPS_ENET_GTX_CLK),     // hps_io.hps_io_emac1_inst_TX_CLK
      .hps_io_hps_io_emac1_inst_TXD0  (HPS_ENET_TX_DATA[0]),  //       .hps_io_emac1_inst_TXD0
      .hps_io_hps_io_emac1_inst_TXD1  (HPS_ENET_TX_DATA[1]),  //       .hps_io_emac1_inst_TXD1
      .hps_io_hps_io_emac1_inst_TXD2  (HPS_ENET_TX_DATA[2]),  //       .hps_io_emac1_inst_TXD2
      .hps_io_hps_io_emac1_inst_TXD3  (HPS_ENET_TX_DATA[3]),  //       .hps_io_emac1_inst_TXD3
      .hps_io_hps_io_emac1_inst_RXD0  (HPS_ENET_RX_DATA[0]),  //       .hps_io_emac1_inst_RXD0
      .hps_io_hps_io_emac1_inst_MDIO  (HPS_ENET_MDIO),        //       .hps_io_emac1_inst_MDIO
      .hps_io_hps_io_emac1_inst_MDC   (HPS_ENET_MDC),         //       .hps_io_emac1_inst_MDC
      .hps_io_hps_io_emac1_inst_RX_CTL(HPS_ENET_RX_DV),       //       .hps_io_emac1_inst_RX_CTL
      .hps_io_hps_io_emac1_inst_TX_CTL(HPS_ENET_TX_EN),       //       .hps_io_emac1_inst_TX_CTL
      .hps_io_hps_io_emac1_inst_RX_CLK(HPS_ENET_RX_CLK),      //       .hps_io_emac1_inst_RX_CLK
      .hps_io_hps_io_emac1_inst_RXD1  (HPS_ENET_RX_DATA[1]),  //       .hps_io_emac1_inst_RXD1
      .hps_io_hps_io_emac1_inst_RXD2  (HPS_ENET_RX_DATA[2]),  //       .hps_io_emac1_inst_RXD2
      .hps_io_hps_io_emac1_inst_RXD3  (HPS_ENET_RX_DATA[3]),  //       .hps_io_emac1_inst_RXD3

      .hps_io_hps_io_sdio_inst_CMD(HPS_SD_CMD),      // .hps_io_sdio_inst_CMD
      .hps_io_hps_io_sdio_inst_D0 (HPS_SD_DATA[0]),  // .hps_io_sdio_inst_D0
      .hps_io_hps_io_sdio_inst_D1 (HPS_SD_DATA[1]),  // .hps_io_sdio_inst_D1
      .hps_io_hps_io_sdio_inst_CLK(HPS_SD_CLK),      // .hps_io_sdio_inst_CLK
      .hps_io_hps_io_sdio_inst_D2 (HPS_SD_DATA[2]),  // .hps_io_sdio_inst_D2
      .hps_io_hps_io_sdio_inst_D3 (HPS_SD_DATA[3]),  // .hps_io_sdio_inst_D3

      .hps_io_hps_io_usb1_inst_D0 (HPS_USB_DATA[0]),  // .hps_io_usb1_inst_D0
      .hps_io_hps_io_usb1_inst_D1 (HPS_USB_DATA[1]),  // .hps_io_usb1_inst_D1
      .hps_io_hps_io_usb1_inst_D2 (HPS_USB_DATA[2]),  // .hps_io_usb1_inst_D2
      .hps_io_hps_io_usb1_inst_D3 (HPS_USB_DATA[3]),  // .hps_io_usb1_inst_D3
      .hps_io_hps_io_usb1_inst_D4 (HPS_USB_DATA[4]),  // .hps_io_usb1_inst_D4
      .hps_io_hps_io_usb1_inst_D5 (HPS_USB_DATA[5]),  // .hps_io_usb1_inst_D5
      .hps_io_hps_io_usb1_inst_D6 (HPS_USB_DATA[6]),  // .hps_io_usb1_inst_D6
      .hps_io_hps_io_usb1_inst_D7 (HPS_USB_DATA[7]),  // .hps_io_usb1_inst_D7
      .hps_io_hps_io_usb1_inst_CLK(HPS_USB_CLKOUT),   // .hps_io_usb1_inst_CLK
      .hps_io_hps_io_usb1_inst_STP(HPS_USB_STP),      // .hps_io_usb1_inst_STP
      .hps_io_hps_io_usb1_inst_DIR(HPS_USB_DIR),      // .hps_io_usb1_inst_DIR
      .hps_io_hps_io_usb1_inst_NXT(HPS_USB_NXT),      // .hps_io_usb1_inst_NXT

      .hps_io_hps_io_uart0_inst_RX(HPS_UART_RX),  // .hps_io_uart0_inst_RX
      .hps_io_hps_io_uart0_inst_TX(HPS_UART_TX),  // .hps_io_uart0_inst_TX

      .hps_data_export            (hps_data),              //             hps_data.export
      .logit_0_export             (logits[0]),             //              logit_0.export
      .logit_1_export             (logits[1]),             //              logit_1.export
      .logit_2_export             (logits[2]),             //              logit_2.export
      .logit_3_export             (logits[3]),             //              logit_3.export
      .logit_4_export             (logits[4]),             //              logit_4.export
      .logit_5_export             (logits[5]),             //              logit_5.export
      .logit_6_export             (logits[6]),             //              logit_6.export
      .logit_7_export             (logits[7]),             //              logit_7.export
      .logit_8_export             (logits[8]),             //              logit_8.export
      .logit_9_export             (logits[9]),             //              logit_9.export
      .hps_data_valid_export      (hps_data_valid),        //       hps_data_valid.export
      .hps_start_conv_export      (hps_start_conv),        //       hps_start_conv.export
      .hps_logits_retrieved_export(hps_logits_retrieved),  // hps_logits_retrieved.export
      .hps_state_export           (hps_state),             //            hps_state.export

      .debug_fc_hold_counter_export(input_valid)
  );

  // Counter for the number of holds requested by fully connected layer
  // When the counter reaches 1600 (number of outputs of second conv layer),
  // the circuit finished processing one input image and we can proceed to next input.
  reg [$clog2(N_OUTPUTS_LAYER_1):0] fc_hold_counter = 0;
  reg fc_last_hold = 0;
  reg input_valid = 0;
  reg next_input = 0;

  always @(posedge system_clock, posedge global_reset) begin
    if (global_reset) begin
      rami_wraddress  <= 0;
      fc_hold_counter <= 0;
      fc_last_hold    <= 0;
      input_valid     <= 0;
      next_input      <= 0;
    end else begin
      case (hps_state)
        HPS_WAIT_DATA_S: begin
          next_input <= 0;
          rami_wren <= 0;
          rami_data_in <= hps_data;
          if (hps_data_valid) begin
            rami_wren <= 1;
            hps_state <= HPS_WRITE_DATA_S;
          end else if (hps_start_conv) begin
            input_valid <= 1;
            hps_state <= HPS_WAIT_CONV_S;
          end else begin
            hps_state <= HPS_WAIT_DATA_S;
          end
        end

        HPS_WRITE_DATA_S: begin
          rami_wren <= 0;
          rami_wraddress <= rami_wraddress + 1;
          if (!hps_data_valid) begin
            hps_state <= HPS_WAIT_DATA_S;
          end else begin
            hps_state <= HPS_WRITE_DATA_S;
          end
        end

        HPS_WAIT_CONV_S: begin
          if(hold_data_fc && !fc_last_hold) begin
            fc_hold_counter = fc_hold_counter + 1;
          end

          if (fc_hold_counter == N_OUTPUTS_LAYER_1) begin
            hps_state <= HPS_CONV_DONE_S;
          end

          fc_last_hold = hold_data_fc;
        end

        HPS_CONV_DONE_S: begin
          if(hps_logits_retrieved) begin
            rami_wraddress  <= 0;
            fc_hold_counter <= 0;
            fc_last_hold    <= 0;
            input_valid     <= 0;
            next_input      <= 1;
          end
        end

        default: hps_state <= HPS_WAIT_DATA_S;
      endcase
    end
  end

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
      .clock  (pll_clock),
      .q      (rfc0_data_out)
  );

  always @(posedge system_clock, posedge global_reset, posedge next_input) begin
    if (global_reset || next_input) begin
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
      if (pll_locked && input_valid) begin
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
  end
endmodule

