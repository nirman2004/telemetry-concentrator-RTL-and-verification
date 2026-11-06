
module fifo_read_monitor #(
    parameter int DATA_WIDTH = 8
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  rd_en,
    input  logic [DATA_WIDTH-1:0] data_out,
    input  logic                  empty,

    output logic                  read_valid,
    output logic [DATA_WIDTH-1:0] read_data
);

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            read_valid <= 1'b0;
            read_data  <= '0;
        end
        else begin
            read_valid <= 1'b0;

            if (rd_en && !empty) begin
                // Allow registered memory output to update
                #1;

                read_data  <= data_out;
                read_valid <= 1'b1;
            end
        end
    end

endmodule
