
`timescale 1ns/1ps

module reference_scoreboard #(
    parameter PACKET_WIDTH = 44
)(
    input logic rst_n,

    // Independent input clock domains
    input logic vibration_clk,
    input logic temperature_clk,
    input logic emergency_clk,

    // Input handshakes
    input logic vibration_valid,
    input logic vibration_ready,
    input logic [PACKET_WIDTH-1:0] vibration_packet,

    input logic temperature_valid,
    input logic temperature_ready,
    input logic [PACKET_WIDTH-1:0] temperature_packet,

    input logic emergency_valid,
    input logic emergency_ready,
    input logic [PACKET_WIDTH-1:0] emergency_packet,

    // Scheduler/output clock domain
    input logic scheduler_clk,
    input logic out_valid,
    input logic out_ready,
    input logic [PACKET_WIDTH-1:0] out_packet,

    // Scoreboard results
    output integer accepted_count,
    output integer received_count,
    output integer error_count,
    output integer pending_count
);

    // One expected queue per input channel
    logic [PACKET_WIDTH-1:0] vibration_expected[$];
    logic [PACKET_WIDTH-1:0] temperature_expected[$];
    logic [PACKET_WIDTH-1:0] emergency_expected[$];

    integer vibration_accepted;
    integer temperature_accepted;
    integer emergency_accepted;

    // ------------------------------------------------
    // Record accepted vibration packets
    // ------------------------------------------------
    always @(posedge vibration_clk or negedge rst_n) begin
        if (!rst_n) begin
            vibration_expected.delete();
            vibration_accepted = 0;
        end
        else if (vibration_valid && vibration_ready) begin
            vibration_expected.push_back(vibration_packet);
            vibration_accepted = vibration_accepted + 1;
        end
    end

    // ------------------------------------------------
    // Record accepted temperature packets
    // ------------------------------------------------
    always @(posedge temperature_clk or negedge rst_n) begin
        if (!rst_n) begin
            temperature_expected.delete();
            temperature_accepted = 0;
        end
        else if (temperature_valid && temperature_ready) begin
            temperature_expected.push_back(temperature_packet);
            temperature_accepted = temperature_accepted + 1;
        end
    end

    // ------------------------------------------------
    // Record accepted emergency packets
    // ------------------------------------------------
    always @(posedge emergency_clk or negedge rst_n) begin
        if (!rst_n) begin
            emergency_expected.delete();
            emergency_accepted = 0;
        end
        else if (emergency_valid && emergency_ready) begin
            emergency_expected.push_back(emergency_packet);
            emergency_accepted = emergency_accepted + 1;
        end
    end

    // ------------------------------------------------
    // Compare every output handshake against its
    // corresponding channel's expected queue
    // ------------------------------------------------
    always @(posedge scheduler_clk or negedge rst_n) begin
        if (!rst_n) begin
            received_count = 0;
            error_count = 0;
        end
        else if (out_valid && out_ready) begin

            received_count = received_count + 1;

            case (out_packet[43:42])

                // Vibration channel
                2'd0: begin
                    if (vibration_expected.size() == 0) begin
                        $error(
                            "[SCOREBOARD] Unexpected vibration packet: %h",
                            out_packet
                        );
                        error_count = error_count + 1;
                    end
                    else begin
                        if (out_packet !== vibration_expected[0]) begin
                            $error(
                                "[SCOREBOARD] Vibration mismatch. Expected=%h Actual=%h",
                                vibration_expected[0],
                                out_packet
                            );
                            error_count = error_count + 1;
                        end
                        else begin
                            $display(
                                "[SCOREBOARD PASS] Vibration packet matched: %h",
                                out_packet
                            );
                        end

                        vibration_expected.pop_front();
                    end
                end

                // Temperature channel
                2'd1: begin
                    if (temperature_expected.size() == 0) begin
                        $error(
                            "[SCOREBOARD] Unexpected temperature packet: %h",
                            out_packet
                        );
                        error_count = error_count + 1;
                    end
                    else begin
                        if (out_packet !== temperature_expected[0]) begin
                            $error(
                                "[SCOREBOARD] Temperature mismatch. Expected=%h Actual=%h",
                                temperature_expected[0],
                                out_packet
                            );
                            error_count = error_count + 1;
                        end
                        else begin
                            $display(
                                "[SCOREBOARD PASS] Temperature packet matched: %h",
                                out_packet
                            );
                        end

                        temperature_expected.pop_front();
                    end
                end

                // Emergency channel
                2'd2: begin
                    if (emergency_expected.size() == 0) begin
                        $error(
                            "[SCOREBOARD] Unexpected emergency packet: %h",
                            out_packet
                        );
                        error_count = error_count + 1;
                    end
                    else begin
                        if (out_packet !== emergency_expected[0]) begin
                            $error(
                                "[SCOREBOARD] Emergency mismatch. Expected=%h Actual=%h",
                                emergency_expected[0],
                                out_packet
                            );
                            error_count = error_count + 1;
                        end
                        else begin
                            $display(
                                "[SCOREBOARD PASS] Emergency packet matched: %h",
                                out_packet
                            );
                        end

                        emergency_expected.pop_front();
                    end
                end

                default: begin
                    $error(
                        "[SCOREBOARD] Invalid channel ID in packet: %h",
                        out_packet
                    );
                    error_count = error_count + 1;
                end

            endcase
        end
    end

    // ------------------------------------------------
    // Summary counters
    // ------------------------------------------------
    always_comb begin
        accepted_count =
            vibration_accepted +
            temperature_accepted +
            emergency_accepted;

        pending_count =
            vibration_expected.size() +
            temperature_expected.size() +
            emergency_expected.size();
    end

endmodule
