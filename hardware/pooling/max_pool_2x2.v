module max_pool_2x2 #(
    parameter DATA_WIDTH = 32
)(
    input  wire signed [DATA_WIDTH-1:0] data_i [0:3],
    output wire signed [DATA_WIDTH-1:0] result_o
);
    reg signed [DATA_WIDTH-1:0] result_reg;
    
    always @(*) begin
        if(data_i[0] >= data_i[1] &&
           data_i[0] >= data_i[2] &&
           data_i[0] >= data_i[3])

            result_reg <= data_i[0];

        else if(data_i[1] >= data_i[0] &&
                data_i[1] >= data_i[2] &&
                data_i[1] >= data_i[3])

            result_reg <= data_i[1];

        else if(data_i[2] >= data_i[0] &&
                data_i[2] >= data_i[1] &&
                data_i[2] >= data_i[3])

            result_reg <= data_i[2];

        else if(data_i[3] >= data_i[0] &&
                data_i[3] >= data_i[1] &&
                data_i[3] >= data_i[2])

            result_reg <= data_i[3];

        else result_reg <= 32'hABAB;
    end

    assign result_o = result_reg;

endmodule