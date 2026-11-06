
module fifo_write_monitor #(
    parameter int DATA_WIDTH = 8
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    input  logic                  full,

    output logic                  write_valid,
    output logic [DATA_WIDTH-1:0] write_data
);

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            write_valid <= 1'b0;
            write_data  <= '0;
        end
        else begin
            write_valid <= 1'b0;

            if (wr_en && !full) begin
                write_valid <= 1'b1;
                write_data  <= wr_data;
            end
        end
    end

endmodule
