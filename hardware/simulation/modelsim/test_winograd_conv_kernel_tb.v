// verilog_lint: waive-start explicit-parameter-storage-type
`timescale 1 ps / 1 ps
module test_winograd_conv_kernel_tb ();

  // verilog_lint: waive-start parameter-name-style
  localparam DATA_WIDTH = 32;
  localparam FRAC_WIDTH = 16;
  // verilog_lint: waive-stop parameter-name-style

  reg signed  [DATA_WIDTH-1:0] window[4*4] = '{default: 0};
  reg signed  [DATA_WIDTH-1:0] kernel[4*4] = '{default: 0};
  wire signed [DATA_WIDTH-1:0] result[2*2];

  winograd_4x4_conv_kernel #(
      .DATA_WIDTH(DATA_WIDTH),
      .FRAC_WIDTH(FRAC_WIDTH)
  ) WINOGRAD_4x4_CONV_KERNEL_0 (
      .window(window),
      .kernel(kernel),
      .result(result)
  );

  /**** Testbench ****/
  integer i;
  initial begin
    #10;
    window = '{
        0: 32'h0000_0202,
        1: 32'h0000_0101,
        2: 32'h0000_0000,
        3: 32'h0000_0000,

        4: 32'h0000_0000,
        5: 32'h0000_0000,
        6: 32'h0000_0101,
        7: 32'h0000_0000,

        8: 32'h0000_0303,
        9: 32'h0000_0202,
        10: 32'h0000_0101,
        11: 32'h0000_0000,

        12: 32'h0000_0000,
        13: 32'h0000_0000,
        14: 32'h0000_0000,
        15: 32'h0000_0000
    };

    kernel = '{
        0: 32'hffff_0000,
        1: 32'hfffe_8000,
        2: 32'hffff_8000,
        3: 32'hffff_0000,

        4: 32'h0000_0000,
        5: 32'h0000_0000,
        6: 32'h0000_0000,
        7: 32'h0000_0000,

        8: 32'hfffe_0000,
        9: 32'hfffd_0000,
        10: 32'hffff_0000,
        11: 32'hfffe_0000,

        12: 32'hffff_0000,
        13: 32'hfffe_8000,
        14: 32'hffff_8000,
        15: 32'hffff_0000
    };
    #10;
  end

  /*******************/
endmodule

