module fifo_coverage #(
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
    input logic [PTR_WIDTH-1:0] rd_bin
);

    // Transaction counters
    integer accepted_writes = 0;
    integer accepted_reads  = 0;

    // Boundary-condition counters
    integer blocked_writes = 0;
    integer blocked_reads  = 0;

    // Reset counter
    integer reset_events = 0;

    // Functional coverage hit flags
    bit write_seen       = 0;
    bit read_seen        = 0;
    bit full_seen        = 0;
    bit empty_seen       = 0;
    bit blocked_wr_seen  = 0;
    bit blocked_rd_seen  = 0;
    bit wr_wrap_seen     = 0;
    bit rd_wrap_seen     = 0;
    bit reset_seen       = 0;

    // ------------------------------------------------
    // WRITE-DOMAIN COVERAGE
    // ------------------------------------------------
    always @(posedge wr_clk) begin
        if (rst_n === 1'b1) begin

            if (wr_en && !full) begin
                accepted_writes = accepted_writes + 1;
                write_seen = 1;

                // Pointer is at its final address before
                // an accepted write causes address wrap.
                if (wr_bin[ADDR_WIDTH-1:0] ==
                    {ADDR_WIDTH{1'b1}})
                    wr_wrap_seen = 1;
            end

            if (wr_en && full) begin
                blocked_writes = blocked_writes + 1;
                blocked_wr_seen = 1;
            end

            if (full)
                full_seen = 1;
        end
    end

    // ------------------------------------------------
    // READ-DOMAIN COVERAGE
    // ------------------------------------------------
    always @(posedge rd_clk) begin
        if (rst_n === 1'b1) begin

            if (rd_en && !empty) begin
                accepted_reads = accepted_reads + 1;
                read_seen = 1;

                // Pointer is at its final address before
                // an accepted read causes address wrap.
                if (rd_bin[ADDR_WIDTH-1:0] ==
                    {ADDR_WIDTH{1'b1}})
                    rd_wrap_seen = 1;
            end

            if (rd_en && empty) begin
                blocked_reads = blocked_reads + 1;
                blocked_rd_seen = 1;
            end

            if (empty)
                empty_seen = 1;
        end
    end

    // ------------------------------------------------
    // RESET COVERAGE
    // ------------------------------------------------
    always @(negedge rst_n) begin
        reset_events = reset_events + 1;
        reset_seen = 1;
    end

    // ------------------------------------------------
    // COVERAGE REPORT
    // ------------------------------------------------
    task automatic report_coverage;

        integer hit_bins;
        integer total_bins;

        begin
            hit_bins = 0;
            total_bins = 9;

            if (write_seen)      hit_bins++;
            if (read_seen)       hit_bins++;
            if (full_seen)       hit_bins++;
            if (empty_seen)      hit_bins++;
            if (blocked_wr_seen) hit_bins++;
            if (blocked_rd_seen) hit_bins++;
            if (wr_wrap_seen)    hit_bins++;
            if (rd_wrap_seen)    hit_bins++;
            if (reset_seen)      hit_bins++;

            $display("");
            $display("==========================================");
            $display("       ASYNC FIFO FUNCTIONAL COVERAGE");
            $display("==========================================");

            $display("Accepted writes       : %0d", accepted_writes);
            $display("Accepted reads        : %0d", accepted_reads);
            $display("Blocked write attempts: %0d", blocked_writes);
            $display("Blocked read attempts : %0d", blocked_reads);
            $display("Reset events          : %0d", reset_events);

            $display("------------------------------------------");
            $display("Write operation       : %s",
                     write_seen ? "HIT" : "MISS");
            $display("Read operation        : %s",
                     read_seen ? "HIT" : "MISS");
            $display("FIFO full             : %s",
                     full_seen ? "HIT" : "MISS");
            $display("FIFO empty            : %s",
                     empty_seen ? "HIT" : "MISS");
            $display("Write blocked at full : %s",
                     blocked_wr_seen ? "HIT" : "MISS");
            $display("Read blocked at empty : %s",
                     blocked_rd_seen ? "HIT" : "MISS");
            $display("Write pointer wrap    : %s",
                     wr_wrap_seen ? "HIT" : "MISS");
            $display("Read pointer wrap     : %s",
                     rd_wrap_seen ? "HIT" : "MISS");
            $display("Reset observed        : %s",
                     reset_seen ? "HIT" : "MISS");

            $display("------------------------------------------");

            $display("Tracked-bin hit rate  : %0d / %0d (%0.2f%%)",
                     hit_bins, total_bins,
                     (100.0 * hit_bins) / total_bins);

            $display("==========================================");
        end
    endtask

endmodule