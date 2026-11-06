`timescale 1ns/1ps

module telemetry_sva #(
    parameter PACKET_WIDTH = 44
)(
    // Common scheduler clock
    input logic clk,
    input logic rst_n,

    // Output interface
    input logic out_valid,
    input logic out_ready,
    input logic [PACKET_WIDTH-1:0] out_packet,

    // Buffer status
    input logic [2:0] buffer_full,
    input logic [2:0] buffer_empty,

    // Independent producer clocks
    input logic vibration_clk,
    input logic temperature_clk,
    input logic emergency_clk,

    // Vibration input interface
    input logic vibration_valid,
    input logic vibration_ready,
    input logic [PACKET_WIDTH-1:0] vibration_packet,

    // Temperature input interface
    input logic temperature_valid,
    input logic temperature_ready,
    input logic [PACKET_WIDTH-1:0] temperature_packet,

    // Emergency input interface
    input logic emergency_valid,
    input logic emergency_ready,
    input logic [PACKET_WIDTH-1:0] emergency_packet
);

    // =========================================
    // FAILURE COUNTERS
    // =========================================

    integer stability_failures = 0;
    integer known_packet_failures = 0;
    integer buffer_status_failures = 0;
    integer valid_stall_failures = 0;
    integer invalid_output_failures = 0;

    integer vibration_valid_failures = 0;
    integer vibration_data_failures = 0;

    integer temperature_valid_failures = 0;
    integer temperature_data_failures = 0;

    integer emergency_valid_failures = 0;
    integer emergency_data_failures = 0;


    // =========================================
    // OBSERVATION COUNTERS
    // =========================================

    integer stability_checks = 0;
    integer known_packet_checks = 0;
    integer buffer_status_checks = 0;
    integer valid_stall_checks = 0;
    integer invalid_output_checks = 0;

    integer backpressure_cycles = 0;
    integer valid_packet_cycles = 0;
    integer buffer_full_cycles = 0;
    integer buffer_empty_cycles = 0;

    integer vibration_stall_cycles = 0;
    integer temperature_stall_cycles = 0;
    integer emergency_stall_cycles = 0;


    // =========================================
    // PROPERTY 1: OUTPUT STABILITY
    // =========================================

    property p_output_stable_during_stall;
        @(posedge clk)
        disable iff (!rst_n)
        (out_valid && !out_ready)
        |=> (out_valid && $stable(out_packet));
    endproperty

    a_output_stable_during_stall:
        assert property (p_output_stable_during_stall)
        else begin
            stability_failures++;
            $error("[SVA FAIL] Output packet changed during stall");
        end


    // =========================================
    // PROPERTY 2: VALID PACKET MUST BE KNOWN
    // =========================================

    property p_valid_packet_known;
        @(posedge clk)
        disable iff (!rst_n)
        out_valid |-> !$isunknown(out_packet);
    endproperty

    a_valid_packet_known:
        assert property (p_valid_packet_known)
        else begin
            known_packet_failures++;
            $error("[SVA FAIL] Unknown output packet");
        end


    // =========================================
    // PROPERTY 3: BUFFER NOT FULL AND EMPTY
    // =========================================

    property p_buffer_not_full_and_empty;
        @(posedge clk)
        disable iff (!rst_n)
        ((buffer_full & buffer_empty) == 3'b000);
    endproperty

    a_buffer_not_full_and_empty:
        assert property (p_buffer_not_full_and_empty)
        else begin
            buffer_status_failures++;
            $error("[SVA FAIL] Buffer full and empty simultaneously");
        end


    // =========================================
    // PROPERTY 4: OUTPUT VALID HELD DURING STALL
    // =========================================

    property p_valid_held_during_stall;
        @(posedge clk)
        disable iff (!rst_n)
        (out_valid && !out_ready)
        |=> out_valid;
    endproperty

    a_valid_held_during_stall:
        assert property (p_valid_held_during_stall)
        else begin
            valid_stall_failures++;
            $error("[SVA FAIL] out_valid dropped during stall");
        end


    // =========================================
    // PROPERTY 5: INVALID OUTPUT MUST BE ZERO
    // =========================================

    property p_invalid_output_zero;
        @(posedge clk)
        disable iff (!rst_n)
        !out_valid |-> (out_packet == '0);
    endproperty

    a_invalid_output_zero:
        assert property (p_invalid_output_zero)
        else begin
            invalid_output_failures++;
            $error("[SVA FAIL] Invalid output packet is not zero");
        end


    // =========================================
    // PROPERTY 6: VIBRATION VALID HELD
    // =========================================

    property p_vibration_valid_held;
        @(posedge vibration_clk)
        disable iff (!rst_n)
        (vibration_valid && !vibration_ready)
        |=> vibration_valid;
    endproperty

    a_vibration_valid_held:
        assert property (p_vibration_valid_held)
        else begin
            vibration_valid_failures++;
            $error("[SVA FAIL] Vibration valid dropped during backpressure");
        end


    // =========================================
    // PROPERTY 7: VIBRATION DATA STABILITY
    // =========================================

    property p_vibration_data_stable;
        @(posedge vibration_clk)
        disable iff (!rst_n)
        (vibration_valid && !vibration_ready)
        |=> $stable(vibration_packet);
    endproperty

    a_vibration_data_stable:
        assert property (p_vibration_data_stable)
        else begin
            vibration_data_failures++;
            $error("[SVA FAIL] Vibration packet changed during backpressure");
        end


    // =========================================
    // PROPERTY 8: TEMPERATURE VALID HELD
    // =========================================

    property p_temperature_valid_held;
        @(posedge temperature_clk)
        disable iff (!rst_n)
        (temperature_valid && !temperature_ready)
        |=> temperature_valid;
    endproperty

    a_temperature_valid_held:
        assert property (p_temperature_valid_held)
        else begin
            temperature_valid_failures++;
            $error("[SVA FAIL] Temperature valid dropped during backpressure");
        end


    // =========================================
    // PROPERTY 9: TEMPERATURE DATA STABILITY
    // =========================================

    property p_temperature_data_stable;
        @(posedge temperature_clk)
        disable iff (!rst_n)
        (temperature_valid && !temperature_ready)
        |=> $stable(temperature_packet);
    endproperty

    a_temperature_data_stable:
        assert property (p_temperature_data_stable)
        else begin
            temperature_data_failures++;
            $error("[SVA FAIL] Temperature packet changed during backpressure");
        end


    // =========================================
    // PROPERTY 10: EMERGENCY VALID HELD
    // =========================================

    property p_emergency_valid_held;
        @(posedge emergency_clk)
        disable iff (!rst_n)
        (emergency_valid && !emergency_ready)
        |=> emergency_valid;
    endproperty

    a_emergency_valid_held:
        assert property (p_emergency_valid_held)
        else begin
            emergency_valid_failures++;
            $error("[SVA FAIL] Emergency valid dropped during backpressure");
        end


    // =========================================
    // PROPERTY 11: EMERGENCY DATA STABILITY
    // =========================================

    property p_emergency_data_stable;
        @(posedge emergency_clk)
        disable iff (!rst_n)
        (emergency_valid && !emergency_ready)
        |=> $stable(emergency_packet);
    endproperty

    a_emergency_data_stable:
        assert property (p_emergency_data_stable)
        else begin
            emergency_data_failures++;
            $error("[SVA FAIL] Emergency packet changed during backpressure");
        end


    // =========================================
    // OUTPUT SCENARIO OBSERVATION COUNTERS
    // =========================================

    always @(posedge clk) begin

        if (rst_n) begin

            buffer_status_checks++;

            if (out_valid)
                known_packet_checks++;

            if (!out_valid)
                invalid_output_checks++;

            if (out_valid && !out_ready) begin
                stability_checks++;
                valid_stall_checks++;
                backpressure_cycles++;
            end

            if (out_valid)
                valid_packet_cycles++;

            if (|buffer_full)
                buffer_full_cycles++;

            if (|buffer_empty)
                buffer_empty_cycles++;

        end

    end


    // =========================================
    // INPUT BACKPRESSURE OBSERVATION COUNTERS
    // Each channel uses its own clock.
    // =========================================

    always @(posedge vibration_clk) begin
        if (rst_n && vibration_valid && !vibration_ready)
            vibration_stall_cycles++;
    end

    always @(posedge temperature_clk) begin
        if (rst_n && temperature_valid && !temperature_ready)
            temperature_stall_cycles++;
    end

    always @(posedge emergency_clk) begin
        if (rst_n && emergency_valid && !emergency_ready)
            emergency_stall_cycles++;
    end


    // =========================================
    // FINAL SVA REPORT TASK
    // =========================================

    task print_report;

    begin

        $display("\n");
        $display("==========================================");
        $display("          TELEMETRY SVA REPORT");
        $display("==========================================");

        $display("\n--- OUTPUT ASSERTION RESULTS ---");

        if (stability_checks > 0 && stability_failures == 0)
            $display("Output stability          : PASS");
        else
            $display("Output stability          : NOT VERIFIED");

        if (known_packet_checks > 0 && known_packet_failures == 0)
            $display("Valid packet known        : PASS");
        else
            $display("Valid packet known        : NOT VERIFIED");

        if (buffer_status_checks > 0 && buffer_status_failures == 0)
            $display("Buffer status             : PASS");
        else
            $display("Buffer status             : NOT VERIFIED");

        if (valid_stall_checks > 0 && valid_stall_failures == 0)
            $display("Valid held during stall   : PASS");
        else
            $display("Valid held during stall   : NOT VERIFIED");

        if (invalid_output_checks > 0 && invalid_output_failures == 0)
            $display("Invalid output zero       : PASS");
        else
            $display("Invalid output zero       : NOT VERIFIED");


        $display("\n--- PRODUCER ASSERTION RESULTS ---");

        if (vibration_stall_cycles > 0 &&
            vibration_valid_failures == 0 &&
            vibration_data_failures == 0)
            $display("Vibration producer        : PASS");
        else
            $display("Vibration producer        : NOT VERIFIED");

        if (temperature_stall_cycles > 0 &&
            temperature_valid_failures == 0 &&
            temperature_data_failures == 0)
            $display("Temperature producer      : PASS");
        else
            $display("Temperature producer      : NOT VERIFIED");

        if (emergency_stall_cycles > 0 &&
            emergency_valid_failures == 0 &&
            emergency_data_failures == 0)
            $display("Emergency producer        : PASS");
        else
            $display("Emergency producer        : NOT VERIFIED");


        $display("\n--- FAILURE COUNTERS ---");

        $display("Output stability failures : %0d", stability_failures);
        $display("Known packet failures     : %0d", known_packet_failures);
        $display("Buffer status failures    : %0d", buffer_status_failures);
        $display("Output valid stall failures: %0d", valid_stall_failures);
        $display("Invalid output failures   : %0d", invalid_output_failures);

        $display("Vibration valid failures  : %0d", vibration_valid_failures);
        $display("Vibration data failures   : %0d", vibration_data_failures);

        $display("Temperature valid failures: %0d", temperature_valid_failures);
        $display("Temperature data failures: %0d", temperature_data_failures);

        $display("Emergency valid failures  : %0d", emergency_valid_failures);
        $display("Emergency data failures   : %0d", emergency_data_failures);


        $display("\n--- SCENARIO OBSERVATIONS ---");

        $display("Output stability observations: %0d", stability_checks);
        $display("Known packet observations    : %0d", known_packet_checks);
        $display("Buffer status samples        : %0d", buffer_status_checks);
        $display("Output backpressure cycles   : %0d", backpressure_cycles);
        $display("Valid output cycles          : %0d", valid_packet_cycles);
        $display("Buffer full cycles           : %0d", buffer_full_cycles);
        $display("Buffer empty cycles          : %0d", buffer_empty_cycles);

        $display("Vibration producer stalls    : %0d", vibration_stall_cycles);
        $display("Temperature producer stalls  : %0d", temperature_stall_cycles);
        $display("Emergency producer stalls    : %0d", emergency_stall_cycles);

        $display("==========================================");

    end

    endtask

endmodule