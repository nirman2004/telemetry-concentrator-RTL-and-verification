
`timescale 1ns/1ps

module packet_scheduler_tb;
    bit test_done = 0;
    localparam PACKET_WIDTH = 44;

    logic clk;
    logic rst_n;

    logic [2:0] in_valid;
    logic [2:0] in_ready;

    logic [PACKET_WIDTH-1:0] vibration_packet;
    logic [PACKET_WIDTH-1:0] temperature_packet;
    logic [PACKET_WIDTH-1:0] emergency_packet;

    logic out_valid;
    logic out_ready;
    logic [PACKET_WIDTH-1:0] out_packet;

    integer error_count = 0;

    packet_scheduler #(
        .PACKET_WIDTH(PACKET_WIDTH),
        .MAX_EMERGENCY_BURST(2)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .in_valid(in_valid),

        .vibration_packet(vibration_packet),
        .temperature_packet(temperature_packet),
        .emergency_packet(emergency_packet),

        .in_ready(in_ready),

        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_packet(out_packet)
    );

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Reset task
    task automatic reset_dut;
        begin
            @(negedge clk);
            rst_n = 0;
            in_valid = 0;
            out_ready = 0;

            vibration_packet = '0;
            temperature_packet = '0;
            emergency_packet = '0;

            repeat (3) @(posedge clk);

            @(negedge clk);
            rst_n = 1;

            repeat (2) @(posedge clk);
        end
    endtask

    // Check and consume one expected packet.
    // clear_source=0 keeps the source valid for its next packet.
    task automatic consume_expected(
    input logic [PACKET_WIDTH-1:0] expected_packet,
    input string test_name,
    input logic clear_source
);
    logic [1:0] source_id;

    begin
        // Wait until the scheduler presents a packet.
        wait (out_valid === 1'b1);

        // Allow combinational outputs to settle.
        #1;

        if (out_packet !== expected_packet) begin
            $error("[%s] Packet mismatch. Expected=%h Actual=%h",
                   test_name, expected_packet, out_packet);
            error_count++;
        end
        else begin
            $display("[PASS] %s: packet=%h",
                     test_name, out_packet);
        end

        source_id = expected_packet[43:42];

        // Assert ready away from the active clock edge.
        @(negedge clk);
        out_ready = 1'b1;

        // IMPORTANT: allow in_ready to update before checking it.
        #1;

        if (in_ready[source_id] !== 1'b1) begin
            $error("[%s] Selected source was not ready. Source=%0d, in_ready=%b",
                   test_name, source_id, in_ready);
            error_count++;
        end

        // Complete the valid-ready handshake.
        @(posedge clk);
        #1;

        // Deassert ready and optionally remove the source packet.
        @(negedge clk);
        out_ready = 1'b0;

        if (clear_source)
            in_valid[source_id] = 1'b0;

        // Allow scheduler outputs to settle before the next test action.
        #1;
    end
endtask

    initial begin

        rst_n = 0;
        in_valid = 0;
        out_ready = 0;

        vibration_packet = '0;
        temperature_packet = '0;
        emergency_packet = '0;

        // =========================================
        // TEST 1: Emergency priority and burst limit
        // =========================================

        $display("\n[TEST 1] Emergency priority and burst limit");

        reset_dut();

        vibration_packet =
            {2'd0, 2'd0, 8'd1, 32'hAAAA0001};

        temperature_packet =
            {2'd1, 2'd0, 8'd1, 32'hBBBB0001};

        emergency_packet =
            {2'd2, 2'd0, 8'd1, 32'hCCCC0001};
        
        @(negedge clk);
        in_valid = 3'b111;

        // First emergency packet
        consume_expected(
            emergency_packet,
            "First emergency packet",
            1'b0
        );

        // Present the second emergency packet
        emergency_packet =
            {2'd2, 2'd0, 8'd2, 32'hCCCC0002};
            #1
        // Second emergency packet
        consume_expected(
            emergency_packet,
            "Second emergency packet",
            1'b1
        );

        // Normal traffic must now be served
        consume_expected(
            vibration_packet,
            "Vibration after emergency burst",
            1'b1
        );

        consume_expected(
            temperature_packet,
            "Temperature round-robin",
            1'b1
        );

        // =========================================
        // TEST 2: Normal-channel round-robin
        // =========================================

        $display("\n[TEST 2] Normal channel round-robin");

        reset_dut();

        vibration_packet =
            {2'd0, 2'd0, 8'd2, 32'hAAAA0002};

        temperature_packet =
            {2'd1, 2'd0, 8'd2, 32'hBBBB0002};

        @(negedge clk);
        in_valid = 3'b011;

        consume_expected(
            vibration_packet,
            "Round-robin vibration",
            1'b1
        );

        consume_expected(
            temperature_packet,
            "Round-robin temperature",
            1'b1
        );

        // =========================================
        // TEST 3: Output backpressure
        // =========================================

        $display("\n[TEST 3] Output backpressure");

        reset_dut();

        temperature_packet =
            {2'd1, 2'd0, 8'd3, 32'hBBBB0003};

        @(negedge clk);
        in_valid = 3'b010;
        out_ready = 0;

        wait (out_valid === 1'b1);

        begin
            logic [PACKET_WIDTH-1:0] held_packet;

            held_packet = out_packet;

            repeat (5) begin
                @(negedge clk);

                if (out_valid !== 1'b1) begin
                    $error("[BACKPRESSURE] out_valid dropped");
                    error_count++;
                end

                if (out_packet !== held_packet) begin
                    $error("[BACKPRESSURE] Packet changed during stall");
                    error_count++;
                end

                if (in_ready[1] !== 1'b0) begin
                    $error("[BACKPRESSURE] Source ready while stalled");
                    error_count++;
                end
            end

            $display("[PASS] Output packet stable during backpressure");
        end

        consume_expected(
            temperature_packet,
            "Backpressure release",
            1'b1
        );

        // =========================================
        // FINAL REPORT
        // =========================================

        repeat (2) @(posedge clk);

        $display("\n==================================");
        $display(" PACKET SCHEDULER TEST REPORT");
        $display("==================================");
        $display("Errors: %0d", error_count);

        if (error_count == 0)
            $display("[FINAL RESULT] ALL TESTS PASSED");
        else
            $display("[FINAL RESULT] TEST FAILED");

        $display("==================================");
    test_done = 1'b1;

        $finish;
    end

    // Simulation watchdog
initial begin
    fork
        begin
            wait (test_done == 1'b1);
            #1;
            $finish;
        end

        begin
            #10000;
            $fatal(1, "Simulation timeout: testbench did not complete");
        end
    join_any

    disable fork;
end
endmodule
