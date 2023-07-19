// verilog_lint: waive-start explicit-parameter-storage-type
// Winograd input data transformation for F(2x2, 3x3)
module winograd_4x4_data_transformation #(
    // Parameter Declarations
    // Default parameters: Q8.8
    parameter DATA_WIDTH = 16,
    parameter FRAC_WIDTH = 8
) (
    // Input Ports
    input signed [DATA_WIDTH-1:0] data[4*4],

    // Output Ports
    output signed [DATA_WIDTH-1:0] result[4*4]
);

  wire signed [DATA_WIDTH-1:0] temp[4*4];

  // First row of intermediate matrix
  assign temp[0] = data[0] - data[8];
  assign temp[1] = data[1] - data[9];
  assign temp[2] = data[2] - data[10];
  assign temp[3] = data[3] - data[11];

  // Second row of intermediate matrix
  assign temp[4] = data[4] + data[8];
  assign temp[5] = data[5] + data[9];
  assign temp[6] = data[6] + data[10];
  assign temp[7] = data[7] + data[11];

  // Third row of intermediate matrix
  assign temp[8] = -data[4] + data[8];
  assign temp[9] = -data[5] + data[9];
  assign temp[10] = -data[6] + data[10];
  assign temp[11] = -data[7] + data[11];

  // Fourth row of intermediate matrix
  assign temp[12] = data[4] - data[12];
  assign temp[13] = data[5] - data[13];
  assign temp[14] = data[6] - data[14];
  assign temp[15] = data[7] - data[15];

  // First row of result matrix
  assign result[0] = temp[0] - temp[2];
  assign result[1] = temp[1] + temp[2];
  assign result[2] = -temp[1] + temp[2];
  assign result[3] = temp[1] - temp[3];

  // Second row of result matrix
  assign result[4] = temp[4] - temp[6];
  assign result[5] = temp[5] + temp[6];
  assign result[6] = -temp[5] + temp[6];
  assign result[7] = temp[5] - temp[7];

  // Third row of result matrix
  assign result[8] = temp[8] - temp[10];
  assign result[9] = temp[9] + temp[10];
  assign result[10] = -temp[9] + temp[10];
  assign result[11] = temp[9] - temp[11];

  // Fourth row of result matrix
  assign result[12] = temp[12] - temp[14];
  assign result[13] = temp[13] + temp[14];
  assign result[14] = -temp[13] + temp[14];
  assign result[15] = temp[13] - temp[15];

endmodule
