
module async_fifo_sva #(
    parameter ADDR_WIDTH = 4,
    parameter PTR_WIDTH  = ADDR_WIDTH + 1
)(
    input logic wr_clk,
    input logic rd_clk,
    input logic rst_n,

    input logic wr_en,
    input logic rd_en,
    input logic full,
    input logic empty,

    input logic [PTR_WIDTH-1:0] wr_bin,
    input logic [PTR_WIDTH-1:0] wr_gray,
    input logic [PTR_WIDTH-1:0] rd_bin,
    input logic [PTR_WIDTH-1:0] rd_gray
);

    logic wr_history_valid;
    logic rd_history_valid;

    // History-valid flags
    always_ff @(posedge wr_clk or negedge rst_n) begin
        if (!rst_n)
            wr_history_valid <= 1'b0;
        else
            wr_history_valid <= 1'b1;
    end

    always_ff @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n)
            rd_history_valid <= 1'b0;
        else
            rd_history_valid <= 1'b1;
    end

    // ================================================
    // WRITE POINTER ASSERTIONS
    // ================================================

    // 1. Binary pointer must increment only after
    //    an accepted write in the previous cycle.

    property p_write_pointer_update;
        @(posedge wr_clk)
        disable iff (!rst_n)
        wr_history_valid |->
            (wr_bin == (
                $past(wr_bin) +
                $past(wr_en && !full)
            ));
    endproperty

    assert property (p_write_pointer_update)
        else $error("[SVA ERROR] Incorrect write pointer update");

    // 2. Binary-to-Gray conversion

    property p_write_gray_encoding;
        @(posedge wr_clk)
        disable iff (!rst_n)
        wr_gray == ((wr_bin >> 1) ^ wr_bin);
    endproperty

    assert property (p_write_gray_encoding)
        else $error("[SVA ERROR] Write Gray encoding incorrect");

    // 3. Gray pointer changes by at most one bit

    property p_write_gray_one_bit;
        @(posedge wr_clk)
        disable iff (!rst_n)
        wr_history_valid |->
            $onehot0(wr_gray ^ $past(wr_gray));
    endproperty

    assert property (p_write_gray_one_bit)
        else $error("[SVA ERROR] Write Gray pointer changed multiple bits");


    // ================================================
    // READ POINTER ASSERTIONS
    // ================================================

    // 4. Binary pointer must increment only after
    //    an accepted read in the previous cycle.

    property p_read_pointer_update;
        @(posedge rd_clk)
        disable iff (!rst_n)
        rd_history_valid |->
            (rd_bin == (
                $past(rd_bin) +
                $past(rd_en && !empty)
            ));
    endproperty

    assert property (p_read_pointer_update)
        else $error("[SVA ERROR] Incorrect read pointer update");

    // 5. Binary-to-Gray conversion

    property p_read_gray_encoding;
        @(posedge rd_clk)
        disable iff (!rst_n)
        rd_gray == ((rd_bin >> 1) ^ rd_bin);
    endproperty

    assert property (p_read_gray_encoding)
        else $error("[SVA ERROR] Read Gray encoding incorrect");

    // 6. Gray pointer changes by at most one bit

    property p_read_gray_one_bit;
        @(posedge rd_clk)
        disable iff (!rst_n)
        rd_history_valid |->
            $onehot0(rd_gray ^ $past(rd_gray));
    endproperty

    assert property (p_read_gray_one_bit)
        else $error("[SVA ERROR] Read Gray pointer changed multiple bits");

endmodule
