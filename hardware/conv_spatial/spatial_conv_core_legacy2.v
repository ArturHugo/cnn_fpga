module spatial_conv_core #(
    parameter ADDR_WIDTH  = 16,
    parameter DATA_WIDTH  = 32,
    parameter FRAC_WIDTH  = 16,

    parameter N_ROWS      = 28,
    parameter N_COLS      = 28,
    parameter N_CHANNELS  = 1,
    parameter N_KERNELS   = 32,

    parameter KERNEL_SIZE = 3,
    parameter CONV_STRIDE = 1,

    parameter POOL_SIZE   = 2,
    parameter POOL_STRIDE = 2
)(
    input  wire  clock_i,
    input  wire  reset_i,
    input  wire  data_valid_i   [0:N_CHANNELS-1],
    input  wire  kernel_valid_i [0:N_CHANNELS-1],
    input  wire  hold_data_i    [0:N_KERNELS-1],
    input  wire  [DATA_WIDTH-1:0] data_i [0:N_CHANNELS-1],
    input  wire  [DATA_WIDTH-1:0] kernel_i [0:N_CHANNELS-1][0:KERNEL_SIZE*KERNEL_SIZE-1],
    input  wire  [DATA_WIDTH-1:0] bias_i,
    output logic [DATA_WIDTH-1:0] data_o [0:N_KERNELS-1],
    output logic data_valid_o   [0:N_KERNELS-1],
    output logic hold_kernel_o  [0:N_CHANNELS-1],
    output logic hold_data_o    [0:N_CHANNELS-1],
    output logic conv_overflow
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
    
    localparam BUFFER_SIZE = (KERNEL_SIZE-1)*N_COLS + KERNEL_SIZE;
    localparam STATE_WIDTH = 4;
    localparam [STATE_WIDTH-1:0]  // States
    WAIT_CHANNEL_VALID_S = 0,
    CHANNEL_VALID_S      = 1;

    reg [STATE_WIDTH-1:0] curr_state = 0;

    wire [DATA_WIDTH-1:0] conv_result;

    wire [DATA_WIDTH-1:0] input_window [0:N_CHANNELS-1][0:KERNEL_SIZE*KERNEL_SIZE-1];

    wire [DATA_WIDTH-1:0] pool_window [0:N_KERNELS-1][0:POOL_SIZE*POOL_SIZE-1];
    wire [DATA_WIDTH-1:0] pool_result;

    reg conv_valid [0:N_KERNELS-1];
    reg pool_valid [0:N_KERNELS-1];

    reg [DATA_WIDTH-1:0] channel_accumulator = 0;
    reg reset_accumulator = 0;
    
    reg hold_data_reg [0:N_CHANNELS-1] = '{default: 0};

    reg hold_kernel_reg [0:N_CHANNELS-1];

    reg pool_valid_sel [0:N_KERNELS-1] = '{default: 0};
    reg [$clog2(2*(N_COLS-2)):0] pool_elements [0:N_KERNELS-1] = '{default: 0};
    reg [$clog2((N_COLS-2)/2):0] pool_valid_counter [0:N_KERNELS-1] = '{default: 0};

    reg [$clog2(N_CHANNELS):0] buffer_channel = 0;
    reg [$clog2(BUFFER_SIZE+N_COLS-KERNEL_SIZE):0] buffered_elements [0:N_CHANNELS-1] = '{default: 0};
    reg [$clog2(N_ROWS-2):0] conv_rows_left [0:N_CHANNELS-1] = '{default: N_ROWS - 2};

    reg [$clog2(N_CHANNELS):0] prev_channel = 0;
    reg [$clog2(N_CHANNELS):0] curr_channel = 0;
    reg [$clog2(N_CHANNELS):0] next_channel = 0;

    reg [$clog2(N_KERNELS):0]  prev_kernel [0:N_CHANNELS-1] = '{default: 0};
    reg [$clog2(N_KERNELS):0]  curr_kernel [0:N_CHANNELS-1] = '{default: 0};
    reg [$clog2(N_KERNELS):0]  next_kernel [0:N_CHANNELS-1] = '{default: 0};

    assign data_valid_o = pool_valid;

    spatial_conv_kernel #(
        .DATA_WIDTH  (DATA_WIDTH),
        .FRAC_WIDTH  (FRAC_WIDTH),
        .KERNEL_SIZE (KERNEL_SIZE)
    ) SPATIAL_CONV_KERNEL_0 (
        .window   (input_window[curr_channel]),
        .kernel   (kernel_i[curr_channel]),
        .result   (conv_result),
        .overflow (conv_overflow)
    );
    
    max_pool_2x2 #(
        .DATA_WIDTH (DATA_WIDTH)
    ) POOL_2x2_0 (
        .data_i   (pool_window[prev_kernel[prev_channel]]),
        .result_o (pool_result)
    );

    genvar channel;
    generate
        for(channel = 0; channel < N_CHANNELS; channel = channel + 1) begin : channel_loop

            // Requests hold for specific input channel if needed internally or if next layer
            // is requesting hold from any output channel.
            // "a === 1" will make so that 'x' is treated as '0', avoiding undefined output
            assign hold_data_o[channel] = hold_data_reg[channel] ||
                                          (hold_data_i.or() === 1);

            window_buffer #(
                .DATA_WIDTH  (DATA_WIDTH),
                .LINE_LENGTH (N_COLS),
                .WINDOW_SIZE (KERNEL_SIZE)
            ) INPUT_WINDOW_BUFFER (
                .clk_i    (clock_i),
                .data_i   (data_i[channel]),
                .enable_i (data_valid_i[channel] && !hold_data_o[channel]),
                .window_o (input_window[channel])
            );

            always @(posedge clock_i, posedge reset_i) begin
                if(reset_i) begin
                    hold_kernel_o[channel] <= 0;
                end else begin
                    if(kernel_valid_i[channel]) begin
                        hold_kernel_o[channel] <= 1;
                    end
                    if(hold_kernel_reg[channel] == 0) begin
                        hold_kernel_o[channel] <= 0;
                    end
                end
            end
        end
    endgenerate

    genvar kernel;
    generate
        for(kernel = 0; kernel < N_KERNELS; kernel = kernel + 1) begin : kernel_loop

            assign data_o[kernel] = pool_valid[kernel] ? pool_result : 32'habab;

            window_buffer #(
                .DATA_WIDTH  (DATA_WIDTH),
                .LINE_LENGTH (N_COLS-KERNEL_SIZE+1),
                .WINDOW_SIZE (POOL_SIZE)
            ) POOL_WINDOW_BUFFER (
                .clk_i    (clock_i),
                .data_i   (channel_accumulator),
                .enable_i (conv_valid[kernel]),
                .window_o (pool_window[kernel])
            );
        end
    endgenerate

    /**** Convolution control ****/
    always @(posedge clock_i, posedge reset_i) begin
        if(reset_i) begin
            curr_state    <= 0;
            prev_channel  <= 0;
            curr_channel  <= 0;
            next_channel  <= 0;
            prev_kernel   <= '{default: 0};
            curr_kernel   <= '{default: 0};
            next_kernel   <= '{default: 0};
            conv_valid    <= '{default: 0};
            hold_data_reg <= '{default: 0};

            hold_kernel_reg <= '{default: 1};

            channel_accumulator <= 0;
            reset_accumulator   <= 0;

            buffer_channel    <= 0;
            buffered_elements <= '{default: 0};
            conv_rows_left    <= '{default: N_ROWS - 2};
            hold_data_reg     <= '{default: 0};

            pool_elements  <= '{default: 0};
            pool_valid_sel <= '{default: 0};
            pool_valid     <= '{default: 0};
            pool_valid_counter <= '{default: 0};
        end else begin
            /**** Input buffer control ****/
            if(conv_rows_left[curr_channel] != 0) begin
                if(hold_data_reg[curr_channel]) begin
                    // If we reach the end of line
                    if(buffered_elements[curr_channel] == BUFFER_SIZE+N_COLS-KERNEL_SIZE) begin
                        // Decrement the counter of valid buffered values so that we
                        // wait for alignment and can proceed to read next line.
                        buffered_elements[curr_channel] = BUFFER_SIZE - KERNEL_SIZE;

                        // Decrement the number of rows left for processing so we know
                        // when we are done.
                        conv_rows_left[curr_channel] = conv_rows_left[curr_channel] - 1;
                    end
                end else begin
                    if(data_valid_i[curr_channel]) begin
                        // Increment the number of valid elements put on buffer
                        buffered_elements[curr_channel] = buffered_elements[curr_channel] + 1;

                        // If we put enough elements so that we reach first valid window,
                        // request for channel hold internally.
                        if(buffered_elements[curr_channel] >= BUFFER_SIZE) begin
                            hold_data_reg[curr_channel] = 1;
                        end
                    end
                end
            end
            /******************************/

            /**** Channel and filter sequencing logic ****/
            case(curr_state)
                WAIT_CHANNEL_VALID_S: begin
                    // If we need to hold the output data for current channel,
                    // we kee waiting.
                    if(hold_data_i[curr_kernel[curr_channel]]) begin
                        curr_state <= WAIT_CHANNEL_VALID_S;
                    end else begin
                        // No convolution result is valid while we wait a valid channel
                        conv_valid = '{default: 0};

                        // If we have a valid kernel for this channel, signal to hold it
                        hold_kernel_reg[prev_channel] = 1;
                        
                        // If we have both a valid window and a valid kernel for the current channel,
                        // we can proceed with convolution. Otherwise, keep waiting
                        if(hold_data_reg[curr_channel] && kernel_valid_i[curr_channel]) begin
                            curr_state <= CHANNEL_VALID_S;
                        end else begin
                            curr_state <= WAIT_CHANNEL_VALID_S;
                        end
                    end
                end

                CHANNEL_VALID_S: begin
                    // The convolution of the channel has been done
                    // So we can read the same channel from the next kernel
                    hold_kernel_reg[curr_channel] = 0;

                    next_kernel[curr_channel] = curr_kernel[curr_channel] + 1;

                    // If we reach the last channel, wrap around and indicate
                    // that we have one kernel less to convolve with the current window
                    next_channel = curr_channel + 1;
                    if(next_channel == N_CHANNELS) begin
                        next_channel = 0;

                        // Raise convolution valid signal once all the channels of the
                        // convolution have been properly accumulated. Then proceed to next kernel
                        conv_valid[curr_kernel[curr_channel]] = 1;

                        // Signal to reset the channel accumulator for the new filter
                        reset_accumulator <= 1;
                    end

                    // If we convolved all the kernels with this window,
                    // we can proceed to the next one after we process each channel
                    if(curr_kernel[next_channel] == N_KERNELS) begin
                        hold_data_reg[next_channel] = 0;
                        curr_kernel[next_channel] = 0;
                    end

                    if(reset_accumulator) begin
                        channel_accumulator  = 0;
                        reset_accumulator   <= 0;
                    end

                    // Accumulate the convolution of this channel in an accumulator register
                    if(next_channel < N_CHANNELS) begin
                        channel_accumulator = channel_accumulator + conv_result;
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

            // Pooling buffer control
            if(conv_valid[prev_kernel[prev_channel]]) begin
                pool_elements[prev_kernel[prev_channel]] = pool_elements[prev_kernel[prev_channel]] + 1;
                if(pool_elements[prev_kernel[prev_channel]] == N_COLS) begin
                    pool_valid_sel[prev_kernel[prev_channel]] = 1;
                end
            end else if(pool_valid_counter[prev_kernel[prev_channel]] == (N_COLS-2)/2) begin
                pool_valid_sel[prev_kernel[prev_channel]] = 0;
                pool_elements[prev_kernel[prev_channel]]  = 0;
                pool_valid_counter[prev_kernel[prev_channel]] = 0;
                pool_valid[prev_kernel[prev_channel]] <= 0;
            end else
            if(pool_valid_sel[prev_kernel[prev_channel]]) begin
                pool_valid_sel[prev_kernel[prev_channel]] = 0;
                pool_elements[prev_kernel[prev_channel]] =
                    pool_elements[prev_kernel[prev_channel]] - POOL_SIZE;
                pool_valid_counter[prev_kernel[prev_channel]] = 
                    pool_valid_counter[prev_kernel[prev_channel]] + 1;
                pool_valid[prev_kernel[prev_channel]] <= 1;
            end else begin
                pool_valid[prev_kernel[prev_channel]] <= 0;
            end
        end
        
    end
    /*****************************/
endmodule
