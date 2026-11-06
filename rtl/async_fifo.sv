
module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4,
    parameter PTR_WIDTH  = ADDR_WIDTH + 1
)(
    input  logic                  wr_clk,
    input  logic                  rd_clk,
    input  logic                  rst_n,

    input  logic                  wr_en,
    input  logic                  rd_en,

    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out,

    output logic                  full,
    output logic                  empty
);

    logic [ADDR_WIDTH-1:0] wr_addr;
    logic [ADDR_WIDTH-1:0] rd_addr;

    logic [PTR_WIDTH-1:0] wr_gray;
    logic [PTR_WIDTH-1:0] rd_gray;

    logic [PTR_WIDTH-1:0] wr_gray_sync;
    logic [PTR_WIDTH-1:0] rd_gray_sync;

    // Write pointer
    write_pointer #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .PTR_WIDTH(PTR_WIDTH)
    ) u_write_pointer (
        .wr_clk(wr_clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_gray_sync(rd_gray_sync),
        .wr_addr(wr_addr),
        .wr_gray(wr_gray),
        .full(full)
    );

    // Read pointer
    read_pointer #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .PTR_WIDTH(PTR_WIDTH)
    ) u_read_pointer (
        .rd_clk(rd_clk),
        .rst_n(rst_n),
        .rd_en(rd_en),
        .wr_gray_sync(wr_gray_sync),
        .rd_addr(rd_addr),
        .rd_gray(rd_gray),
        .empty(empty)
    );

    // Synchronize write pointer into read domain
    synchronizer #(
        .WIDTH(PTR_WIDTH)
    ) u_wr_sync (
        .clk(rd_clk),
        .rst_n(rst_n),
        .async_in(wr_gray),
        .sync_out(wr_gray_sync)
    );

    // Synchronize read pointer into write domain
    synchronizer #(
        .WIDTH(PTR_WIDTH)
    ) u_rd_sync (
        .clk(wr_clk),
        .rst_n(rst_n),
        .async_in(rd_gray),
        .sync_out(rd_gray_sync)
    );

    // Dual-clock memory
    fifo_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_fifo_mem (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .wr_en(wr_en && !full),
        .rd_en(rd_en && !empty),
        .wr_addr(wr_addr),
        .rd_addr(rd_addr),
        .data_in(data_in),
        .data_out(data_out)
    );

endmodule
