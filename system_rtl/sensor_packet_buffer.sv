
module sensor_packet_buffer #(
    parameter PACKET_WIDTH = 44,
    parameter ADDR_WIDTH   = 4
)(
    // Independent clock domains
    input  logic                   wr_clk,
    input  logic                   rd_clk,
    input  logic                   rst_n,

    // Sensor-side packet interface
    input  logic                   in_valid,
    output logic                   in_ready,
    input  logic [PACKET_WIDTH-1:0] packet_in,

    // Output-side packet interface
    output logic                   out_valid,
    input  logic                   out_ready,
    output logic [PACKET_WIDTH-1:0] packet_out,

    // FIFO status
    output logic                   full,
    output logic                   empty
);

    // Internal FIFO signals
    logic [PACKET_WIDTH-1:0] fifo_data_out;
    logic fifo_wr_en;
    logic fifo_rd_en;

    // Tracks the synchronous FIFO read operation
    logic rd_pending;

    // ------------------------------------------------
    // INPUT SIDE: Write complete packets into FIFO
    // ------------------------------------------------

    assign in_ready = !full;

    assign fifo_wr_en = in_valid && in_ready;

    // ------------------------------------------------
    // OUTPUT SIDE: Read packets from FIFO
    // ------------------------------------------------

    // Read only when:
    // 1. FIFO contains data
    // 2. No previous read is awaiting capture
    // 3. Output register is available

    assign fifo_rd_en =
        !empty &&
        !rd_pending &&
        (!out_valid || out_ready);

    // ------------------------------------------------
    // Existing asynchronous FIFO
    // ------------------------------------------------

    async_fifo #(
        .DATA_WIDTH(PACKET_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_packet_fifo (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .rst_n(rst_n),

        .wr_en(fifo_wr_en),
        .rd_en(fifo_rd_en),

        .data_in(packet_in),
        .data_out(fifo_data_out),

        .full(full),
        .empty(empty)
    );

    // ------------------------------------------------
    // Output staging register
    // Handles synchronous FIFO read latency
    // ------------------------------------------------

    always_ff @(posedge rd_clk or negedge rst_n) begin

        if (!rst_n) begin
            packet_out <= '0;
            out_valid  <= 1'b0;
            rd_pending <= 1'b0;
        end

        else begin

            // Receiver accepted the previous packet
            if (out_valid && out_ready) begin
                out_valid <= 1'b0;
            end

            // Capture FIFO data from the previous read
            if (rd_pending) begin
                packet_out <= fifo_data_out;
                out_valid  <= 1'b1;
                rd_pending <= 1'b0;
            end

            // Issue a new FIFO read
            if (fifo_rd_en) begin
                rd_pending <= 1'b1;
            end

        end
    end

endmodule
