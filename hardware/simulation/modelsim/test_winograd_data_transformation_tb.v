// verilog_lint: waive-start explicit-parameter-storage-type
`timescale 1 ps / 1 ps
module test_winograd_data_transformation_tb ();

  // verilog_lint: waive-start parameter-name-style
  localparam DATA_WIDTH = 32;
  localparam FRAC_WIDTH = 16;
  // verilog_lint: waive-stop parameter-name-style

  reg signed [DATA_WIDTH-1:0] data[4*4] = '{default: 0};
  wire signed [DATA_WIDTH-1:0] transformed[4*4];

  winograd_4x4_data_transformation #(
      .DATA_WIDTH(DATA_WIDTH),
      .FRAC_WIDTH(FRAC_WIDTH)
  ) WINOGRAD_4x4_DATA_TRANSFORMATION_0 (
      .data  (data),
      .result(transformed)
  );

  /**** Testbench ****/
  integer i;
  initial begin
    #10;
    data = '{
        0: 32'h0000_0101,
        1: 32'h0000_0000,
        2: 32'h0000_0000,
        3: 32'h0000_0000,
        4: 32'h0000_0000,
        5: 32'h0000_0202,
        6: 32'h0000_0202,
        7: 32'h0000_0000,
        8: 32'h0000_0202,
        9: 32'h0000_0000,
        10: 32'h0000_0000,
        11: 32'h0000_0202,
        12: 32'h0000_0000,
        13: 32'h0000_0000,
        14: 32'h0000_0202,
        15: 32'h0000_0101
    };
    #10;
  end

  /*******************/
endmodule

