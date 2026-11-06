
module fifo_mem #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    input  logic                  wr_clk,
    input  logic                  rd_clk,
    input  logic                  wr_en,
    input  logic                  rd_en,

    input  logic [ADDR_WIDTH-1:0] wr_addr,
    input  logic [ADDR_WIDTH-1:0] rd_addr,

    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out
);

    localparam DEPTH = (1 << ADDR_WIDTH);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Write operation
    always_ff @(posedge wr_clk) begin
        if (wr_en)
            mem[wr_addr] <= data_in;
    end

    // Synchronous read operation
    always_ff @(posedge rd_clk) begin
        if (rd_en)
            data_out <= mem[rd_addr];
    end

endmodule
