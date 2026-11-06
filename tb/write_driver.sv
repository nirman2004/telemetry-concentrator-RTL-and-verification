
module fifo_write_driver #(
    parameter DATA_WIDTH = 8
)(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 full,

    output logic                 wr_en,
    output logic [DATA_WIDTH-1:0] data_in
);

    // Initialize driver outputs
    initial begin
        wr_en   = 1'b0;
        data_in = '0;
    end

    // Drive one write transaction
    task automatic drive_write(
        input logic [DATA_WIDTH-1:0] data
    );

        // Wait for a safe driving edge
        @(negedge clk);

        // Wait until reset is released and FIFO has space
        while ((rst_n !== 1'b1) || (full !== 1'b0))
            @(negedge clk);

        // Apply write request
        data_in = data;
        wr_en   = 1'b1;

        // DUT samples the write request here
        @(posedge clk);

        // Deassert write enable at the next falling edge
        @(negedge clk);
        wr_en = 1'b0;

    endtask

    // Drive write idle cycles
    task automatic idle_write(
        input integer cycles
    );

        repeat (cycles) begin
            @(negedge clk);
            wr_en = 1'b0;
        end

    endtask
    
    task automatic attempt_write_while_full(input logic [DATA_WIDTH-1:0] data);
    @(negedge clk);
    if (full) begin
        data_in = data;
        wr_en = 1'b1;
        @(posedge clk);
        @(negedge clk);
        wr_en = 1'b0;
        $display("[TEST] Write attempted while FULL");
    end
    else begin
        $error("[FAIL] FIFO was not FULL during blocked-write test");
    end
endtask

endmodule
