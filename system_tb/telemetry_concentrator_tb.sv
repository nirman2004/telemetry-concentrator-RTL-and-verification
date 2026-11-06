
`timescale 1ns/1ps

module telemetry_concentrator_tb;

    localparam PACKET_WIDTH = 44;
    localparam ADDR_WIDTH   = 4;

    logic vibration_clk = 0;
    logic temperature_clk = 0;
    logic emergency_clk = 0;
    logic scheduler_clk = 0;

    logic rst_n = 0;

    logic vibration_valid = 0;
    logic temperature_valid = 0;
    logic emergency_valid = 0;

    logic vibration_ready;
    logic temperature_ready;
    logic emergency_ready;

    logic [43:0] vibration_packet;
    logic [43:0] temperature_packet;
    logic [43:0] emergency_packet;

    logic out_valid;
    logic out_ready = 0;
    logic [43:0] out_packet;

    logic [2:0] buffer_full;
    logic [2:0] buffer_empty;

    integer error_count = 0;
integer received_count = 0;
integer t3_normal_remaining = 0;
integer t3_emergency_streak = 0;
integer t3_output_count = 0;
integer t3_error_count = 0;

logic t3_active = 0;

integer sb_accepted_count;
integer sb_received_count;
integer sb_error_count;
integer sb_pending_count;

// Cumulative performance counters
integer total_vibration_accepted = 0;
integer total_temperature_accepted = 0;
integer total_emergency_accepted = 0;

integer total_vibration_received = 0;
integer total_temperature_received = 0;
integer total_emergency_received = 0;

integer output_stall_cycles = 0;
integer output_transfer_cycles = 0;

integer t4_output_count = 0;
integer t4_error_count = 0;

logic t4_active = 0;
logic t4_prev_valid = 0;
integer t4_vibration_count = 0;
integer t4_temperature_count = 0;
logic [1:0] t4_prev_channel = 0;
logic [43:0] received_packets[$];




// Test 6A: Temperature backpressure
logic t6a_active = 0;
integer t6a_error_count = 0;
integer t6a_wait_cycles = 0;
integer t6a_accepted_count = 0;
integer t6a_output_count = 0;

// Test 6B: Emergency backpressure
logic t6b_active = 0;
integer t6b_error_count = 0;
integer t6b_wait_cycles = 0;
integer t6b_accepted_count = 0;
integer t6b_output_count = 0;
// Test 5: Full buffer and backpressure recovery
logic t5_active = 0;

integer t5_accepted_count = 0;
integer t5_output_count = 0;
integer t5_error_count = 0;
integer t5_wait_cycles = 0;

// ============================================
// TEST 7: RESET DURING ACTIVE TRAFFIC
// ============================================

logic t7_active = 0;

integer t7_error_count = 0;
integer t7_output_count = 0;
integer t7_accepted_count = 0;
    // Independent clocks
    always #5 vibration_clk = ~vibration_clk;
    always #7 temperature_clk = ~temperature_clk;
    always #9 emergency_clk = ~emergency_clk;
    always #5 scheduler_clk = ~scheduler_clk;


// Vibration input acceptance
always @(posedge vibration_clk) begin
    if (rst_n && vibration_valid && vibration_ready) begin

        total_vibration_accepted++;

        if (t5_active)
            t5_accepted_count++;

    end
end


// Temperature input acceptance
always @(posedge temperature_clk) begin
    if (rst_n && temperature_valid && temperature_ready) begin

        total_temperature_accepted++;

        if (t6a_active)
            t6a_accepted_count++;

    end
end
// Emergency input acceptance
always @(posedge emergency_clk) begin
    if (rst_n && emergency_valid && emergency_ready) begin

        total_emergency_accepted++;

        if (t6b_active)
            t6b_accepted_count++;

    end
end
    // DUT
    telemetry_concentrator #(
        .PACKET_WIDTH(PACKET_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MAX_EMERGENCY_BURST(2)
    ) dut (
        .vibration_clk(vibration_clk),
        .temperature_clk(temperature_clk),
        .emergency_clk(emergency_clk),
        .scheduler_clk(scheduler_clk),

        .rst_n(rst_n),

        .vibration_valid(vibration_valid),
        .vibration_ready(vibration_ready),
        .vibration_packet(vibration_packet),

        .temperature_valid(temperature_valid),
        .temperature_ready(temperature_ready),
        .temperature_packet(temperature_packet),

        .emergency_valid(emergency_valid),
        .emergency_ready(emergency_ready),
        .emergency_packet(emergency_packet),

        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_packet(out_packet),

        .buffer_full(buffer_full),
        .buffer_empty(buffer_empty)
    );
    telemetry_sva #(
    .PACKET_WIDTH(PACKET_WIDTH)
) u_telemetry_sva (
    .clk(scheduler_clk),
    .rst_n(rst_n),

    .out_valid(out_valid),
    .out_ready(out_ready),
    .out_packet(out_packet),

    .buffer_full(buffer_full),
    .buffer_empty(buffer_empty),
        // Independent producer clocks
    .vibration_clk(vibration_clk),
    .temperature_clk(temperature_clk),
    .emergency_clk(emergency_clk),

    // Vibration producer
    .vibration_valid(vibration_valid),
    .vibration_ready(vibration_ready),
    .vibration_packet(vibration_packet),

    // Temperature producer
    .temperature_valid(temperature_valid),
    .temperature_ready(temperature_ready),
    .temperature_packet(temperature_packet),

    // Emergency producer
    .emergency_valid(emergency_valid),
    .emergency_ready(emergency_ready),
    .emergency_packet(emergency_packet)
);


telemetry_coverage #(
    .PACKET_WIDTH(PACKET_WIDTH)
) u_telemetry_coverage (
    .clk(scheduler_clk),
    .rst_n(rst_n),

    .out_valid(out_valid),
    .out_ready(out_ready),
    .out_packet(out_packet),

    .buffer_full(buffer_full),
    .buffer_empty(buffer_empty),

    // Internal scheduler observations
    .sched_in_valid(dut.u_packet_scheduler.in_valid),
    .selected_grant(dut.u_packet_scheduler.selected_grant),
    .emergency_streak(dut.u_packet_scheduler.emergency_streak),
    .grant_locked(dut.u_packet_scheduler.grant_locked)
);
// Reference scoreboard
reference_scoreboard #(
    .PACKET_WIDTH(PACKET_WIDTH)
) scoreboard (
    .rst_n(rst_n),

    .vibration_clk(vibration_clk),
    .temperature_clk(temperature_clk),
    .emergency_clk(emergency_clk),

    .vibration_valid(vibration_valid),
    .vibration_ready(vibration_ready),
    .vibration_packet(vibration_packet),

    .temperature_valid(temperature_valid),
    .temperature_ready(temperature_ready),
    .temperature_packet(temperature_packet),

    .emergency_valid(emergency_valid),
    .emergency_ready(emergency_ready),
    .emergency_packet(emergency_packet),

    .scheduler_clk(scheduler_clk),
    .out_valid(out_valid),
    .out_ready(out_ready),
    .out_packet(out_packet),

    .accepted_count(sb_accepted_count),
    .received_count(sb_received_count),
    .error_count(sb_error_count),
    .pending_count(sb_pending_count)
);
   
// Output monitor

always @(posedge scheduler_clk) begin
    if (rst_n && out_valid && out_ready) begin
    $display("[GRANT TRACE] Time=%0t Grant=%0d",
                 $time, out_packet[43:42]);
        received_packets.push_back(out_packet);
        received_count++;
        if (t7_active)
    t7_output_count++;
        if (t5_active)
    t5_output_count++;
output_transfer_cycles++;

case (out_packet[43:42])

    2'd0: begin
        total_vibration_received++;
    end

    2'd1: begin
        total_temperature_received++;

        if (t6a_active)
            t6a_output_count++;
    end

    2'd2: begin
        total_emergency_received++;

        if (t6b_active)
            t6b_output_count++;
    end

    default:
        $error("[METRICS] Invalid output channel");

endcase
        $display(
            "[OUTPUT] Time=%0t Packet=%h Channel=%0d Sequence=%0d",
            $time,
            out_packet,
            out_packet[43:42],
            out_packet[39:32]
        );

        // =========================================
        // TEST 3: Emergency priority and burst limit
        // =========================================
        if (t3_active) begin

            t3_output_count++;

            case (out_packet[43:42])

                2'd2: begin
                    if (t3_normal_remaining > 0 &&
                        t3_emergency_streak >= 2) begin

                        $error(
                            "[PRIORITY FAIL] More than 2 consecutive emergency packets"
                        );

                        t3_error_count++;
                    end

                    t3_emergency_streak++;
                end

                2'd0, 2'd1: begin
                    t3_emergency_streak = 0;
                    t3_normal_remaining--;
                end

                default: begin
                    $error("[PRIORITY FAIL] Invalid channel");
                    t3_error_count++;
                end

            endcase
        end

        // =========================================
        // TEST 4: Round-robin fairness
        // =========================================
        if (t4_active) begin
if (out_packet[43:42] == 2'd0) begin
    t4_vibration_count++;
end
else if (out_packet[43:42] == 2'd1) begin
    t4_temperature_count++;
end
else begin
    $error("[FAIRNESS FAIL] Unexpected channel");
    t4_error_count++;
end
            t4_output_count++;

            if (out_packet[43:42] == 2'd2) begin
                $error("[FAIRNESS FAIL] Unexpected emergency packet");
                t4_error_count++;
            end

            if (t4_prev_valid &&
                out_packet[43:42] == t4_prev_channel) begin

                $error(
                    "[FAIRNESS FAIL] Same normal channel served consecutively. Channel=%0d",
                    out_packet[43:42]
                );

                t4_error_count++;
            end

            t4_prev_channel = out_packet[43:42];
            t4_prev_valid = 1'b1;

            $display(
                "[FAIRNESS] Output channel=%0d Sequence=%0d",
                out_packet[43:42],
                out_packet[39:32]
            );

        end

    end
end


always @(posedge scheduler_clk) begin
    if (rst_n && out_valid && !out_ready)
        output_stall_cycles++;
end

    // Reset
    task automatic reset_dut;
        begin
            rst_n = 0;

            vibration_valid = 0;
            temperature_valid = 0;
            emergency_valid = 0;

            out_ready = 0;

            vibration_packet = 0;
            temperature_packet = 0;
            emergency_packet = 0;

            repeat (6) @(negedge scheduler_clk);

            rst_n = 1;

            repeat (6) @(negedge scheduler_clk);
        end
    endtask

    // Send one vibration packet
    task automatic send_vibration(input integer seq);
        begin
            @(negedge vibration_clk);

            vibration_packet = {
                2'd0, 2'd0, seq[7:0],
                (32'hAAAA0000 + seq)
            };

            vibration_valid = 1;

            do begin
                @(posedge vibration_clk);
            end while (vibration_ready !== 1'b1);

            @(negedge vibration_clk);
            vibration_valid = 0;
        end
    endtask

    // Send one temperature packet
    task automatic send_temperature(input integer seq);
        begin
            @(negedge temperature_clk);

            temperature_packet = {
                2'd1, 2'd0, seq[7:0],
                (32'hBBBB0000 + seq)
            };

            temperature_valid = 1;

            do begin
                @(posedge temperature_clk);
            end while (temperature_ready !== 1'b1);

            @(negedge temperature_clk);
            temperature_valid = 0;
        end
    endtask

    // Send one emergency packet
    task automatic send_emergency(input integer seq);
        begin
            @(negedge emergency_clk);

            emergency_packet = {
                2'd2, 2'd0, seq[7:0],
                (32'hCCCC0000 + seq)
            };

            emergency_valid = 1;

            do begin
                @(posedge emergency_clk);
            end while (emergency_ready !== 1'b1);

            @(negedge emergency_clk);
            emergency_valid = 0;
        end
    endtask
    
    
    
    // ============================================
    // TYPED PACKET GENERATION TASKS
    // Used by Test 11 for packet-type coverage.
    // Existing send tasks remain unchanged.
    // ============================================

    task automatic send_vibration_typed(
        input integer seq,
        input logic [1:0] pkt_type
    );
        begin
            @(negedge vibration_clk);

            vibration_packet = {
                2'd0, pkt_type, seq[7:0],
                (32'hAAAA0000 + seq)
            };

            vibration_valid = 1;

            do begin
                @(posedge vibration_clk);
            end while (vibration_ready !== 1'b1);

            @(negedge vibration_clk);
            vibration_valid = 0;
        end
    endtask


    task automatic send_temperature_typed(
        input integer seq,
        input logic [1:0] pkt_type
    );
        begin
            @(negedge temperature_clk);

            temperature_packet = {
                2'd1, pkt_type, seq[7:0],
                (32'hBBBB0000 + seq)
            };

            temperature_valid = 1;

            do begin
                @(posedge temperature_clk);
            end while (temperature_ready !== 1'b1);

            @(negedge temperature_clk);
            temperature_valid = 0;
        end
    endtask


    task automatic send_emergency_typed(
        input integer seq,
        input logic [1:0] pkt_type
    );
        begin
            @(negedge emergency_clk);

            emergency_packet = {
                2'd2, pkt_type, seq[7:0],
                (32'hCCCC0000 + seq)
            };

            emergency_valid = 1;

            do begin
                @(posedge emergency_clk);
            end while (emergency_ready !== 1'b1);

            @(negedge emergency_clk);
            emergency_valid = 0;
        end
    endtask

    
    task automatic check_full_only_state;

integer timeout_count;

begin

    timeout_count = 0;

    while (timeout_count < 30 &&
           !((|buffer_full) && !(|buffer_empty))) begin

        @(negedge scheduler_clk);
        timeout_count++;

    end

    if ((|buffer_full) && !(|buffer_empty)) begin

        $display("[TEST 8 PASS] Full-only buffer state observed");

    end
    else begin

        $display("[TEST 8 FAIL] Full-only buffer state not observed");

        error_count++;

    end

end

endtask

    // Main test
    initial begin

        $display("\n==========================================");
        $display(" TELEMETRY CONCENTRATOR INTEGRATION TEST");
        $display("==========================================");

        reset_dut();

        // Enable output consumer
        out_ready = 1;

        $display("\n[TEST 1] Simultaneous multi-channel traffic");

        fork
            begin
                for (int i = 0; i < 8; i++)
                    send_vibration(i);
            end

            begin
                for (int i = 0; i < 5; i++)
                    send_temperature(i);
            end

            begin
                for (int i = 0; i < 4; i++)
                    send_emergency(i);
            end
        join

        // Allow all buffers and scheduler to drain
        repeat (150) @(negedge scheduler_clk);

        $display("\n[TEST 2] Output backpressure");

        out_ready = 0;

        fork
            send_temperature(20);
            send_emergency(20);
        join

        repeat (10) @(negedge scheduler_clk);

        begin
            logic [43:0] held_packet;

            if (out_valid !== 1'b1) begin
                $error("[BACKPRESSURE] No output packet available");
                error_count++;
            end
            else begin
                held_packet = out_packet;

                repeat (5) begin
                    @(negedge scheduler_clk);

                    if (out_valid !== 1'b1 ||
                        out_packet !== held_packet) begin

                        $error("[BACKPRESSURE] Output changed during stall");
                        error_count++;
                    end
                end

                $display("[PASS] Output stable during backpressure");
            end
        end

        out_ready = 1;

        repeat (50) @(negedge scheduler_clk);
        // ============================================
        // TEST 3: EMERGENCY PRIORITY UNDER CONTENTION
        // ============================================

        $display("\n[TEST 3] Emergency priority under contention");

        // Start a fresh scoreboard epoch.
        reset_dut();

        // Keep output stalled while loading all buffers.
        out_ready = 0;

        t3_normal_remaining = 8;
        t3_emergency_streak = 0;
        t3_output_count = 0;
        t3_error_count = 0;

        fork
            begin
                for (int i = 0; i < 4; i++)
                    send_vibration(30 + i);
            end

            begin
                for (int i = 0; i < 4; i++)
                    send_temperature(30 + i);
            end

            begin
                for (int i = 0; i < 4; i++)
                    send_emergency(30 + i);
            end
        join

        // Allow asynchronous FIFO synchronizers and
        // read-side staging registers to settle.
        repeat (10) @(negedge scheduler_clk);

        // Start observing scheduler behavior.
        t3_active = 1;
        out_ready = 1;

        // Allow all 12 packets to drain.
        repeat (100) @(negedge scheduler_clk);

        t3_active = 0;

        if (t3_output_count != 12) begin
            $error(
                "[TEST 3 FAIL] Expected 12 outputs, received %0d",
                t3_output_count
            );
            t3_error_count++;
        end

        if (t3_normal_remaining != 0) begin
            $error(
                "[TEST 3 FAIL] Normal packets remaining: %0d",
                t3_normal_remaining
            );
            t3_error_count++;
        end

        if (t3_error_count == 0)
            $display("[TEST 3 PASS] Emergency priority and burst limit verified");
        else
            $display("[TEST 3 FAIL] Priority errors: %0d", t3_error_count);
            
            
            // ============================================
// TEST 4: ROUND-ROBIN FAIRNESS
// ============================================

$display("\n[TEST 4] Round-robin fairness");

reset_dut();

// Hold output while loading both normal channels.
out_ready = 0;

t4_output_count = 0;
t4_error_count = 0;

t4_vibration_count = 0;
t4_temperature_count = 0;

t4_prev_valid = 0;
t4_prev_channel = 0;

fork
    begin
        for (int i = 0; i < 6; i++)
            send_vibration(40 + i);
    end

    begin
        for (int i = 0; i < 6; i++)
            send_temperature(40 + i);
    end
join

// Allow both asynchronous buffers to settle.
repeat (10) @(negedge scheduler_clk);

// Start fairness observation.
t4_active = 1;
out_ready = 1;

// Allow all 12 packets to drain.
repeat (100) @(negedge scheduler_clk);

t4_active = 0;

// Check output count.
if (t4_output_count != 12) begin
    $error(
        "[TEST 4 FAIL] Expected 12 packets, received %0d",
        t4_output_count
    );
    t4_error_count++;
end

if (t4_error_count == 0)
    $display("[TEST 4 PASS] Round-robin fairness verified");
else
    $display("[TEST 4 FAIL] Fairness errors: %0d", t4_error_count);
    
    
    
// ============================================
// TEST 5: FULL BUFFER AND BACKPRESSURE RECOVERY
// ============================================

$display("\n[TEST 5] Full buffer and backpressure recovery");

reset_dut();

// Hold output so the vibration buffer fills.
out_ready = 0;

// Reset Test 5 counters.
t5_accepted_count = 0;
t5_output_count = 0;
t5_error_count = 0;
t5_wait_cycles = 0;

// Enable Test 5 monitoring.
t5_active = 1;

$display("[TEST 5] Filling vibration buffer...");

fork

    // -----------------------------------------
    // Producer: Send 20 vibration packets.
    // The send task holds valid and packet data
    // until the ready handshake occurs.
    // -----------------------------------------
    begin

        for (int i = 0; i < 20; i++) begin
            send_vibration(60 + i);
        end

        $display("[TEST 5] Producer completed all 20 packets");

    end

    // -----------------------------------------
    // Controller: Wait for buffer full.
    // -----------------------------------------
    begin

        while (vibration_ready !== 1'b0 &&
               t5_wait_cycles < 100) begin

            @(negedge vibration_clk);
            t5_wait_cycles++;

        end

        if (vibration_ready !== 1'b0) begin

            $error("[TEST 5 FAIL] Vibration buffer never became full");
            t5_error_count++;

        end
        else begin

            $display("[TEST 5] Vibration input blocked");

            // Allow the full condition to remain
            // for a few additional clock cycles.
            repeat (3) @(negedge vibration_clk);

            if (!(|buffer_full)) begin

                $error("[TEST 5 FAIL] No buffer_full flag observed");
                t5_error_count++;

            end
            else begin

                $display("[TEST 5 PASS] Buffer full condition observed");

            end

            // Release output backpressure.
            $display("[TEST 5] Releasing output backpressure");

            out_ready = 1;

        end

    end

join

// Allow all remaining packets to drain.
repeat (100) @(negedge scheduler_clk);

// Stop Test 5 monitoring.
t5_active = 0;

// -----------------------------------------
// Test 5 result checks
// -----------------------------------------

$display("\n========== TEST 5 RECOVERY REPORT ==========");

$display("Packets accepted       : %0d", t5_accepted_count);
$display("Packets received       : %0d", t5_output_count);
$display("Scoreboard accepted    : %0d", sb_accepted_count);
$display("Scoreboard received    : %0d", sb_received_count);
$display("Scoreboard pending     : %0d", sb_pending_count);
$display("Scoreboard errors      : %0d", sb_error_count);
$display("Test 5 errors          : %0d", t5_error_count);

if (t5_accepted_count != 20) begin

    $error("[TEST 5 FAIL] Expected 20 accepted packets");
    t5_error_count++;

end

if (t5_output_count != 20) begin

    $error("[TEST 5 FAIL] Expected 20 output packets");
    t5_error_count++;

end

if (sb_accepted_count != sb_received_count) begin

    $error("[TEST 5 FAIL] Scoreboard packet count mismatch");
    t5_error_count++;

end

if (sb_pending_count != 0) begin

    $error("[TEST 5 FAIL] Packets remain pending");
    t5_error_count++;

end

if (sb_error_count != 0) begin

    $error("[TEST 5 FAIL] Scoreboard detected packet mismatches");
    t5_error_count++;

end

if (t5_error_count == 0)
    $display("[TEST 5 PASS] Full buffer and backpressure recovery verified");
else
    $display("[TEST 5 FAIL] Recovery errors: %0d", t5_error_count);

$display("============================================");

                $display("\n==========================================");
      $display("\n==========================================");
      
      
      
// ============================================
// TEST 6A: TEMPERATURE PRODUCER BACKPRESSURE
// ============================================

$display("\n[TEST 6A] Temperature producer backpressure");

reset_dut();

out_ready = 0;

t6a_error_count = 0;
t6a_wait_cycles = 0;
t6a_accepted_count = 0;
t6a_output_count = 0;

t6a_active = 1;

fork

    // Temperature producer: 20 packets
    begin
        for (int i = 0; i < 20; i++)
            send_temperature(80 + i);

        $display("[TEST 6A] Producer completed");
    end

    // Backpressure controller
    begin : temperature_controller

    logic [43:0] held_temperature_packet;

    // Wait until a valid packet is actually blocked.
    while (!(temperature_valid === 1'b1 &&
             temperature_ready === 1'b0) &&
           t6a_wait_cycles < 100) begin

        @(posedge temperature_clk);
        t6a_wait_cycles++;

    end

    if (!(temperature_valid === 1'b1 &&
          temperature_ready === 1'b0)) begin

        $error("[TEST 6A FAIL] Temperature producer was not blocked");
        t6a_error_count++;

    end
    else begin

        $display("[TEST 6A] Temperature producer blocked");

        // Capture the packet at a positive clock edge.
        held_temperature_packet = temperature_packet;

        // Check stability across three positive edges.
        repeat (3) begin

            @(posedge temperature_clk);

            if (temperature_valid !== 1'b1) begin
                $error("[TEST 6A FAIL] Temperature valid dropped during stall");
                t6a_error_count++;
            end

            if (temperature_packet !== held_temperature_packet) begin
                $error("[TEST 6A FAIL] Temperature packet changed during stall");
                t6a_error_count++;
            end

            if (temperature_ready !== 1'b0) begin
                $error("[TEST 6A FAIL] Temperature ready unexpectedly asserted");
                t6a_error_count++;
            end

        end

        if (|buffer_full)
            $display("[TEST 6A PASS] Full buffer observed");
        else begin
            $error("[TEST 6A FAIL] No full buffer flag observed");
            t6a_error_count++;
        end

    end

    // Always release output backpressure.
    @(negedge scheduler_clk);
    out_ready = 1;

    $display("[TEST 6A] Output backpressure released");

end



join

// Drain remaining packets.
repeat (100) @(negedge scheduler_clk);

t6a_active = 0;

// Test 6A report
$display("\n========== TEST 6A REPORT ==========");

$display("Temperature accepted : %0d", t6a_accepted_count);
$display("Temperature received : %0d", t6a_output_count);
$display("Scoreboard accepted  : %0d", sb_accepted_count);
$display("Scoreboard received  : %0d", sb_received_count);
$display("Scoreboard pending   : %0d", sb_pending_count);
$display("Scoreboard errors    : %0d", sb_error_count);

if (t6a_accepted_count != 20) begin
    $error("[TEST 6A FAIL] Expected 20 accepted temperature packets");
    t6a_error_count++;
end

if (t6a_output_count != 20) begin
    $error("[TEST 6A FAIL] Expected 20 temperature output packets");
    t6a_error_count++;
end

if (sb_accepted_count != 20 ||
    sb_received_count != 20 ||
    sb_pending_count != 0 ||
    sb_error_count != 0) begin

    $error("[TEST 6A FAIL] Scoreboard verification failed");
    t6a_error_count++;

end

if (t6a_error_count == 0)
    $display("[TEST 6A PASS] Temperature backpressure and recovery verified");
else
    $display("[TEST 6A FAIL] Errors: %0d", t6a_error_count);

$display("====================================");


// ============================================
// TEST 6B: EMERGENCY PRODUCER BACKPRESSURE
// ============================================

$display("\n[TEST 6B] Emergency producer backpressure");

reset_dut();

out_ready = 0;

t6b_error_count = 0;
t6b_wait_cycles = 0;
t6b_accepted_count = 0;
t6b_output_count = 0;

t6b_active = 1;

fork

    // Emergency producer: 20 packets
    begin
        for (int i = 0; i < 20; i++)
            send_emergency(100 + i);

        $display("[TEST 6B] Producer completed");
    end

    // Backpressure controller
    begin : emergency_controller

    logic [43:0] held_emergency_packet;

    // Wait until a valid emergency packet is actually blocked.
    while (!(emergency_valid === 1'b1 &&
             emergency_ready === 1'b0) &&
           t6b_wait_cycles < 100) begin

        @(posedge emergency_clk);
        t6b_wait_cycles++;

    end

    if (!(emergency_valid === 1'b1 &&
          emergency_ready === 1'b0)) begin

        $error("[TEST 6B FAIL] Emergency producer was not blocked");
        t6b_error_count++;

    end
    else begin

        $display("[TEST 6B] Emergency producer blocked");

        // Capture the packet at a positive clock edge.
        held_emergency_packet = emergency_packet;

        // Check stability across three positive edges.
        repeat (3) begin

            @(posedge emergency_clk);

            if (emergency_valid !== 1'b1) begin
                $error("[TEST 6B FAIL] Emergency valid dropped during stall");
                t6b_error_count++;
            end

            if (emergency_packet !== held_emergency_packet) begin
                $error("[TEST 6B FAIL] Emergency packet changed during stall");
                t6b_error_count++;
            end

            if (emergency_ready !== 1'b0) begin
                $error("[TEST 6B FAIL] Emergency ready unexpectedly asserted");
                t6b_error_count++;
            end

        end

        if (|buffer_full)
            $display("[TEST 6B PASS] Full buffer observed");
        else begin
            $error("[TEST 6B FAIL] No full buffer flag observed");
            t6b_error_count++;
        end

    end

    // Always release output backpressure.
    @(negedge scheduler_clk);
    out_ready = 1;

    $display("[TEST 6B] Output backpressure released");

end

join

// Drain remaining packets.
repeat (100) @(negedge scheduler_clk);

t6b_active = 0;

// Test 6B report
$display("\n========== TEST 6B REPORT ==========");

$display("Emergency accepted : %0d", t6b_accepted_count);
$display("Emergency received : %0d", t6b_output_count);
$display("Scoreboard accepted: %0d", sb_accepted_count);
$display("Scoreboard received: %0d", sb_received_count);
$display("Scoreboard pending : %0d", sb_pending_count);
$display("Scoreboard errors  : %0d", sb_error_count);

if (t6b_accepted_count != 20) begin
    $error("[TEST 6B FAIL] Expected 20 accepted emergency packets");
    t6b_error_count++;
end

if (t6b_output_count != 20) begin
    $error("[TEST 6B FAIL] Expected 20 emergency output packets");
    t6b_error_count++;
end

if (sb_accepted_count != 20 ||
    sb_received_count != 20 ||
    sb_pending_count != 0 ||
    sb_error_count != 0) begin

    $error("[TEST 6B FAIL] Scoreboard verification failed");
    t6b_error_count++;

end

if (t6b_error_count == 0)
    $display("[TEST 6B PASS] Emergency backpressure and recovery verified");
else
    $display("[TEST 6B FAIL] Errors: %0d", t6b_error_count);
    
    
    
    
    // ============================================
// TEST 7B: RESET DURING OUTPUT BACKPRESSURE
// ============================================

$display("\n[TEST 7B] Reset during output backpressure");

reset_dut();

out_ready = 0;

t7_error_count = 0;
t7_output_count = 0;
t7_accepted_count = 0;
t7_active = 1;

// -----------------------------------------
// Load one packet into the vibration buffer.
// -----------------------------------------

send_vibration(150);

// Wait for output staging and scheduler.
repeat (15) @(negedge scheduler_clk);

if (out_valid !== 1'b1) begin
    $error("[TEST 7B FAIL] No packet available before reset");
    t7_error_count++;
end
else begin

    $display("[TEST 7B] Output packet stalled");

    // Confirm packet remains valid during stall.
    repeat (3) @(negedge scheduler_clk);

    if (out_valid !== 1'b1) begin
        $error("[TEST 7B FAIL] Output valid dropped before reset");
        t7_error_count++;
    end

end

// -----------------------------------------
// Assert reset while output is stalled.
// -----------------------------------------

$display("[TEST 7B] Asserting reset");

rst_n = 0;

vibration_valid = 0;
temperature_valid = 0;
emergency_valid = 0;

out_ready = 0;

repeat (6) @(negedge scheduler_clk);

rst_n = 1;

repeat (10) @(negedge scheduler_clk);

// Old packet must not reappear.
if (out_valid !== 1'b0) begin
    $error("[TEST 7B FAIL] Old packet appeared after reset");
    t7_error_count++;
end
else begin
    $display("[TEST 7B PASS] Stalled packet flushed by reset");
end

// ============================================
// TEST 7C: RESET WITH MULTIPLE QUEUED PACKETS
// ============================================

$display("\n[TEST 7C] Reset with packets queued in multiple buffers");

// Keep output stalled.
out_ready = 0;

// Load packets into all three channels.
fork
    begin
        send_vibration(160);
        send_vibration(161);
    end

    begin
        send_temperature(160);
        send_temperature(161);
    end

    begin
        send_emergency(160);
        send_emergency(161);
    end
join

// Allow buffers and scheduler to settle.
repeat (15) @(negedge scheduler_clk);

// Verify packets are waiting.
if (out_valid !== 1'b1) begin
    $error("[TEST 7C FAIL] No queued output before reset");
    t7_error_count++;
end

$display("[TEST 7C] Resetting all queued packets");

// Assert reset.
rst_n = 0;

vibration_valid = 0;
temperature_valid = 0;
emergency_valid = 0;

out_ready = 0;

repeat (6) @(negedge scheduler_clk);

rst_n = 1;

repeat (15) @(negedge scheduler_clk);

// Verify no old output survives reset.
if (out_valid !== 1'b0) begin
    $error("[TEST 7C FAIL] Old queued packet survived reset");
    t7_error_count++;
end
else begin
    $display("[TEST 7C PASS] Queued packets flushed successfully");
end

// ============================================
// TEST 7D: POST-RESET RECOVERY
// ============================================

$display("\n[TEST 7D] Post-reset traffic recovery");

out_ready = 1;

t7_output_count = 0;
t7_active = 1;

// Send fresh packets after reset.
fork
    send_vibration(200);
    send_temperature(200);
    send_emergency(200);
join

// Allow all fresh packets to drain.
repeat (50) @(negedge scheduler_clk);

t7_active = 0;



// -----------------------------------------
// Recovery report
// -----------------------------------------

$display("\n========== TEST 7 REPORT ==========");

$display("Fresh packets accepted : %0d", sb_accepted_count);
$display("Fresh packets received : %0d", sb_received_count);
$display("Fresh packets pending  : %0d", sb_pending_count);
$display("Scoreboard errors      : %0d", sb_error_count);
$display("Test 7 output count    : %0d", t7_output_count);
$display("Test 7 errors          : %0d", t7_error_count);

if (sb_accepted_count != 3 ||
    sb_received_count != 3 ||
    sb_pending_count != 0 ||
    sb_error_count != 0 ||
    t7_output_count != 3) begin

    $error("[TEST 7 FAIL] Post-reset recovery verification failed");
    t7_error_count++;

end

if (t7_error_count == 0)
    $display("[TEST 7 PASS] Reset and recovery verified");
else
    $display("[TEST 7 FAIL] Reset errors: %0d", t7_error_count);

$display("==================================");

$display("====================================");

      
// =========================================
// TEST 8: FULL-ONLY BUFFER STATE
// =========================================

$display("\n[TEST 8] Full-only buffer state coverage");

reset_dut();

out_ready = 0;

fork
    begin
        // Fill vibration buffer
        for (int i = 0; i < 17; i++)
            send_vibration(220 + i);
    end

    begin
        // Keep temperature FIFO populated
        for (int i = 0; i < 3; i++)
            send_temperature(220 + i);
    end

    begin
        // Keep emergency FIFO populated
        for (int i = 0; i < 3; i++)
            send_emergency(220 + i);
    end
join

$display("\n[TEST 8 DEBUG]");
$display("Buffer full  = %b", buffer_full);
$display("Buffer empty = %b", buffer_empty);
$display("Full-only state = %b",
         ((|buffer_full) && !(|buffer_empty)));
check_full_only_state();

out_ready = 1;

repeat (80) @(negedge scheduler_clk);

if (scoreboard.pending_count == 0 &&
    scoreboard.error_count == 0) begin

    $display("[TEST 8 PASS] Multi-buffer drain successful");

end
else begin

    $display("[TEST 8 FAIL] Drain or scoreboard error");
    error_count++;

end

$display("\n[TEST 9A] Emergency burst followed by vibration");

reset_dut();
out_ready = 0;

// First emergency packet reaches output staging
send_emergency(240);

wait (out_valid && out_packet[43:42] == 2'd2);

$display("[TEST 9A] First emergency packet staged");

// Queue additional emergency and vibration packets
fork
    begin
        send_emergency(241);
        send_emergency(242);
    end

    begin
        send_vibration(240);
        send_vibration(241);
    end
join

// Confirm both FIFOs have pending data
wait (!buffer_empty[2] && !buffer_empty[0]);

$display("[TEST 9A] Releasing output");

out_ready = 1;

// Allow scheduler to transfer the packets
repeat (30) @(negedge scheduler_clk);

if (scoreboard.pending_count == 0 &&
    scoreboard.error_count == 0)
    $display("[TEST 9A PASS] Emergency burst and vibration recovery");
else begin
    $display("[TEST 9A FAIL] Scoreboard or drain error");
    error_count++;
end


$display("\n[TEST 9B] Emergency burst followed by temperature");

reset_dut();
out_ready = 0;

// First emergency packet reaches output staging
send_emergency(250);

wait (out_valid && out_packet[43:42] == 2'd2);

$display("[TEST 9B] First emergency packet staged");

// Queue additional emergency and temperature packets
fork
    begin
        send_emergency(251);
        send_emergency(252);
    end

    begin
        send_temperature(250);
        send_temperature(251);
    end
join

wait (!buffer_empty[2] && !buffer_empty[1]);

$display("[TEST 9B] Releasing output");

out_ready = 1;

repeat (30) @(negedge scheduler_clk);

if (scoreboard.pending_count == 0 &&
    scoreboard.error_count == 0)
    $display("[TEST 9B PASS] Emergency burst and temperature recovery");
else begin
    $display("[TEST 9B FAIL] Scoreboard or drain error");
    error_count++;
end
      
     
// ================================================
// TEST 10: VIBRATION GRANT WITH ALL INPUTS ACTIVE
// ================================================

$display("\n[TEST 10] Vibration grant under full contention");

reset_dut();

// -----------------------------------------
// Step 1: Establish emergency streak = 2
// -----------------------------------------

out_ready = 1;

send_emergency(260);
send_emergency(261);

// Wait until both emergency packets have been
// transferred by the scheduler.
wait (dut.u_packet_scheduler.emergency_streak == 2'd2);

$display("[TEST 10] Emergency streak reached maximum");

// -----------------------------------------
// Step 2: Stall output
// -----------------------------------------

out_ready = 0;

// -----------------------------------------
// Step 3: Present vibration first
// -----------------------------------------

send_vibration(260);

// Wait until vibration is selected and locked.
wait (out_valid &&
      out_packet[43:42] == 2'd0);

$display("[TEST 10] Vibration grant locked during stall");

// -----------------------------------------
// Step 4: Queue temperature and emergency
// -----------------------------------------

send_temperature(260);
send_emergency(262);

// -----------------------------------------
// Step 5: Verify all three inputs are valid
// while vibration remains selected.
// -----------------------------------------

wait (dut.u_packet_scheduler.in_valid == 3'b111 &&
      dut.u_packet_scheduler.selected_grant == 2'd0 &&
      out_valid);

$display("[TEST 10] All three scheduler inputs valid");
$display("[TEST 10] Selected grant = %0d",
         dut.u_packet_scheduler.selected_grant);

// -----------------------------------------
// Step 6: Release output
// -----------------------------------------

out_ready = 1;

// Allow all remaining packets to drain.
repeat (30) @(negedge scheduler_clk);

// -----------------------------------------
// Step 7: Check scoreboard
// -----------------------------------------

if (sb_pending_count == 0 &&
    sb_error_count == 0) begin

    $display("[TEST 10 PASS] All contention packets drained");

end
else begin

    $display("[TEST 10 FAIL] Scoreboard or drain error");
    error_count++;

end


    // ================================================
    // TEST 11: ALL CHANNEL x PACKET TYPE COMBINATIONS
    // ================================================

    $display("\n[TEST 11] Packet type and channel cross coverage");

    reset_dut();

    out_ready = 1;

    // Four packet types on each of three channels.
    // Total expected packets = 3 x 4 = 12.

    fork

        // -----------------------------------------
        // VIBRATION: packet types 0, 1, 2, 3
        // -----------------------------------------

        begin
            for (int pkt_type = 0; pkt_type < 4; pkt_type++) begin

                send_vibration_typed(
                    270 + pkt_type,
                    pkt_type[1:0]
                );

                $display(
                    "[TEST 11] Vibration packet type=%0d sent",
                    pkt_type
                );

            end
        end

        // -----------------------------------------
        // TEMPERATURE: packet types 0, 1, 2, 3
        // -----------------------------------------

        begin
            for (int pkt_type = 0; pkt_type < 4; pkt_type++) begin

                send_temperature_typed(
                    280 + pkt_type,
                    pkt_type[1:0]
                );

                $display(
                    "[TEST 11] Temperature packet type=%0d sent",
                    pkt_type
                );

            end
        end

        // -----------------------------------------
        // EMERGENCY: packet types 0, 1, 2, 3
        // -----------------------------------------

        begin
            for (int pkt_type = 0; pkt_type < 4; pkt_type++) begin

                send_emergency_typed(
                    290 + pkt_type,
                    pkt_type[1:0]
                );

                $display(
                    "[TEST 11] Emergency packet type=%0d sent",
                    pkt_type
                );

            end
        end

    join

    // Allow all asynchronous buffers and scheduler
    // to transfer the 12 packets.
    repeat (100) @(negedge scheduler_clk);

    // -----------------------------------------
    // TEST 11 REPORT
    // -----------------------------------------

    $display("\n========== TEST 11 REPORT ==========");

    $display("Packets accepted : %0d", sb_accepted_count);
    $display("Packets received : %0d", sb_received_count);
    $display("Packets pending  : %0d", sb_pending_count);
    $display("Scoreboard errors: %0d", sb_error_count);

    if (sb_accepted_count == 12 &&
        sb_received_count == 12 &&
        sb_pending_count == 0 &&
        sb_error_count == 0) begin

        $display("[TEST 11 PASS] All 12 channel/type combinations verified");

    end
    else begin

        $display("[TEST 11 FAIL] Packet type verification failed");
        error_count++;

    end

    $display("====================================");


$display("==============================================");

$display(" TELEMETRY INTEGRATION TEST REPORT");
$display("==========================================");

$display("Packets accepted    : %0d", sb_accepted_count);
$display("Packets received    : %0d", sb_received_count);
$display("Packets pending     : %0d", sb_pending_count);
$display("Scoreboard errors   : %0d", sb_error_count);
$display("Backpressure errors : %0d", error_count);

$display("Priority test outputs: %0d", t3_output_count);
$display("Priority test errors : %0d", t3_error_count);
$display("");
$display("");
$display("========== TEST 4 FAIRNESS REPORT ==========");

$display("Vibration packets                  : %0d",
         t4_vibration_count);

$display("Temperature packets                : %0d",
         t4_temperature_count);

$display("Total outputs                      : %0d",
         t4_output_count);

$display("Consecutive same-channel violations: %0d",
         t4_error_count);

$display("Scoreboard errors                  : %0d",
         sb_error_count);

$display("Pending packets                    : %0d",
         sb_pending_count);

$display("============================================");

$display("");
$display("========== PERFORMANCE REPORT ==========");

$display("Vibration accepted  : %0d",
         total_vibration_accepted);

$display("Temperature accepted: %0d",
         total_temperature_accepted);

$display("Emergency accepted  : %0d",
         total_emergency_accepted);

$display("-----------------------------------------");

$display("Vibration received  : %0d",
         total_vibration_received);

$display("Temperature received: %0d",
         total_temperature_received);

$display("Emergency received  : %0d",
         total_emergency_received);

$display("-----------------------------------------");

$display("Output transfer cycles: %0d",
         output_transfer_cycles);

$display("Output stall cycles   : %0d",
         output_stall_cycles);

$display("=========================================");
if (sb_accepted_count != sb_received_count) begin
    $error("[FAIL] Accepted and received packet counts differ");
    error_count++;
end

if (sb_pending_count != 0) begin
    $error("[FAIL] Packets remain in expected queues");
    error_count++;
end

if (sb_error_count != 0)
    error_count++;

if (t3_error_count != 0)
    error_count++;

if (t4_error_count != 0)
    error_count++;
    
 if (t5_error_count != 0)
    error_count++;
    
    if (t6a_error_count != 0)
    error_count++;

if (t6b_error_count != 0)
    error_count++;
    
    if (t7_error_count != 0)
    error_count++;
    $display("Test 6A temperature errors: %0d", t6a_error_count);
$display("Test 6B emergency errors  : %0d", t6b_error_count);
$display("Test 7 reset errors: %0d", t7_error_count);
if (error_count == 0)
    $display("[FINAL RESULT] ALL TESTS PASSED");
else
    $display("[FINAL RESULT] TEST FAILED");

$display("==========================================");
u_telemetry_sva.print_report();

u_telemetry_coverage.print_report();
u_telemetry_coverage.print_detailed_coverage();
$finish;
    end

    initial begin
        #50000;
        $fatal(1, "[FATAL] Integration test timeout");
    end

endmodule
