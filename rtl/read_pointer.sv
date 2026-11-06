
module read_pointer #(
    parameter ADDR_WIDTH = 4,
    parameter PTR_WIDTH  = ADDR_WIDTH + 1
)(
    input  logic                 rd_clk,
    input  logic                 rst_n,
    input  logic                 rd_en,
    input  logic [PTR_WIDTH-1:0] wr_gray_sync,

    output logic [ADDR_WIDTH-1:0] rd_addr,
    output logic [PTR_WIDTH-1:0]  rd_gray,
    output logic                  empty
);

    logic [PTR_WIDTH-1:0] rd_bin;
    logic [PTR_WIDTH-1:0] rd_bin_next;
    logic [PTR_WIDTH-1:0] rd_gray_next;

    logic empty_next;
    logic rd_accept;

    assign rd_accept = rd_en && !empty;

    // Next binary pointer
    assign rd_bin_next = rd_bin + rd_accept;

    // Binary to Gray conversion
    assign rd_gray_next =
        (rd_bin_next >> 1) ^ rd_bin_next;

    // Empty detection
    assign empty_next = (rd_gray_next == wr_gray_sync);

    always_ff @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_bin  <= '0;
            rd_gray <= '0;
            empty   <= 1'b1;
        end
        else begin
            rd_bin  <= rd_bin_next;
            rd_gray <= rd_gray_next;
            empty   <= empty_next;
        end
    end

    assign rd_addr = rd_bin[ADDR_WIDTH-1:0];

endmodule
