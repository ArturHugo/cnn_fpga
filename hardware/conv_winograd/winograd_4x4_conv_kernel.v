// verilog_lint: waive-start explicit-parameter-storage-type
// Winograd convolution step for F(2x2, 3x3)
// Input kernel must be already transformed
module winograd_4x4_conv_kernel #(
    // Parameter Declarations
    // Default parameters: Q8.8
    parameter DATA_WIDTH = 16,
    parameter FRAC_WIDTH = 8
) (
    // Input Ports
    input signed [DATA_WIDTH-1:0] window[4*4],
    input signed [DATA_WIDTH-1:0] kernel[4*4],

    // Output Ports
    output signed [DATA_WIDTH-1:0] result[2*2],
    output wire overflow
);

  wire signed [DATA_WIDTH-1:0] transformed[4*4];
  wire signed [DATA_WIDTH-1:0] product[4*4];
  wire signed [DATA_WIDTH-1:0] temp[2*4];

  wire [4*4-1:0] overflows;


  winograd_4x4_data_transformation #(
      .DATA_WIDTH(DATA_WIDTH),
      .FRAC_WIDTH(FRAC_WIDTH)
  ) WDT0 (
      .data  (window),
      .result(transformed)
  );

  genvar i, j;
  generate
    for (i = 0; i < 4; i = i + 1) begin : g_row_loop
      for (j = 0; j < 4; j = j + 1) begin : g_col_loop
        fixed_mult #(
            .DATA_WIDTH(DATA_WIDTH),
            .FRAC_WIDTH(FRAC_WIDTH)
        ) m0 (
            .in1     (transformed[4*i+j]),
            .in2     (kernel[4*i+j]),
            .result  (product[4*i+j]),
            .overflow(overflows[4*i+j])
        );
      end
    end
  endgenerate

  // First column of intermediate matrix
  assign temp[0]   = product[0] + product[4] + product[8];
  assign temp[4]   = product[4] - product[8] - product[12];

  // Second column of intermediate matrix
  assign temp[1]   = product[1] + product[5] + product[9];
  assign temp[5]   = product[5] - product[9] - product[13];

  // Third column of intermediate matrix
  assign temp[2]   = product[2] + product[6] + product[10];
  assign temp[6]   = product[6] - product[10] - product[14];

  // Fourth column of intermediate matrix
  assign temp[3]   = product[3] + product[7] + product[11];
  assign temp[7]   = product[7] - product[11] - product[15];

  // First row of result matrix
  assign result[0] = temp[0] + temp[1] + temp[2];
  assign result[1] = temp[1] - temp[2] - temp[3];

  // Second row of result matrix
  assign result[2] = temp[4] + temp[5] + temp[6];
  assign result[3] = temp[5] - temp[6] - temp[7];

  assign overflow  = |(overflows);

endmodule
