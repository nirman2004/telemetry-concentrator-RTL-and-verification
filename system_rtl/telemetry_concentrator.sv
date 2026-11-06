
`timescale 1ns/1ps

module telemetry_concentrator #(
    parameter PACKET_WIDTH = 44,
    parameter ADDR_WIDTH   = 4,
    parameter MAX_EMERGENCY_BURST = 2
)(
    // Independent sensor clocks
    input logic vibration_clk,
    input logic temperature_clk,
    input logic emergency_clk,

    // Common scheduler / read clock
    input logic scheduler_clk,

    input logic rst_n,

    // Vibration input
    input logic vibration_valid,
    output logic vibration_ready,
    input logic [PACKET_WIDTH-1:0] vibration_packet,

    // Temperature input
    input logic temperature_valid,
    output logic temperature_ready,
    input logic [PACKET_WIDTH-1:0] temperature_packet,

    // Emergency input
    input logic emergency_valid,
    output logic emergency_ready,
    input logic [PACKET_WIDTH-1:0] emergency_packet,

    // Shared output interface
    output logic out_valid,
    input logic out_ready,
    output logic [PACKET_WIDTH-1:0] out_packet,

    // FIFO status: [2]=emergency, [1]=temperature, [0]=vibration
    output logic [2:0] buffer_full,
    output logic [2:0] buffer_empty
);

    // -----------------------------------------
    // Internal buffer-to-scheduler connections
    // -----------------------------------------

    logic [2:0] buffer_out_valid;
    logic [2:0] buffer_out_ready;

    logic [PACKET_WIDTH-1:0] vibration_buffer_packet;
    logic [PACKET_WIDTH-1:0] temperature_buffer_packet;
    logic [PACKET_WIDTH-1:0] emergency_buffer_packet;

    // -----------------------------------------
    // Vibration packet buffer
    // -----------------------------------------

    sensor_packet_buffer #(
        .PACKET_WIDTH(PACKET_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_vibration_buffer (
        .wr_clk(vibration_clk),
        .rd_clk(scheduler_clk),
        .rst_n(rst_n),

        .in_valid(vibration_valid),
        .in_ready(vibration_ready),
        .packet_in(vibration_packet),

        .out_valid(buffer_out_valid[0]),
        .out_ready(buffer_out_ready[0]),
        .packet_out(vibration_buffer_packet),

        .full(buffer_full[0]),
        .empty(buffer_empty[0])
    );

    // -----------------------------------------
    // Temperature packet buffer
    // -----------------------------------------

    sensor_packet_buffer #(
        .PACKET_WIDTH(PACKET_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_temperature_buffer (
        .wr_clk(temperature_clk),
        .rd_clk(scheduler_clk),
        .rst_n(rst_n),

        .in_valid(temperature_valid),
        .in_ready(temperature_ready),
        .packet_in(temperature_packet),

        .out_valid(buffer_out_valid[1]),
        .out_ready(buffer_out_ready[1]),
        .packet_out(temperature_buffer_packet),

        .full(buffer_full[1]),
        .empty(buffer_empty[1])
    );

    // -----------------------------------------
    // Emergency packet buffer
    // -----------------------------------------

    sensor_packet_buffer #(
        .PACKET_WIDTH(PACKET_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_emergency_buffer (
        .wr_clk(emergency_clk),
        .rd_clk(scheduler_clk),
        .rst_n(rst_n),

        .in_valid(emergency_valid),
        .in_ready(emergency_ready),
        .packet_in(emergency_packet),

        .out_valid(buffer_out_valid[2]),
        .out_ready(buffer_out_ready[2]),
        .packet_out(emergency_buffer_packet),

        .full(buffer_full[2]),
        .empty(buffer_empty[2])
    );

    // -----------------------------------------
    // Priority-aware packet scheduler
    // -----------------------------------------

    packet_scheduler #(
        .PACKET_WIDTH(PACKET_WIDTH),
        .MAX_EMERGENCY_BURST(MAX_EMERGENCY_BURST)
    ) u_packet_scheduler (
        .clk(scheduler_clk),
        .rst_n(rst_n),

        .in_valid(buffer_out_valid),

        .vibration_packet(vibration_buffer_packet),
        .temperature_packet(temperature_buffer_packet),
        .emergency_packet(emergency_buffer_packet),

        .in_ready(buffer_out_ready),

        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_packet(out_packet)
    );

endmodule
