// verilog_lint: waive-start explicit-parameter-storage-type
module fully_connected_comb #(  // TODO test
    parameter DATA_WIDTH = 32,
    parameter FRAC_WIDTH = 16,
    parameter N_INPUTS   = 1600,
    parameter N_NEURONS  = 10
) (
    input logic signed [DATA_WIDTH-1:0] data_i[N_INPUTS],
    input logic signed [DATA_WIDTH-1:0] weights_i[N_NEURONS][N_INPUTS],
    input logic signed [DATA_WIDTH-1:0] biases_i[N_NEURONS],

    output logic signed [DATA_WIDTH-1:0] logits_o[N_NEURONS]
);

  wire signed [DATA_WIDTH-1:0] products [N_NEURONS][  N_INPUTS];
  wire signed [DATA_WIDTH-1:0] sum_steps[N_NEURONS][N_INPUTS-1];

  genvar input_i;
  genvar neuron_i;

  generate
    for (neuron_i = 0; neuron_i < N_NEURONS; neuron_i = neuron_i + 1) begin : g_neuron_product_loop
      for (input_i = 0; input_i < N_INPUTS; input_i = input_i + 1) begin : g_input_product_loop
        fixed_mult #(
            .DATA_WIDTH(DATA_WIDTH),
            .FRAC_WIDTH(FRAC_WIDTH)
        ) m0 (
            .in1     (data_i[input_i]),
            .in2     (weights_i[neuron_i][input_i]),
            .result  (products[neuron_i][input_i]),
            .overflow()
        );
      end
    end
  endgenerate

  generate
    for (neuron_i = 0; neuron_i < N_NEURONS; neuron_i = neuron_i + 1) begin : g_neuron_loop
      assign sum_steps[neuron_i][0] = products[neuron_i][0] + products[neuron_i][1];
      for (input_i = 0; input_i < N_INPUTS - 2; input_i = input_i + 1) begin : g_input_loop
        assign sum_steps[neuron_i][input_i+1] = sum_steps[neuron_i][input_i] +
                                                products[neuron_i][input_i+2];
      end
      assign logits_o[neuron_i] = sum_steps[neuron_i][N_INPUTS-2];
    end
  endgenerate

endmodule
