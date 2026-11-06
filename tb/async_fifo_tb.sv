
module async_fifo_tb #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4,
    parameter DEPTH = (1 << ADDR_WIDTH)
)(
    input logic wr_clk,
    input logic rd_clk
);

    logic rst_n;

    // Driver-controlled DUT inputs
    wire wr_en;
    wire rd_en;
    wire [DATA_WIDTH-1:0] data_in;

    logic [DATA_WIDTH-1:0] data_out;
    logic full, empty;

    // Monitor transaction signals
    logic write_valid;
    logic [DATA_WIDTH-1:0] write_data;

    logic read_valid;
    logic [DATA_WIDTH-1:0] read_data;

    integer total_writes = 200;
    integer total_reads  = 200;
    integer regression_errors = 0;
    
    
    
    // =================================================
// FUNCTIONAL COVERAGE
// =================================================

fifo_coverage #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .PTR_WIDTH(ADDR_WIDTH + 1)
) fifo_coverage_inst (
    .wr_clk(wr_clk),
    .rd_clk(rd_clk),
    .rst_n(rst_n),

    .wr_en(wr_en),
    .rd_en(rd_en),
    .full(full),
    .empty(empty),

    .wr_bin(dut.u_write_pointer.wr_bin),
    .rd_bin(dut.u_read_pointer.rd_bin)
);

    // =================================================
    // WRITE DRIVER
    // =================================================

    fifo_write_driver #(
        .DATA_WIDTH(DATA_WIDTH)
    ) write_driver_inst (
        .clk(wr_clk),
        .rst_n(rst_n),
        .full(full),
        .wr_en(wr_en),
        .data_in(data_in)
    );

    // =================================================
    // READ DRIVER
    // =================================================

    fifo_read_driver #(
        .DATA_WIDTH(DATA_WIDTH)
    ) read_driver_inst (
        .clk(rd_clk),
        .rst_n(rst_n),
        .empty(empty),
        .rd_en(rd_en)
    );

    // =================================================
    // DUT
    // =================================================

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty)
    );

    // =================================================
    // SYSTEMVERILOG ASSERTIONS
    // =================================================

    async_fifo_sva #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .PTR_WIDTH(ADDR_WIDTH + 1)
    ) fifo_assertions (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .rst_n(rst_n),

        .wr_en(wr_en),
        .rd_en(rd_en),
        .full(full),
        .empty(empty),

        .wr_bin(dut.u_write_pointer.wr_bin),
        .wr_gray(dut.u_write_pointer.wr_gray),

        .rd_bin(dut.u_read_pointer.rd_bin),
        .rd_gray(dut.u_read_pointer.rd_gray)
    );

    // =================================================
    // WRITE MONITOR
    // =================================================

    fifo_write_monitor #(
        .DATA_WIDTH(DATA_WIDTH)
    ) write_mon (
        .clk(wr_clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_data(data_in),
        .full(full),
        .write_valid(write_valid),
        .write_data(write_data)
    );

    // =================================================
    // READ MONITOR
    // =================================================

    fifo_read_monitor #(
        .DATA_WIDTH(DATA_WIDTH)
    ) read_mon (
        .clk(rd_clk),
        .rst_n(rst_n),
        .rd_en(rd_en),
        .data_out(data_out),
        .empty(empty),
        .read_valid(read_valid),
        .read_data(read_data)
    );

    // =================================================
    // SCOREBOARD
    // =================================================

    fifo_scoreboard #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(DEPTH)
    ) scoreboard_inst (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .rst_n(rst_n),

        .write_valid(write_valid),
        .write_data(write_data),

        .read_valid(read_valid),
        .read_data(read_data)
    );

    // =================================================
    // RESET TASK
    // =================================================

    task automatic reset_fifo();

        rst_n = 1'b0;

        // Both drivers are expected to be idle
        repeat (5) @(negedge wr_clk);

        repeat (5) @(negedge rd_clk);

        rst_n = 1'b1;

        repeat (5) @(negedge wr_clk);
        repeat (5) @(negedge rd_clk);

        $display("[%0t] RESET COMPLETE", $time);

    endtask

    // =================================================
    // SCOREBOARD CHECK TASK
    // =================================================

    task automatic check_scoreboard(
        input integer expected_writes,
        input integer expected_reads,
        input string test_name
    );

        repeat (5) @(negedge rd_clk);
        repeat (2) @(negedge wr_clk);

        $display("\n========== %s SCOREBOARD CHECK ==========",
                 test_name);

        $display("Accepted writes : %0d",
                 scoreboard_inst.write_count);

        $display("Accepted reads  : %0d",
                 scoreboard_inst.read_count);

        $display("Matches         : %0d",
                 scoreboard_inst.match_count);

        $display("Mismatches      : %0d",
                 scoreboard_inst.mismatch_count);

        $display("Pending entries : %0d",
                 scoreboard_inst.expected_queue.size());

        if (scoreboard_inst.write_count == expected_writes &&
            scoreboard_inst.read_count == expected_reads &&
            scoreboard_inst.match_count == expected_reads &&
            scoreboard_inst.mismatch_count == 0 &&
            scoreboard_inst.expected_queue.size() == 0) begin

            $display("[REGRESSION PASS] %s", test_name);

        end
        else begin

            $display("[REGRESSION FAIL] %s", test_name);
            regression_errors++;

        end

    endtask

    // =================================================
    // RANDOMIZED WRITER
    // =================================================

    task automatic randomized_writer();

        integer count;
        integer delay_cycles;

        count = 0;

        $display("\n[RANDOM WRITER] Starting");

        while (count < total_writes) begin

            delay_cycles = $urandom_range(0, 3);

            if (delay_cycles > 0)
                write_driver_inst.idle_write(delay_cycles);

            write_driver_inst.drive_write(
                $urandom_range(0, 255)
            );

            count++;

        end

        $display("[RANDOM WRITER] Completed %0d writes",
                 count);

    endtask

    // =================================================
    // RANDOMIZED READER
    // =================================================

    task automatic randomized_reader();

        integer count;
        integer read_probability;

        count = 0;

        $display("\n[RANDOM READER] Starting");

        while (count < total_reads) begin

            read_probability = $urandom_range(0, 99);

            if (read_probability < 70) begin

                read_driver_inst.drive_read();
                count++;

            end
            else begin

                read_driver_inst.idle_read(1);

            end

        end

        $display("[RANDOM READER] Completed %0d reads",
                 count);

    endtask

    // =================================================
    // FIFO WRAP-AROUND TEST
    // =================================================

    task automatic fifo_wraparound_test();

        integer round_idx;
        integer i;

        logic [DATA_WIDTH-1:0] test_data;

        $display("\n========== FIFO WRAP-AROUND TEST ==========");

        for (round_idx = 0; round_idx < 3; round_idx++) begin

            // Fill FIFO
            $display("\n[ROUND %0d] Writing %0d entries",
                     round_idx + 1, DEPTH);

            for (i = 0; i < DEPTH; i++) begin

                test_data = 8'h10 + (round_idx * DEPTH) + i;

                write_driver_inst.drive_write(test_data);

                $display("[WRITE] Round=%0d Data=%0h",
                         round_idx + 1, test_data);

            end

            wait (full == 1'b1);

            $display("[PASS] Round %0d: FIFO full",
                     round_idx + 1);

            // Empty FIFO
            $display("[ROUND %0d] Reading %0d entries",
                     round_idx + 1, DEPTH);

            for (i = 0; i < DEPTH; i++) begin

                read_driver_inst.drive_read();

            end

            wait (empty == 1'b1);

            $display("[PASS] Round %0d: FIFO empty",
                     round_idx + 1);

            repeat (2) @(negedge rd_clk);
            repeat (2) @(negedge wr_clk);

        end

        $display("\n[PASS] FIFO pointer wrap-around test completed");

    endtask

    // =================================================
    // SIMULTANEOUS READ/WRITE TEST
    // =================================================

    task automatic simultaneous_rw_test();

        integer write_count;
        integer read_count;

        write_count = 0;
        read_count  = 0;

        $display("\n========== SIMULTANEOUS READ/WRITE TEST ==========");

        fork

            begin

                $display("[WRITER] Starting");

                while (write_count < 100) begin

                    write_driver_inst.drive_write(
                        $urandom_range(0, 255)
                    );

                    write_count++;

                end

                $display("[WRITER] Completed %0d writes",
                         write_count);

            end

            begin

                $display("[READER] Starting");

                while (read_count < 100) begin

                    read_driver_inst.drive_read();

                    read_count++;

                end

                $display("[READER] Completed %0d reads",
                         read_count);

            end

        join

        repeat (5) @(negedge rd_clk);
        repeat (2) @(negedge wr_clk);

        $display("\n========== SIMULTANEOUS TEST SUMMARY ==========");

        $display("Testbench writes : %0d", write_count);
        $display("Testbench reads  : %0d", read_count);

        $display("Scoreboard writes: %0d",
                 scoreboard_inst.write_count);

        $display("Scoreboard reads : %0d",
                 scoreboard_inst.read_count);

        $display("Matches          : %0d",
                 scoreboard_inst.match_count);

        $display("Mismatches       : %0d",
                 scoreboard_inst.mismatch_count);

        $display("Pending entries  : %0d",
                 scoreboard_inst.expected_queue.size());

        if (write_count == 100 &&
            read_count == 100 &&
            scoreboard_inst.write_count == 100 &&
            scoreboard_inst.read_count == 100 &&
            scoreboard_inst.match_count == 100 &&
            scoreboard_inst.mismatch_count == 0 &&
            scoreboard_inst.expected_queue.size() == 0)

            $display("[SUCCESS] SIMULTANEOUS READ/WRITE TEST PASSED");

        else begin

            $display("[FAILURE] SIMULTANEOUS READ/WRITE TEST FAILED");
            regression_errors++;

        end

    endtask

    // =================================================
    // RESET DURING OPERATION TEST
    // =================================================

    task automatic reset_during_operation_test();

        integer i;
        logic [DATA_WIDTH-1:0] test_data;

        $display("\n========== RESET DURING OPERATION TEST ==========");

        // Phase 1: Write 8 entries
        $display("\n[PHASE 1] Writing 8 entries before reset");

        for (i = 0; i < 8; i++) begin

            test_data = 8'hA0 + i;

            write_driver_inst.drive_write(test_data);

            $display("[PRE-RESET WRITE] Data=%0h", test_data);

        end

        repeat (2) @(negedge wr_clk);

        // Phase 2: Reset while FIFO contains data
        $display("\n[PHASE 2] Asserting reset while FIFO contains data");

        @(negedge wr_clk);

        rst_n = 1'b0;

        repeat (4) @(negedge wr_clk);
        repeat (4) @(negedge rd_clk);

        rst_n = 1'b1;

        repeat (4) @(negedge wr_clk);
        repeat (4) @(negedge rd_clk);

        if (full == 1'b0 && empty == 1'b1)
            $display("[PASS] FIFO flags reset correctly");
        else
            $error("[FAIL] Incorrect FIFO flags after reset");

        // Phase 3: Check empty-read protection
        $display("\n[PHASE 3] Checking empty FIFO protection");

        if (empty)
            $display("[PASS] FIFO is empty after reset");
        else
            $error("[FAIL] FIFO should be empty after reset");

        // Phase 4: Recovery
        $display("\n[PHASE 4] Testing FIFO recovery after reset");

        for (i = 0; i < 4; i++) begin

            test_data = 8'hD0 + i;

            write_driver_inst.drive_write(test_data);

            $display("[RECOVERY WRITE] Data=%0h", test_data);

        end

        for (i = 0; i < 4; i++) begin

            read_driver_inst.drive_read();

        end

        repeat (3) @(negedge rd_clk);

        if (empty)
            $display("[PASS] FIFO returned to empty after recovery");
        else
            $error("[FAIL] FIFO did not become empty after recovery");

        $display("\n========== RESET DURING OPERATION TEST COMPLETE ==========");

    endtask
    
   
task automatic fifo_boundary_coverage_test();

    integer i;
    logic [DATA_WIDTH-1:0] test_data;

    $display("\n========== FIFO BOUNDARY COVERAGE TEST ==========");

    // Fill FIFO
    for (i = 0; i < DEPTH; i++) begin
        test_data = i;
        write_driver_inst.drive_write(test_data);
    end

    wait (full == 1'b1);
    $display("[PASS] FIFO reached FULL");

    // Blocked write attempt
    write_driver_inst.attempt_write_while_full(8'hFF);

    // Drain FIFO
    for (i = 0; i < DEPTH; i++) begin
        read_driver_inst.drive_read();
    end

    wait (empty == 1'b1);
    $display("[PASS] FIFO reached EMPTY");

    // Blocked read attempt
    read_driver_inst.attempt_read_while_empty();

    repeat (5) @(negedge rd_clk);

    $display("========== BOUNDARY TEST COMPLETE ==========");

endtask


    // =================================================
    // MAIN REGRESSION
    // =================================================

    initial begin

        regression_errors = 0;

        $display("\n");
        $display("############################################");
        $display("# ASYNCHRONOUS FIFO VERIFICATION REGRESSION");
        $display("############################################");

        // TEST 1: Randomized traffic
        reset_fifo();

        $display("\n========== TEST 1: RANDOMIZED TRAFFIC ==========");

        fork
            randomized_writer();
            randomized_reader();
        join

        check_scoreboard(200, 200, "RANDOMIZED TRAFFIC");

        // TEST 2: Pointer wrap-around
        reset_fifo();

        $display("\n========== TEST 2: POINTER WRAP-AROUND ==========");

        fifo_wraparound_test();

        check_scoreboard(48, 48, "POINTER WRAP-AROUND");

        // TEST 3: Simultaneous read/write
        reset_fifo();

        $display("\n========== TEST 3: SIMULTANEOUS READ/WRITE ==========");

        simultaneous_rw_test();

        check_scoreboard(100, 100, "SIMULTANEOUS READ/WRITE");

        // TEST 4: Reset during operation
        reset_fifo();

        $display("\n========== TEST 4: RESET DURING OPERATION ==========");

        reset_during_operation_test();

        check_scoreboard(4, 4, "RESET RECOVERY");

        // Final regression summary
        $display("\n");
        $display("############################################");
        $display("# FINAL REGRESSION SUMMARY");
        $display("############################################");

        if (regression_errors == 0) begin

            $display("[REGRESSION SUCCESS]");
            $display("All four verification scenarios passed.");

        end
        else begin

            $display("[REGRESSION FAILURE]");
            $display("Failed scenarios: %0d", regression_errors);

        end

        $display("############################################");

        #100;
        fifo_boundary_coverage_test();

// Allow monitors and scoreboard to settle
    repeat (5) @(negedge rd_clk);
        // Print functional coverage report
    fifo_coverage_inst.report_coverage();

        $finish;

    end

endmodule
