
`timescale 1ns/1ps

module telemetry_coverage #(
    parameter PACKET_WIDTH = 44
)(
    input logic clk,
    input logic rst_n,

    input logic out_valid,
    input logic out_ready,
    input logic [PACKET_WIDTH-1:0] out_packet,

    input logic [2:0] buffer_full,
    input logic [2:0] buffer_empty,
        // Scheduler internal observation signals
    input logic [2:0] sched_in_valid,
    input logic [1:0] selected_grant,
    input logic [1:0] emergency_streak,
    input logic grant_locked
);

    // =========================================
    // TELEMETRY FUNCTIONAL COVERAGE
    // =========================================

    covergroup telemetry_cg @(posedge clk);

        option.per_instance = 1;

        // -------------------------------------
        // 1. Output channel coverage
        // -------------------------------------

        cp_channel: coverpoint out_packet[43:42]
            iff (rst_n && out_valid && out_ready) {

            bins vibration   = {2'b00};
            bins temperature = {2'b01};
            bins emergency   = {2'b10};

            illegal_bins reserved_channel = {2'b11};
        }


        // -------------------------------------
        // 2. Packet type coverage
        // -------------------------------------

        cp_packet_type: coverpoint out_packet[41:40]
            iff (rst_n && out_valid && out_ready) {

            bins type_0 = {2'b00};
            bins type_1 = {2'b01};
            bins type_2 = {2'b10};
            bins type_3 = {2'b11};
        }


        // -------------------------------------
        // 3. Channel x packet type
        // -------------------------------------

        channel_type_cross:
            cross cp_channel, cp_packet_type;


        // -------------------------------------
        // 4. Output backpressure
        // -------------------------------------

        cp_backpressure: coverpoint
            (out_valid && !out_ready)
            iff (rst_n) {

            bins stall_observed = {1'b1};
        }


        // -------------------------------------
        // 5. Buffer full status
        // -------------------------------------

        cp_buffer_full: coverpoint buffer_full
            iff (rst_n) {

            bins no_buffer_full = {3'b000};

            bins one_or_more_full = {
                3'b001, 3'b010, 3'b011,
                3'b100, 3'b101, 3'b110, 3'b111
            };
        }


        // -------------------------------------
        // 6. Buffer empty status
        // -------------------------------------

        cp_buffer_empty: coverpoint buffer_empty
            iff (rst_n) {

            bins no_buffer_empty = {3'b000};

            bins one_or_more_empty = {
                3'b001, 3'b010, 3'b011,
                3'b100, 3'b101, 3'b110, 3'b111
            };
        }


        // -------------------------------------
        // 7. Simultaneous full and empty
        // -------------------------------------

        cp_buffer_state: coverpoint {
            (|buffer_full),
            (|buffer_empty)
        } iff (rst_n) {

            bins both_inactive = {2'b00};
            bins full_only     = {2'b10};
            bins empty_only    = {2'b01};
            bins both_active   = {2'b11};
        }
        
                // -------------------------------------
        // 8. Actual scheduler grant
        // -------------------------------------

        cp_scheduler_grant: coverpoint selected_grant
            iff (rst_n && out_valid && out_ready) {

            bins vibration   = {2'd0};
            bins temperature = {2'd1};
            bins emergency   = {2'd2};

            illegal_bins invalid_grant = {2'd3};
        }


               // -------------------------------------
        // 9. Contention conditions
        // -------------------------------------

        cp_contention: coverpoint {
            sched_in_valid[2],
            (|sched_in_valid[1:0])
        } iff (rst_n && out_valid && out_ready) {

            bins normal_only          = {2'b01};
            bins emergency_only       = {2'b10};
            bins emergency_and_normal = {2'b11};
        }


        // Separately observe scheduler idle conditions.
        cp_scheduler_idle: coverpoint (|sched_in_valid)
            iff (rst_n) {

            bins scheduler_idle    = {1'b0};
            bins scheduler_active  = {1'b1};
        }


        // -------------------------------------
        // 10. Grant x contention
        // -------------------------------------

        grant_contention_cross:
            cross cp_scheduler_grant, cp_contention {

            // Emergency cannot be granted when only normal
            // channels have valid packets.
            ignore_bins emergency_without_emergency_input =
                binsof(cp_scheduler_grant.emergency) &&
                binsof(cp_contention.normal_only);

            // Normal channels cannot be granted when only
            // the emergency channel has a valid packet.
            ignore_bins vibration_without_normal_input =
                binsof(cp_scheduler_grant.vibration) &&
                binsof(cp_contention.emergency_only);

            ignore_bins temperature_without_normal_input =
                binsof(cp_scheduler_grant.temperature) &&
                binsof(cp_contention.emergency_only);
        }


        // -------------------------------------
        // 11. Normal channel round-robin
        // -------------------------------------

        cp_normal_grant: coverpoint selected_grant
            iff (rst_n && out_valid && out_ready &&
                 selected_grant != 2'd2) {

            bins vibration_to_temperature =
                (2'd0 => 2'd1);

            bins temperature_to_vibration =
                (2'd1 => 2'd0);
        }


        // -------------------------------------
        // 12. Emergency burst sequence
        // -------------------------------------

        cp_emergency_burst: coverpoint selected_grant
            iff (rst_n && out_valid && out_ready) {

            bins two_emergency_then_vibration =
                (2'd2 => 2'd2 => 2'd0);

            bins two_emergency_then_temperature =
                (2'd2 => 2'd2 => 2'd1);
        }


        // -------------------------------------
        // 13. Grant lock during backpressure
        // -------------------------------------

        cp_grant_lock: coverpoint grant_locked
            iff (rst_n && out_valid && !out_ready) {

            bins grant_locked_during_stall = {1'b1};
        }

    endgroup


    // =========================================
    // COVERAGE INSTANCE
    // =========================================

    telemetry_cg telemetry_cg_inst = new();


// =========================================
// COVERAGE DIAGNOSTIC COUNTERS
// =========================================

integer buffer_state_count[0:3] = '{default:0};

integer emergency_vib_count = 0;
integer emergency_temp_count = 0;

integer grant_normal_only_count = 0;
integer grant_emergency_only_count = 0;
integer grant_both_count = 0;


integer gc_count[0:2][1:3] = '{default:0};
// =========================================
// COVERAGE DIAGNOSTIC MONITOR
// =========================================

always @(posedge clk) begin

    if (rst_n) begin

        // Buffer state diagnostics
        buffer_state_count[
            {(|buffer_full), (|buffer_empty)}
        ]++;

        // Grant and contention diagnostics
        if (out_valid && out_ready) begin

            case ({sched_in_valid[2],
                   (|sched_in_valid[1:0])})

                2'b01:
                    grant_normal_only_count++;

                2'b10:
                    grant_emergency_only_count++;

                2'b11:
                    grant_both_count++;

                default: ;
            endcase
if (selected_grant <= 2 &&
    {sched_in_valid[2], (|sched_in_valid[1:0])} >= 1 &&
    {sched_in_valid[2], (|sched_in_valid[1:0])} <= 3) begin

    gc_count[selected_grant]
            [{sched_in_valid[2], (|sched_in_valid[1:0])}]++;
end
            // Emergency burst diagnostics
            // The actual transition bins remain in the covergroup.
        end

    end

end

task print_detailed_coverage;

begin

    $display("\n========== COVERAGE BIN DIAGNOSTICS ==========");

    $display("\nBuffer State Counts:");
    $display("  00 Both inactive : %0d", buffer_state_count[0]);
    $display("  01 Empty only    : %0d", buffer_state_count[1]);
    $display("  10 Full only     : %0d", buffer_state_count[2]);
    $display("  11 Both active   : %0d", buffer_state_count[3]);

    $display("\nGrant/Contention Observations:");
    $display("  Normal only      : %0d", grant_normal_only_count);
    $display("  Emergency only   : %0d", grant_emergency_only_count);
    $display("  Both             : %0d", grant_both_count);

    $display("\nEmergency Burst Coverage:");
    $display("  Two emergency then vibration : Check covergroup");
    $display("  Two emergency then temperature: Check covergroup");
    $display("\nGrant x Contention Bin Counts:");

$display("Vibration   : Normal=%0d Both=%0d",
         gc_count[0][1], gc_count[0][3]);

$display("Temperature : Normal=%0d Both=%0d",
         gc_count[1][1], gc_count[1][3]);

$display("Emergency   : Emergency=%0d Both=%0d",
         gc_count[2][2], gc_count[2][3]);

    $display("===============================================");

end

endtask

    // =========================================
    // COVERAGE REPORT
    // =========================================

   task print_report;

begin

    $display("\n");
    $display("==========================================");
    $display("       TELEMETRY FUNCTIONAL COVERAGE");
    $display("==========================================");

    $display("Overall Coverage          : %0.2f%%",
             telemetry_cg_inst.get_coverage());

    $display("------------------------------------------");
    $display("Individual Coverpoint Coverage");
    $display("------------------------------------------");

    $display("Channel                   : %0.2f%%",
             telemetry_cg_inst.cp_channel.get_coverage());

    $display("Packet Type               : %0.2f%%",
             telemetry_cg_inst.cp_packet_type.get_coverage());

    $display("Channel x Packet Type     : %0.2f%%",
             telemetry_cg_inst.channel_type_cross.get_coverage());

    $display("Backpressure              : %0.2f%%",
             telemetry_cg_inst.cp_backpressure.get_coverage());

    $display("Buffer Full               : %0.2f%%",
             telemetry_cg_inst.cp_buffer_full.get_coverage());

    $display("Buffer Empty              : %0.2f%%",
             telemetry_cg_inst.cp_buffer_empty.get_coverage());

    $display("Buffer State              : %0.2f%%",
             telemetry_cg_inst.cp_buffer_state.get_coverage());

    $display("Scheduler Grant           : %0.2f%%",
             telemetry_cg_inst.cp_scheduler_grant.get_coverage());

    $display("Contention                : %0.2f%%",
             telemetry_cg_inst.cp_contention.get_coverage());

    $display("Grant x Contention        : %0.2f%%",
             telemetry_cg_inst.grant_contention_cross.get_coverage());

    $display("Normal Round Robin        : %0.2f%%",
             telemetry_cg_inst.cp_normal_grant.get_coverage());

    $display("Emergency Burst           : %0.2f%%",
             telemetry_cg_inst.cp_emergency_burst.get_coverage());

    $display("Grant Lock                : %0.2f%%",
             telemetry_cg_inst.cp_grant_lock.get_coverage());
    $display("Scheduler Idle            : %0.2f%%",
             telemetry_cg_inst.cp_scheduler_idle.get_coverage());

    $display("==========================================");

end

endtask

endmodule
