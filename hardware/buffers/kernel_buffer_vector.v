// verilog_lint: waive-start explicit-parameter-storage-type
module kernel_buffer_vector #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,

    parameter N_CHANNELS  = 1,
    parameter N_KERNELS   = 32,
    parameter KERNEL_SIZE = 3,

    parameter KERNEL_BASE_ADDR = 0
) (
    input logic clock_i,
    input logic reset_i,
    input logic enable_i,
    input logic hold_kernel_i[N_CHANNELS],

    input logic [DATA_WIDTH-1:0] data_i,

    output logic kernel_valid_o[N_CHANNELS],

    output logic [DATA_WIDTH-1:0] bias_o,
    output logic [ADDR_WIDTH-1:0] kernel_rdaddress_o,
    output logic [DATA_WIDTH-1:0] kernel_o[N_CHANNELS*KERNEL_SIZE*KERNEL_SIZE]
);

  reg [$clog2(KERNEL_SIZE*KERNEL_SIZE):0] kernel_index = 0;
  reg [$clog2(N_KERNELS):0] curr_kernel[N_CHANNELS] = '{default: 0};
  reg [$clog2(N_CHANNELS):0] curr_channel = 0;

  // verilog_lint: waive-start parameter-name-style
  localparam STATE_WIDTH = 2;
  localparam [STATE_WIDTH-1:0]  // States
  READ_KERNEL_S = 0, WAIT_HOLD_S = 1;
  // verilog_lint: waive-stop parameter-name-style

  reg [STATE_WIDTH-1:0] curr_state = 0;

  reg kernel_valid_aux[N_CHANNELS] = '{default: 0};

  genvar channel;
  generate
    for (channel = 0; channel < N_CHANNELS; channel = channel + 1) begin : g_channel_loop
      always @(posedge clock_i, posedge reset_i) begin
        if (reset_i) begin
          kernel_valid_o[channel] <= 0;
        end else begin
          if (hold_kernel_i[channel] == 0) begin
            kernel_valid_o[channel] <= 0;
          end
          if (kernel_valid_aux[channel]) begin
            kernel_valid_o[channel] <= 1;
          end
        end
      end
    end
  endgenerate

  always @(posedge clock_i, posedge reset_i) begin
    if (reset_i) begin
      kernel_rdaddress_o <= KERNEL_BASE_ADDR;
      bias_o             <= data_i;
      kernel_o           <= '{default: 0};
      kernel_valid_aux   <= '{default: 0};
      curr_kernel        <= '{default: 0};
      kernel_index       <= 0;
      curr_channel       <= 0;
      curr_state         <= 0;
    end else begin
      if (enable_i) begin
        case (curr_state)
          READ_KERNEL_S: begin
            if (kernel_valid_o[curr_channel]) begin
              kernel_valid_aux[curr_channel] = 0;
              curr_channel = curr_channel + 1;
              if (curr_channel == N_CHANNELS) begin
                curr_channel = 0;
              end
              kernel_rdaddress_o = KERNEL_BASE_ADDR +
                                   curr_channel*KERNEL_SIZE*KERNEL_SIZE +
                                   curr_kernel[curr_channel]*(KERNEL_SIZE*KERNEL_SIZE*N_CHANNELS+1);
              if (curr_channel != 0) begin
                kernel_rdaddress_o = kernel_rdaddress_o + 1;
              end
            end else begin
              if (kernel_rdaddress_o == KERNEL_BASE_ADDR +
                                        curr_kernel[curr_channel]*
                                        (KERNEL_SIZE*KERNEL_SIZE*N_CHANNELS+1)) begin
                bias_o <= data_i;
                kernel_rdaddress_o = kernel_rdaddress_o + 1;
              end else begin
                kernel_o[curr_channel*KERNEL_SIZE*KERNEL_SIZE+kernel_index] <= data_i;
                kernel_rdaddress_o = kernel_rdaddress_o + 1;
                kernel_index = kernel_index + 1;
                if (kernel_index == KERNEL_SIZE * KERNEL_SIZE) begin
                  curr_kernel[curr_channel] = curr_kernel[curr_channel] + 1;
                  if (curr_kernel[curr_channel] == N_KERNELS) begin
                    curr_kernel[curr_channel] = 0;
                  end
                  kernel_index = 0;
                  kernel_valid_aux[curr_channel] = 1;
                  curr_state <= WAIT_HOLD_S;
                end
              end
            end
          end

          WAIT_HOLD_S: begin
            curr_state <= READ_KERNEL_S;
          end

          default: curr_state <= READ_KERNEL_S;
        endcase
      end
    end
  end
endmodule
