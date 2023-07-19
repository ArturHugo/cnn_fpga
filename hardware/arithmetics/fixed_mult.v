// verilog_lint: waive-start explicit-parameter-storage-type
module fixed_mult #(
    // Parameter Declarations
    // Default parameters: Q8.8
    parameter DATA_WIDTH = 16,
    parameter FRAC_WIDTH = 8
) (
    // Input Ports
    input signed [DATA_WIDTH-1:0] in1,
    input signed [DATA_WIDTH-1:0] in2,

    // Output Ports
    output logic signed [DATA_WIDTH-1:0] result,
    output logic overflow
);

  wire signed [2*DATA_WIDTH-1:0] intermediate = in1 * in2;
  wire rounding_bit = intermediate[FRAC_WIDTH-1];

  wire signed [2*DATA_WIDTH-1:0] upper_limit, lower_limit;
  assign upper_limit = $signed(
      {{(DATA_WIDTH + 1) {1'b0}}, {(DATA_WIDTH - 1) {1'b1}}} << (DATA_WIDTH / 2)
  );
  assign lower_limit = $signed(
      {{(DATA_WIDTH + 1) {1'b1}}, {(DATA_WIDTH - 1) {1'b0}}} << (DATA_WIDTH / 2)
  );

  assign overflow = (intermediate > upper_limit) | (intermediate < lower_limit);

  assign result = (intermediate >> FRAC_WIDTH) + rounding_bit;

endmodule
