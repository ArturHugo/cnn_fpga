// verilog_lint: waive-start explicit-parameter-storage-type
module winograd_4x4_conv_core #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter FRAC_WIDTH = 16,

    parameter N_ROWS     = 28,
    parameter N_COLS     = 28,
    parameter N_CHANNELS = 3,
    parameter N_KERNELS  = 64,

    parameter KERNEL_SIZE = 4,
    parameter CONV_STRIDE = 2,

    parameter POOL_SIZE   = 2,
    parameter POOL_STRIDE = 2
) (
    input logic clock_i,
    input logic reset_i,
    input logic data_valid_i  [N_CHANNELS],
    input logic kernel_valid_i[N_CHANNELS],
    input logic hold_data_i   [ N_KERNELS],

    input logic [DATA_WIDTH-1:0] bias_i,
    input logic [DATA_WIDTH-1:0] data_i  [N_CHANNELS],
    input logic [DATA_WIDTH-1:0] kernel_i[N_CHANNELS][KERNEL_SIZE*KERNEL_SIZE],

    output logic conv_overflow,
    output logic data_valid_o [ N_KERNELS],
    output logic hold_kernel_o[N_CHANNELS],
    output logic hold_data_o  [N_CHANNELS],

    output logic [DATA_WIDTH-1:0] data_o[N_KERNELS]
);
  //  for each window of input
  //      for each channel of window
  //          for each corresponding channel kernel
  //              conv
  //
  // conforme chegam janelas da camada anterior
  // a camada atual convolui os filtros do canal correspondente
  // com essa janela e insere o resultado no buffer de janela do canal
  // correspondente ao canal do filtro

  // verilog_lint: waive-start parameter-name-style
  localparam BUFFER_SIZE = (KERNEL_SIZE - 1) * N_COLS + KERNEL_SIZE;
  localparam STATE_WIDTH = 4;
  localparam [STATE_WIDTH-1:0]  // States
  WAIT_CHANNEL_VALID_S = 0, CHANNEL_VALID_S = 1;
  // verilog_lint: waive-stop parameter-name-style

  reg [STATE_WIDTH-1:0] curr_state = 0;

  wire signed [DATA_WIDTH-1:0] conv_result[2*2];

  logic [DATA_WIDTH-1:0] input_window[N_CHANNELS][KERNEL_SIZE*KERNEL_SIZE];

  wire [$clog2(N_KERNELS)-1:0] valid_pool_index;
  wire [DATA_WIDTH-1:0] pool_window[N_KERNELS][POOL_SIZE*POOL_SIZE];
  wire [DATA_WIDTH-1:0] pool_result;

  wire [DATA_WIDTH-1:0] activation_result;

  reg conv_valid[N_KERNELS];
  reg pool_valid[N_KERNELS];

  reg signed [DATA_WIDTH-1:0] channel_accumulator[2*2] = '{default: 0};
  reg reset_accumulator = 0;

  reg hold_data_internal[N_CHANNELS] = '{default: 0};

  reg hold_data_aux[N_CHANNELS] = '{default: 0};
  reg hold_kernel_aux[N_CHANNELS];

  reg ignored_last_col[N_KERNELS] = '{default: 0};
  reg pool_valid_sel[N_KERNELS] = '{default: 0};
  reg [$clog2(2*(N_COLS-2)):0] pool_elements[N_KERNELS] = '{default: 0};
  reg [$clog2((N_COLS-2)/2):0] pool_valid_counter[N_KERNELS] = '{default: 0};

  reg [$clog2(N_CHANNELS):0] buffer_channel = 0;
  reg [$clog2(BUFFER_SIZE+N_COLS-KERNEL_SIZE):0] buffered_elements[N_CHANNELS] = '{default: 0};
  reg [$clog2(N_ROWS-2):0] conv_rows_left[N_CHANNELS] = '{default: N_ROWS - 2};

  reg [$clog2(N_CHANNELS):0] prev_channel = 0;
  reg [$clog2(N_CHANNELS):0] curr_channel = 0;
  reg [$clog2(N_CHANNELS):0] next_channel = 0;

  reg [$clog2(N_KERNELS):0] prev_kernel[N_CHANNELS] = '{default: 0};
  reg [$clog2(N_KERNELS):0] curr_kernel[N_CHANNELS] = '{default: 0};
  reg [$clog2(N_KERNELS):0] next_kernel[N_CHANNELS] = '{default: 0};

  assign data_valid_o = pool_valid;

  winograd_4x4_conv_kernel #(
      .DATA_WIDTH(DATA_WIDTH),
      .FRAC_WIDTH(FRAC_WIDTH)
  ) WINOGRAD_4x4_CONV_KERNEL_0 (
      .window  (input_window[curr_channel]),
      .kernel  (kernel_i[curr_channel]),
      .result  (conv_result),
      .overflow(conv_overflow)
  );

  max_pool_2x2 #(
      .DATA_WIDTH(DATA_WIDTH)
  ) POOL_2x2_0 (
      .data_i  (channel_accumulator),
      .result_o(pool_result)
  );

  relu #(
    .DATA_WIDTH(DATA_WIDTH)
  ) ACTIVATION_0 (
    .data_i(pool_result),
    .result_o(activation_result)
  );

  genvar channel;
  generate
    for (channel = 0; channel < N_CHANNELS; channel = channel + 1) begin : g_channel_loop

      // Requests hold for specific input channel if needed internally or if next layer
      // is requesting hold from any output channel.
      // "a === 1" will make so that 'x' is treated as '0', avoiding undefined output
      assign hold_data_o[channel] = hold_data_internal[channel] || (hold_data_i.or() === 1);

      window_buffer #(
          .DATA_WIDTH (DATA_WIDTH),
          .LINE_LENGTH(N_COLS),
          .WINDOW_SIZE(KERNEL_SIZE)
      ) INPUT_WINDOW_BUFFER (
          .clk_i   (clock_i),
          .data_i  (data_i[channel]),
          .enable_i(data_valid_i[channel] && !hold_data_o[channel]),
          .window_o(input_window[channel])
      );

      always @(posedge clock_i, posedge reset_i) begin
        if (reset_i) begin
          hold_kernel_o[channel] <= 0;
        end else begin
          if (kernel_valid_i[channel]) begin
            hold_kernel_o[channel] <= 1;
          end
          if (hold_kernel_aux[channel] == 0) begin
            hold_kernel_o[channel] <= 0;
          end
        end
      end

      always @(posedge clock_i, posedge reset_i) begin
        if (reset_i) begin
          buffered_elements[channel]  <= 0;
          conv_rows_left[channel]     <= N_ROWS - 2;
          hold_data_internal[channel] <= 0;
        end else begin
          if (conv_rows_left[channel] != 0) begin
            if (hold_data_o[channel]) begin
              // If we reach the end of line
              if (buffered_elements[channel] == BUFFER_SIZE + N_COLS - KERNEL_SIZE) begin
                // Skip two lines due to stride 2
                buffered_elements[channel] = buffered_elements[channel] - 2 * N_COLS;

                // Decrement the number of rows left for processing so we know
                // when we are done.
                conv_rows_left[channel] = conv_rows_left[channel] - 2;
              end
            end else begin
              if (data_valid_i[channel]) begin
                // Increment the number of valid elements put on buffer
                buffered_elements[channel] = buffered_elements[channel] + 1;

                // If we put enough elements so that we reach first
                // valid window, request for channel hold internally.
                if (buffered_elements[channel] >= BUFFER_SIZE) begin
                  // Enable internal hold every 2 steps of the window
                  if ((buffered_elements[channel] - BUFFER_SIZE) % 2 == 0) begin

                    hold_data_internal[channel] <= 1;
                  end else begin
                    hold_data_internal[channel] <= 0;

                    // If we reach the end of line
                    if (buffered_elements[channel] == BUFFER_SIZE + N_COLS - KERNEL_SIZE) begin
                      // Skip two lines due to stride 2
                      buffered_elements[channel] = buffered_elements[channel] - 2 * N_COLS;

                      // Decrement the number of rows left for processing so we know
                      // when we are done.
                      conv_rows_left[channel] = conv_rows_left[channel] - 2;
                    end
                  end
                end
              end
            end
            if (hold_data_aux[channel] == 0) begin
              hold_data_internal[channel] <= 0;
            end
          end
        end
      end
    end
  endgenerate

  genvar kernel;
  generate
    for (kernel = 0; kernel < N_KERNELS; kernel = kernel + 1) begin : g_kernel_loop
      assign data_o[kernel] = pool_valid[kernel] ? activation_result : 32'hXXXX_XXXX;
    end
  endgenerate

  /**** Convolution control ****/
  always @(posedge clock_i, posedge reset_i) begin
    if (reset_i) begin
      curr_state    <= 0;
      prev_channel  <= 0;
      curr_channel  <= 0;
      next_channel  <= 0;
      prev_kernel   <= '{default: 0};
      curr_kernel   <= '{default: 0};
      next_kernel   <= '{default: 0};
      conv_valid    <= '{default: 0};

      hold_data_aux   <= '{default: 1};
      hold_kernel_aux <= '{default: 1};

      channel_accumulator <= '{default: bias_i};
      reset_accumulator   <= 0;

      pool_valid <= '{default: 0};

    end else begin
      /**** Channel and filter sequencing logic ****/
      case (curr_state)
        WAIT_CHANNEL_VALID_S: begin
          pool_valid = '{default: 0};

          // If we need to hold the output data for current channel,
          // we kee waiting.
          if (hold_data_i.and()) begin
            curr_state <= WAIT_CHANNEL_VALID_S;
          end else begin
            // No convolution result is valid while we wait a valid channel
            conv_valid = '{default: 0};

            // If we have a valid window for this channel, signal to hold it
            hold_data_aux[prev_channel] = 1;

            // If we have a valid kernel for this channel, signal to hold it
            hold_kernel_aux[prev_channel] = 1;

            // If we have both a valid window and a valid kernel for the current channel,
            // we can proceed with convolution. Otherwise, keep waiting
            if (hold_data_internal[curr_channel] && kernel_valid_i[curr_channel]) begin
              curr_state <= CHANNEL_VALID_S;
            end else begin
              curr_state <= WAIT_CHANNEL_VALID_S;
            end
          end
        end

        CHANNEL_VALID_S: begin
          // The convolution of the channel has been done
          // So we can read te same channel from the next kernel
          hold_kernel_aux[curr_channel] = 0;

          next_kernel[curr_channel] = curr_kernel[curr_channel] + 1;

          // If we reach the last channel, wrap around and indicate
          // that we have one kernel less to convolve with the current window
          next_channel = curr_channel + 1;
          if (next_channel == N_CHANNELS) begin
            next_channel = 0;

            // Raise convolution valid signal once all the channels of the
            // convolution have been properly accumulated. Then proceed to next kernel
            conv_valid[curr_kernel[curr_channel]] = 1;

            // Signal to reset the channel accumulator for the new filter
            reset_accumulator <= 1;

            pool_valid[curr_kernel[curr_channel]] = 1;
          end

          // If we convolved all the kernels with this window,
          // we can proceed to the next one after we process each channel
          if (next_kernel[curr_channel] == N_KERNELS) begin
            hold_data_aux[curr_channel] = 0;
            next_kernel[curr_channel]   = 0;
          end

          if (reset_accumulator) begin
            channel_accumulator = '{default: bias_i};
            reset_accumulator <= 0;
          end

          // Accumulate the convolution of this channel in an accumulator register
          if (next_channel < N_CHANNELS) begin
            channel_accumulator[0] = channel_accumulator[0] + conv_result[0];
            channel_accumulator[1] = channel_accumulator[1] + conv_result[1];
            channel_accumulator[2] = channel_accumulator[2] + conv_result[2];
            channel_accumulator[3] = channel_accumulator[3] + conv_result[3];
          end

          // Preserve previous channel and kernel for pooling control
          prev_channel = curr_channel;
          prev_kernel[prev_channel] = curr_kernel[curr_channel];

          curr_kernel[curr_channel] = next_kernel[curr_channel];
          curr_channel = next_channel;

          // We need to check if the next channel is valid for processing
          curr_state <= WAIT_CHANNEL_VALID_S;
        end

        default: begin
          curr_state <= WAIT_CHANNEL_VALID_S;
        end
      endcase
      /*********************************************/
    end

  end
  /*****************************/
endmodule
