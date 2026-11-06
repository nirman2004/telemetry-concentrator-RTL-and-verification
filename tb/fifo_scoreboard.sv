
`timescale 1ns / 1ps

module fifo_scoreboard #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 16
)(
    input logic wr_clk,
    input logic rd_clk,
    input logic rst_n,

    input logic write_valid,
    input logic [DATA_WIDTH-1:0] write_data,

    input logic read_valid,
    input logic [DATA_WIDTH-1:0] read_data
);

    logic [DATA_WIDTH-1:0] expected_queue[$];

    integer write_count = 0;
    integer read_count = 0;
    integer match_count = 0;
    integer mismatch_count = 0;

    // Record every accepted FIFO write
    always @(posedge wr_clk or negedge rst_n) begin
        if (!rst_n) begin
            expected_queue.delete();
            write_count = 0;
        end
        else if (write_valid) begin
            if (expected_queue.size() >= FIFO_DEPTH) begin
                $error("[SB_ERROR] Reference queue overflow!");
                mismatch_count++;
            end
            else begin
                expected_queue.push_back(write_data);
                write_count++;

                $display("[SB_WRITE] Data=%0h Queue_size=%0d",
                         write_data, expected_queue.size());
            end
        end
    end

    // Compare every accepted FIFO read
    always @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n) begin
            read_count = 0;
            match_count = 0;
            mismatch_count = 0;
        end
        else if (read_valid) begin
            if (expected_queue.size() == 0) begin
                $error("[SB_ERROR] Unexpected FIFO read!");
                mismatch_count++;
            end
            else begin
                if (read_data === expected_queue[0]) begin
                    $display("[SB_MATCH] Expected=%0h Actual=%0h",
                             expected_queue[0], read_data);
                    match_count++;
                end
                else begin
                    $error("[SB_MISMATCH] Expected=%0h Actual=%0h",
                           expected_queue[0], read_data);
                    mismatch_count++;
                end

                expected_queue.pop_front();
                read_count++;
            end
        end
    end

    // Final report
    final begin
        $display("\n========== SCOREBOARD REPORT ==========");
        $display("Accepted writes : %0d", write_count);
        $display("Accepted reads  : %0d", read_count);
        $display("Matches         : %0d", match_count);
        $display("Mismatches      : %0d", mismatch_count);
        $display("Pending entries : %0d", expected_queue.size());

        if (mismatch_count == 0 &&
            expected_queue.size() == 0 &&
            write_count == read_count &&
            match_count == read_count)
            $display("[SB_SUCCESS] SCOREBOARD PASSED");
        else
            $display("[SB_FAILURE] SCOREBOARD FAILED");

        $display("=======================================\n");
    end

endmodule
