
module write_pointer #(
    parameter ADDR_WIDTH = 4,
    parameter PTR_WIDTH  = ADDR_WIDTH + 1
)(
    input  logic                 wr_clk,
    input  logic                 rst_n,
    input  logic                 wr_en,
    input  logic [PTR_WIDTH-1:0] rd_gray_sync,

    output logic [ADDR_WIDTH-1:0] wr_addr,
    output logic [PTR_WIDTH-1:0]  wr_gray,
    output logic                  full
);

    logic [PTR_WIDTH-1:0] wr_bin;
    logic [PTR_WIDTH-1:0] wr_bin_next;
    logic [PTR_WIDTH-1:0] wr_gray_next;

    logic full_next;
    logic wr_accept;

    assign wr_accept = wr_en && !full;

    // Next binary pointer
    assign wr_bin_next = wr_bin + wr_accept;

    // Binary to Gray conversion
    assign wr_gray_next =
        (wr_bin_next >> 1) ^ wr_bin_next;

    // Full detection:
    // Invert the two most significant bits
    // of the synchronized read Gray pointer.
    assign full_next =
        (wr_gray_next ==
         {~rd_gray_sync[PTR_WIDTH-1:PTR_WIDTH-2],
           rd_gray_sync[PTR_WIDTH-3:0]});

    always_ff @(posedge wr_clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_bin  <= '0;
            wr_gray <= '0;
            full    <= 1'b0;
        end
        else begin
            wr_bin  <= wr_bin_next;
            wr_gray <= wr_gray_next;
            full    <= full_next;
        end
    end

    assign wr_addr = wr_bin[ADDR_WIDTH-1:0];

endmodule
