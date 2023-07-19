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
    parameter POOL_STRIDE = 2,

    parameter OUTPUT_WINDOW_SIZE = 3
)(
    // TODO usando apenas para debug
    output logic debug_conv_valid [0:N_KERNELS-1],
    output logic debug_pool_valid [0:N_KERNELS-1],
    output logic [DATA_WIDTH-1:0] debug_acc,

    input  wire  clock_i,
    input  wire  reset_i,
    input  wire  window_valid_i [0:N_CHANNELS-1],
    input  wire  kernel_valid_i [0:N_CHANNELS-1],
    input  wire  hold_window_i  [0:N_CHANNELS-1],
    input  wire  [DATA_WIDTH-1:0] window_i [0:N_CHANNELS-1][0:KERNEL_SIZE*KERNEL_SIZE-1],
    input  wire  [DATA_WIDTH-1:0] kernel_i [0:N_CHANNELS-1][0:KERNEL_SIZE*KERNEL_SIZE-1],
    input  wire  [DATA_WIDTH-1:0] bias_i,
    // input  wire  [$clog2(N_CHANNELS):0] channel_i,
    // output logic [$clog2(N_KERNELS):0] channel_o,
    output logic [DATA_WIDTH-1:0] window_o [0:N_KERNELS-1][0:OUTPUT_WINDOW_SIZE*OUTPUT_WINDOW_SIZE-1],
    output logic window_valid_o [0:N_CHANNELS-1],
    output logic hold_kernel_o  [0:N_CHANNELS-1],
    output logic hold_window_o  [0:N_CHANNELS-1],
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

    //TODO usando apenas para debug
    assign debug_conv_valid = conv_valid;
    assign debug_pool_valid = pool_valid;
    assign debug_acc = channel_accumulator;

    localparam OUTPUT_N_COLS = (N_COLS - KERNEL_SIZE + 1) / POOL_SIZE;
    localparam OUTPUT_N_ROWS = (N_ROWS - KERNEL_SIZE + 1) / POOL_SIZE;
    
    localparam INPUT_BUFFER_SIZE  = (KERNEL_SIZE-1)*N_COLS + KERNEL_SIZE;
    localparam OUTPUT_BUFFER_SIZE = (OUTPUT_WINDOW_SIZE-1)*(OUTPUT_N_COLS) + OUTPUT_WINDOW_SIZE;

    wire [DATA_WIDTH-1:0] conv_result;

    spatial_conv_kernel #(
        .DATA_WIDTH  (DATA_WIDTH),
        .FRAC_WIDTH  (FRAC_WIDTH),
        .KERNEL_SIZE (KERNEL_SIZE)
    ) SPATIAL_CONV_KERNEL_0 (
        .window   (
            window_i[
                curr_channel
            ]
        ),
        .kernel   (
            kernel_i[
                curr_channel
            ]
        ),
        .result   (conv_result),
        .overflow (conv_overflow),
    );

    
    wire [DATA_WIDTH-1:0] pool_window [0:N_KERNELS-1][0:POOL_SIZE*POOL_SIZE-1];

    wire conv_valid [0:N_KERNELS-1];
    wire pool_valid [0:N_KERNELS-1];

    // genvar channel;
    // generate
    //     for(channel = 0; channel < N_CHANNELS; channel = channel + 1) begin : input_channel_loop

    //         // assign conv_valid[channel] = window_valid_i[channel] && kernel_valid_i[channel];
            
    //     end
    // endgenerate

    reg [DATA_WIDTH-1:0] channel_accumulator = 0;
    reg  reset_accumulator = 0;

    genvar kernel;
    generate
        for(kernel = 0; kernel < N_KERNELS; kernel = kernel + 1) begin : output_channel_loop

            assign pool_valid[kernel] = pool_valid_sel[kernel] ?
                ((pool_elements[kernel] - N_COLS) % 2 == 0) : 0;

            window_buffer #(
                .DATA_WIDTH  (DATA_WIDTH),
                .LINE_LENGTH (N_COLS-KERNEL_SIZE+1),
                .WINDOW_SIZE (POOL_SIZE)
            ) POOL_WINDOW_BUFFER (
                .clk_i    (clock_i),
                .data_i   (channel_accumulator),
                .enable_i (conv_valid[kernel]),
                .window_o (
                    pool_window[
                        kernel
                    ]
                )
            );
            window_buffer #(
                .DATA_WIDTH  (DATA_WIDTH),
                .LINE_LENGTH (OUTPUT_N_COLS),
                .WINDOW_SIZE (OUTPUT_WINDOW_SIZE)
            ) OUTPUT_WINDOW_BUFFER (
                .clk_i    (clock_i),
                .data_i   (pool_result),
                .enable_i (pool_valid[kernel]),
                .window_o (
                    window_o[
                        kernel
                    ]
                )
            );
        end
    endgenerate
    
    wire [DATA_WIDTH-1:0] pool_result;

    max_pool_2x2 #(
        .DATA_WIDTH (DATA_WIDTH)
    ) POOL_2x2_0 (
        .data_i   (
            pool_window[
                curr_kernel[curr_channel]
            ]
        ),
        .result_o (pool_result)
    );

    reg pool_valid_sel [0:N_KERNELS-1] = '{default: 0};
    reg [$clog2(2*(N_COLS-2)):0] pool_elements [0:N_KERNELS-1] = '{default: 0}; 

    always @(posedge clock_i, posedge reset_i) begin
        if(reset_i) begin
            pool_elements  <= '{default: 0};
            pool_valid_sel <= '{default: 0};
        end else if(conv_valid[curr_kernel[curr_channel]]) begin
            pool_elements[curr_kernel[curr_channel]] = pool_elements[curr_kernel[curr_channel]] + 1;
            if(pool_elements[curr_kernel[curr_channel]] == N_COLS) begin
                pool_valid_sel[curr_kernel[curr_channel]] <= 1;
            end
        end else if(pool_elements[curr_kernel[curr_channel]] == 2*(N_COLS-2)) begin
            pool_valid_sel[curr_kernel[curr_channel]] <= 0;
            pool_elements[curr_kernel[curr_channel]]  <= 0;
        end
    end

    reg [$clog2(N_CHANNELS):0] curr_channel = 0;
    reg [$clog2(N_CHANNELS):0] next_channel = 0;

    reg [$clog2(N_KERNELS):0]  curr_kernel [0:N_CHANNELS-1] = '{default: 0};
    reg [$clog2(N_KERNELS):0]  next_kernel [0:N_CHANNELS-1] = '{default: 0};

    localparam [0:0]  // States
    WAIT_CHANNEL_VALID_S = 0,
    CHANNEL_VALID_S      = 1;

    reg [0:0] curr_state = 0;

    /**** Convolution control ****/
    always @(posedge clock_i, posedge reset_i) begin
        if(reset_i) begin
            curr_state    <= 0;
            curr_channel  <= 0;
            next_channel  <= 0;
            curr_kernel   <= '{default: 0};
            next_kernel   <= '{default: 0};
            conv_valid    <= '{default: 0};
            hold_window_o <= '{default: 0};
            hold_kernel_o <= '{default: 0};
            channel_accumulator <= 0;
            reset_accumulator   <= 0;
        end else begin
            case(curr_state)
                WAIT_CHANNEL_VALID_S: begin
                    // If we need to hold the window of current channel for next layer processing
                    // we keep waiting
                    if(hold_window_i[curr_channel]) begin
                        curr_state <= WAIT_CHANNEL_VALID_S;
                    end else begin
                        // No convolution result is valid while we wait a valid channel
                        conv_valid <= '{default: 0};

                        // If we reach a valid window for this channel, signal to hold it
                        if(window_valid_i[curr_channel]) begin
                            hold_window_o[curr_channel] <= 1;
                        end

                        // If we have a valid kernel for this channel, signal to hold it
                        if(kernel_valid_i[curr_channel]) begin
                            hold_kernel_o[curr_channel] <= 1;
                        end
                        
                        // If we have both a valid window and a valid kernel for the current channel,
                        // we can proceed with convolution. Otherwise, keep waiting
                        if(window_valid_i[curr_channel] && kernel_valid_i[curr_channel]) begin
                            curr_state <= CHANNEL_VALID_S;
                        end else begin
                            curr_state <= WAIT_CHANNEL_VALID_S;
                        end
                    end
                end

                CHANNEL_VALID_S: begin
                    // The convolution of the channel has been done
                    // So we can read the same channel from the next kernel
                    hold_kernel_o[curr_channel] <= 0;

                    next_kernel[curr_channel] = curr_kernel[curr_channel] + 1;

                    next_channel = curr_channel + 1;
                    if(next_channel == N_CHANNELS) begin
                        next_channel = 0;
                    end

                    // If we convolved all the kernels with this window,
                    // we can proceed to the next one after we process each channel
                    if(next_kernel[next_channel] == N_KERNELS) begin
                        hold_window_o[next_channel] <= 0;
                        next_kernel[next_channel] = 0;
                    end

                    if(reset_accumulator) begin
                        channel_accumulator  = 0;
                        reset_accumulator   <= 0;
                    end

                    // Accumulate the convolution of this channel in an accumulator register
                    if(next_channel <= N_CHANNELS) begin // TODO testar com <=
                        channel_accumulator = channel_accumulator + conv_result;
                    end

                    // If we reach the last channel, wrap around and indicate
                    // that we have one kernel less to convolve with the current window
                    if(next_channel == N_CHANNELS) begin
                        // Raise convolution valid signal once all the channels of the
                        // convolution have been properly accumulated. Then proceed to next kernel
                        conv_valid[curr_kernel[curr_channel]] = 1;

                        // Signal to reset the channel accumulator for the new filter
                        reset_accumulator <= 1;
                    end

                    curr_kernel[curr_channel] = next_kernel[curr_channel];
                    curr_channel = next_channel;

                    // We need to check if the next channel is valid for processing
                    curr_state <= WAIT_CHANNEL_VALID_S;
                end

                default: begin
                    curr_state <= WAIT_CHANNEL_VALID_S;
                end
            endcase
        end
    end
    /*****************************/

    // TODO testar
    /**** Output window valid control ****/
    reg [$clog2(OUTPUT_BUFFER_SIZE+OUTPUT_N_COLS-OUTPUT_WINDOW_SIZE):0] output_elements [0:N_KERNELS-1] = '{default: 0};

    reg [$clog2(OUTPUT_WINDOW_SIZE-1):0] alignment_counter = 0;

    always @(posedge clock_i, posedge reset_i) begin
        if(reset_i) begin
            alignment_counter <= 0;
            output_elements   <= '{default: 0};
            window_valid_o    <= '{default: 0};
        end else if(pool_valid[curr_kernel[curr_channel]]) begin
            output_elements[curr_kernel[curr_channel]] = output_elements[curr_kernel[curr_channel]] + 1;
            if(alignment_counter > 0) begin
                alignment_counter <= alignment_counter - 1;
                // TODO testar buffer size -1 para garantir que nao seja feita mais uma leitura
                // depois de chegar em uma janela valida
            end else if(output_elements[curr_kernel[curr_channel]] >= OUTPUT_BUFFER_SIZE-1) begin
                window_valid_o[curr_kernel[curr_channel]] <= 1;
            end
        end else if(output_elements[curr_kernel[curr_channel]] == OUTPUT_BUFFER_SIZE
                                                    + OUTPUT_N_COLS 
                                                    - OUTPUT_WINDOW_SIZE) begin
            window_valid_o[curr_kernel[curr_channel]]  <= 0;
            output_elements[curr_kernel[curr_channel]] <= OUTPUT_BUFFER_SIZE-1;
            alignment_counter <= OUTPUT_WINDOW_SIZE;
        end
    end
    /*************************************/
endmodule
