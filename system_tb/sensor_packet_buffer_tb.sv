
`timescale 1ns/1ps

module sensor_packet_buffer_tb;

    parameter PACKET_WIDTH = 44;
    parameter ADDR_WIDTH   = 4;
    parameter DEPTH        = (1 << ADDR_WIDTH);

    logic wr_clk = 0;
    logic rd_clk = 0;
    logic rst_n  = 0;

    logic in_valid;
    logic in_ready;
    logic [PACKET_WIDTH-1:0] packet_in;

    logic out_valid;
    logic out_ready;
    logic [PACKET_WIDTH-1:0] packet_out;

    logic full;
    logic empty;

    integer sent_count     = 0;
    integer received_count = 0;
    integer error_count    = 0;

    logic [PACKET_WIDTH-1:0] expected_queue[$];

    // Independent clocks
    always #5 wr_clk = ~wr_clk;

    initial begin
        #1;
        forever #7 rd_clk = ~rd_clk;
    end

    // DUT
    sensor_packet_buffer #(
        .PACKET_WIDTH(PACKET_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .rst_n(rst_n),

        .in_valid(in_valid),
        .in_ready(in_ready),
        .packet_in(packet_in),

        .out_valid(out_valid),
        .out_ready(out_ready),
        .packet_out(packet_out),

        .full(full),
        .empty(empty)
    );

    // ------------------------------------------------
    // WRITE HANDSHAKE MONITOR
    // ------------------------------------------------

    always @(posedge wr_clk) begin
        if (rst_n && in_valid && in_ready) begin

            expected_queue.push_back(packet_in);
            sent_count++;

            $display(
                "[WRITE] Accepted packet: %h",
                packet_in
            );

        end
    end

    // ------------------------------------------------
    // READ HANDSHAKE MONITOR / SCOREBOARD
    // ------------------------------------------------

    always @(posedge rd_clk) begin
        if (rst_n && out_valid && out_ready) begin

            received_count++;

            if (expected_queue.size() == 0) begin

                $error(
                    "[SB_ERROR] Unexpected packet: %h",
                    packet_out
                );

                error_count++;

            end
            else begin

                if (packet_out !== expected_queue[0]) begin

                    $error(
                        "[SB_MISMATCH] Expected=%h Actual=%h",
                        expected_queue[0],
                        packet_out
                    );

                    error_count++;

                end
                else begin

                    $display(
                        "[SB_MATCH] Expected=%h Actual=%h",
                        expected_queue[0],
                        packet_out
                    );

                end

                expected_queue.pop_front();

            end
        end
    end

    // ------------------------------------------------
    // PACKET WRITE TASK
    // ------------------------------------------------

    task automatic send_packet(
        input logic [PACKET_WIDTH-1:0] packet
    );

        begin

            @(negedge wr_clk);

            packet_in = packet;
            in_valid  = 1'b1;

            // Wait for actual acceptance
            do begin
                @(posedge wr_clk);
            end while (in_ready !== 1'b1);

            @(negedge wr_clk);

            in_valid  = 1'b0;
            packet_in = '0;

        end

    endtask

    // ------------------------------------------------
    // WAIT FOR ALL EXPECTED PACKETS TO BE RECEIVED
    // ------------------------------------------------

    task automatic wait_for_drain;

        integer timeout_count;

        begin

            timeout_count = 0;

            while ((expected_queue.size() != 0) &&
                   (timeout_count < 200)) begin

                @(negedge rd_clk);
                timeout_count++;

            end

            if (expected_queue.size() != 0) begin

                $error(
                    "[TIMEOUT] Packets still pending: %0d",
                    expected_queue.size()
                );

                error_count++;

            end

        end

    endtask

    // ------------------------------------------------
    // TEST SEQUENCE
    // ------------------------------------------------

    initial begin

        in_valid  = 0;
        packet_in = 0;
        out_ready = 0;

        $display("\n======================================");
        $display(" SENSOR PACKET BUFFER STRESS TEST");
        $display("======================================");

        // RESET
        repeat (5) @(negedge wr_clk);
        rst_n = 1'b1;

        repeat (5) @(negedge wr_clk);

        // ============================================
        // TEST 1: BASIC PACKET TRANSFER
        // ============================================

        $display("\n[TEST 1] Basic packet transfer");

        out_ready = 1'b1;

        for (int i = 0; i < 10; i++) begin

            send_packet({
                2'b00,
                2'b00,
                i[7:0],
                (32'hA5000000 + i)
            });

        end

        wait_for_drain();

        // ============================================
        // TEST 2: OUTPUT BACKPRESSURE
        // ============================================

        $display("\n[TEST 2] Output backpressure");

        out_ready = 1'b0;

        for (int i = 10; i < 15; i++) begin

            send_packet({
                2'b01,
                2'b00,
                i[7:0],
                (32'hB6000000 + i)
            });

        end

        // Wait for first output packet
        wait (out_valid === 1'b1);

        begin

            logic [PACKET_WIDTH-1:0] held_packet;

            held_packet = packet_out;

            // Hold receiver stalled
            repeat (5) begin

                @(negedge rd_clk);

                if (out_valid !== 1'b1) begin
                    $error("[BACKPRESSURE] out_valid dropped!");
                    error_count++;
                end

                if (packet_out !== held_packet) begin
                    $error("[BACKPRESSURE] Output data changed!");
                    error_count++;
                end

            end

        end

        $display("[PASS] Output remained stable during stall");

        out_ready = 1'b1;

        wait_for_drain();
// ============================================
// PREPARE TEST 3: CLEAN RESET
// ============================================

repeat (5) @(negedge rd_clk);

$display("[INFO] Resetting packet buffer before full test");

rst_n = 1'b0;
out_ready = 1'b0;
in_valid = 1'b0;
packet_in = '0;

repeat (4) @(negedge wr_clk);

rst_n = 1'b1;

repeat (5) @(posedge wr_clk);
repeat (5) @(posedge rd_clk);

if (empty !== 1'b1 || full !== 1'b0) begin
    $error("[RESET] FIFO did not return to empty state");
    error_count++;
end
else begin
    $display("[PASS] FIFO reset and empty state confirmed");
end
        // ============================================
        // TEST 3: FIFO FULL AND BLOCKED WRITE
        // ============================================
// Ensure the previous test has completely drained



$display("[INFO] Packet buffer drained before full test");
        $display("\n[TEST 3] FIFO full and blocked write");

        out_ready = 1'b0;

        for (int i = 0; i <= DEPTH; i++) begin

    send_packet({
        2'b10,
        2'b00,
        i[7:0],
        (32'hC7000000 + i)
    });

end

        // Allow full flag to settle
        @(negedge wr_clk);
$display("\n========== FIFO FULL DEBUG ==========");

$display("Write binary pointer : %0d",
    dut.u_packet_fifo.u_write_pointer.wr_bin);

$display("Write Gray pointer   : %b",
    dut.u_packet_fifo.u_write_pointer.wr_gray);

$display("Read Gray sync       : %b",
    dut.u_packet_fifo.rd_gray_sync);

$display("Full next            : %b",
    dut.u_packet_fifo.u_write_pointer.full_next);

$display("Full flag            : %b", full);

$display("Input ready          : %b", in_ready);

$display("=====================================\n");
        if (full !== 1'b1) begin

            $error("[FULL] FIFO did not assert full");
            error_count++;

        end
        else begin

            $display("[PASS] FIFO reached FULL");

        end

        // Attempt one additional write
        @(negedge wr_clk);

        in_valid = 1'b1;

        packet_in = {
            2'b10,
            2'b01,
            8'hFF,
            32'hDEADBEEF
        };

        @(posedge wr_clk);

        if (in_ready !== 1'b0) begin

            $error("[FULL] FIFO accepted write while full");
            error_count++;

        end
        else begin

            $display("[PASS] Additional write blocked");
            
        end

        @(negedge wr_clk);

        in_valid  = 1'b0;
        packet_in = '0;

        // Drain FIFO
        out_ready = 1'b1;

        wait_for_drain();

        // ============================================
        // TEST 4: FIFO EMPTY
        // ============================================

        $display("\n[TEST 4] FIFO empty behaviour");

        repeat (5) @(negedge rd_clk);

        if (empty !== 1'b1) begin

            $error("[EMPTY] FIFO did not assert empty");
            error_count++;

        end
        else begin

            $display("[PASS] FIFO reached EMPTY");

        end

        // The wrapper reads automatically.
        // Verify that no output becomes valid.
        repeat (5) begin

            @(negedge rd_clk);

            if (out_valid !== 1'b0) begin

                $error("[EMPTY] Unexpected output while empty");
                error_count++;

            end

        end

        // ============================================
        // TEST 5: RESET AND RECOVERY
        // ============================================

        $display("\n[TEST 5] Reset and recovery");

        @(negedge wr_clk);
        rst_n = 1'b0;

        repeat (4) @(negedge wr_clk);

        rst_n = 1'b1;

        repeat (5) @(negedge wr_clk);

        if (out_valid !== 1'b0) begin

            $error("[RESET] Output valid after reset");
            error_count++;

        end

        // Send fresh packets after reset
        out_ready = 1'b1;

        for (int i = 0; i < 4; i++) begin

            send_packet({
                2'b11,
                2'b00,
                i[7:0],
                (32'hD8000000 + i)
            });

        end

        wait_for_drain();
        
        // ============================================
// TEST 6: OVERFLOW BLOCKING AND RECOVERY
// ============================================

$display("\n[TEST 6] Overflow blocking and recovery");

// Start from a clean state.
rst_n = 1'b0;
out_ready = 1'b0;
in_valid = 1'b0;
packet_in = '0;

repeat (4) @(negedge wr_clk);

rst_n = 1'b1;

repeat (5) @(negedge wr_clk);
repeat (5) @(negedge rd_clk);

// Fill the packet buffer.
$display("[INFO] Filling packet buffer");

for (int i = 0; i <= DEPTH; i++) begin

    send_packet({
        2'b10,
        2'b00,
        i[7:0],
        (32'hE9000000 + i)
    });

end

@(negedge wr_clk);

if (full !== 1'b1) begin
    $error("[OVERFLOW] FIFO did not become full");
    error_count++;
end
else begin
    $display("[PASS] FIFO reached full state");
end

// Present one additional packet while full.
@(negedge wr_clk);

packet_in = {
    2'b10,
    2'b01,
    8'hFE,
    32'hFEED1234
};

in_valid = 1'b1;

@(posedge wr_clk);

if (in_ready !== 1'b0) begin
    $error("[OVERFLOW] Additional write was not blocked");
    error_count++;
end
else begin
    $display("[PASS] Overflow write blocked correctly");
end

// Start draining the buffer.
$display("[INFO] Releasing backpressure");

@(negedge wr_clk);
out_ready = 1'b1;

// Keep valid asserted until the blocked packet is accepted.
do begin
    @(posedge wr_clk);
end while (in_ready !== 1'b1);

// Complete the write transaction.
@(negedge wr_clk);

in_valid = 1'b0;
packet_in = '0;

$display("[PASS] Previously blocked packet accepted after space became available");

// Drain all remaining packets.
wait_for_drain();

if (error_count == 0)
    $display("[TEST 6 PASS] Overflow blocking and recovery verified");
else
    $display("[TEST 6 CHECK] Errors detected: %0d", error_count);

        // ============================================
        // FINAL REPORT
        // ============================================

        repeat (5) @(negedge rd_clk);

        $display("\n======================================");
        $display(" SENSOR PACKET BUFFER TEST REPORT");
        $display("======================================");

        $display("Packets accepted : %0d", sent_count);
        $display("Packets received : %0d", received_count);
        $display("Packets pending  : %0d", expected_queue.size());
        $display("Errors           : %0d", error_count);

        if ((error_count == 0) &&
            (sent_count == received_count) &&
            (expected_queue.size() == 0)) begin

            $display("\n[FINAL RESULT] ALL TESTS PASSED");

        end
        else begin

            $display("\n[FINAL RESULT] TEST FAILED");

        end

        $display("======================================");

        $finish;

    end

    // Simulation timeout
    initial begin

        #20000;

        $fatal(1, "[FATAL] Simulation timeout");

    end

endmodule
