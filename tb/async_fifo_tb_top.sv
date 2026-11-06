
module async_fifo_tb_top;

    logic wr_clk;
    logic rd_clk;

    // Write clock: 10 ns period
    initial begin
        wr_clk = 0;
        forever #5 wr_clk = ~wr_clk;
    end

    // Read clock: 14 ns period
    initial begin
        rd_clk = 0;
        #1;
        forever #7 rd_clk = ~rd_clk;
    end

    async_fifo_tb #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(4)
    ) tb (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk)
    );

endmodule
