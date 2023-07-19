// verilog_lint: waive-start explicit-parameter-storage-type
module fully_connected #(
    parameter ADDR_WIDTH = 16,
    parameter BASE_ADDR  = 0,
    parameter DATA_WIDTH = 32,
    parameter FRAC_WIDTH = 16,
    parameter N_NEURONS  = 10
) (
    input logic clock_i,
    input logic reset_i,
    input logic enable_i,
    input logic data_valid_i,

    input logic [DATA_WIDTH-1:0] data_i,
    input logic [DATA_WIDTH-1:0] ram_weight_i,
    input logic [DATA_WIDTH-1:0] biases_i[N_NEURONS],

    output logic overflow_o,
    output logic hold_data_o,

    output logic [ADDR_WIDTH-1:0] ram_rdaddress_o,

    output logic signed [DATA_WIDTH-1:0] logits_o[N_NEURONS]
);

  // verilog_lint: waive-start parameter-name-style
  localparam STATE_WIDTH = 4;
  localparam [STATE_WIDTH-1:0]  // States
  WAIT_WEIGHTS_S = 0, WEIGHTS_VALID_S = 1;
  // verilog_lint: waive-stop parameter-name-style

  reg [STATE_WIDTH-1:0] curr_state = 0;

  reg weights_valid = 0;

  reg [$clog2(N_NEURONS):0] weight_counter = 0;
  reg [DATA_WIDTH-1:0] weights[N_NEURONS] = '{default: 0};

  wire overflows[N_NEURONS];

  wire signed [DATA_WIDTH-1:0] products[N_NEURONS];

  assign overflow_o = overflows.or();

  genvar neuron;
  generate
    for (neuron = 0; neuron < N_NEURONS; neuron = neuron + 1) begin : g_neurons_loop
      fixed_mult #(
          .DATA_WIDTH(DATA_WIDTH),
          .FRAC_WIDTH(FRAC_WIDTH)
      ) FIXED_MULT_0 (
          .in1(data_i),
          .in2(weights[neuron]),
          .result(products[neuron]),
          .overflow(overflows[neuron])
      );

      always @(posedge clock_i, posedge reset_i) begin
        if (reset_i) begin
          logits_o[neuron] <= biases_i[neuron];
        end else begin
          if (data_valid_i && weights_valid) begin
            logits_o[neuron] = logits_o[neuron] + products[neuron];
          end
        end
      end
    end
  endgenerate

  always @(posedge clock_i, posedge reset_i) begin
    if (reset_i) begin
      curr_state      <= 0;
      hold_data_o     <= 0;
      weights_valid   <= 0;
      weight_counter  <= 0;
      ram_rdaddress_o <= BASE_ADDR;
    end else begin
      if (enable_i) begin
        case (curr_state)
          WAIT_WEIGHTS_S: begin
            weights[weight_counter] = ram_weight_i;
            ram_rdaddress_o = ram_rdaddress_o + 1;
            weight_counter = weight_counter + 1;
            if (weight_counter == N_NEURONS) begin
              weight_counter = 0;
              weights_valid <= 1;
              hold_data_o   <= 0;
              curr_state    <= WEIGHTS_VALID_S;
            end
          end

          WEIGHTS_VALID_S: begin
            if (data_valid_i) begin
              weights_valid <= 0;
              hold_data_o   <= 1;
              curr_state    <= WAIT_WEIGHTS_S;
            end
          end

          default: curr_state <= WAIT_WEIGHTS_S;
        endcase
      end
    end
  end

endmodule
