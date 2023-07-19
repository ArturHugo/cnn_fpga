// verilog_lint: waive-start explicit-parameter-storage-type
// Kernel multiplication and accumulation with feature map window
module spatial_conv_kernel #(
    // Parameter Declarations
    // Default parameters: Q8.8, 3x3 kernel
    parameter DATA_WIDTH  = 16,
    parameter FRAC_WIDTH  = 8,
    parameter KERNEL_SIZE = 3
) (
    // Input Ports
    input signed [DATA_WIDTH-1:0] window[KERNEL_SIZE*KERNEL_SIZE],
    input signed [DATA_WIDTH-1:0] kernel[KERNEL_SIZE*KERNEL_SIZE],

    // Output Ports
    output signed [DATA_WIDTH-1:0] result,
    output logic overflow
);

  logic overflows[KERNEL_SIZE*KERNEL_SIZE];

  wire signed [DATA_WIDTH-1:0] products[KERNEL_SIZE*KERNEL_SIZE];

  wire signed [DATA_WIDTH-1:0] sum_steps[KERNEL_SIZE*KERNEL_SIZE-1];

  genvar i, j;

  generate
    for (i = 0; i < KERNEL_SIZE; i = i + 1) begin : g_row_loop
      for (j = 0; j < KERNEL_SIZE; j = j + 1) begin : g_col_loop
        fixed_mult #(
            .DATA_WIDTH(DATA_WIDTH),
            .FRAC_WIDTH(FRAC_WIDTH)
        ) m0 (
            .in1     (window[KERNEL_SIZE*i+j]),
            .in2     (kernel[KERNEL_SIZE*i+j]),
            .result  (products[KERNEL_SIZE*i+j]),
            .overflow(overflows[KERNEL_SIZE*i+j])
        );
      end
    end
  endgenerate

  generate
    assign sum_steps[0] = products[0] + products[1];
    for (i = 0; i < KERNEL_SIZE * KERNEL_SIZE - 2; i = i + 1) begin : g_acc_loop
      assign sum_steps[i+1] = sum_steps[i] + products[i+2];
    end
  endgenerate

  assign result   = sum_steps[KERNEL_SIZE*KERNEL_SIZE-2];

  assign overflow = overflows.or();

endmodule
