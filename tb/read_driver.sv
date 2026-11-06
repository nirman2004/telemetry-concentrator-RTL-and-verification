
module fifo_read_driver #(
    parameter DATA_WIDTH = 8
)(
    input  logic clk,
    input  logic rst_n,
    input  logic empty,

    output logic rd_en
);

    // Initialize driver output
    initial begin
        rd_en = 1'b0;
    end

    // Drive one read transaction
    task automatic drive_read();

        // Wait for a safe driving edge
        @(negedge clk);

        // Wait until reset is released and FIFO has data
        while ((rst_n !== 1'b1) || (empty !== 1'b0))
            @(negedge clk);

        // Apply read request
        rd_en = 1'b1;

        // DUT samples the read request here
        @(posedge clk);

        // Deassert read enable at the next falling edge
        @(negedge clk);
        rd_en = 1'b0;

    endtask

    // Drive read idle cycles
    task automatic idle_read(
        input integer cycles
    );

        repeat (cycles) begin
            @(negedge clk);
            rd_en = 1'b0;
        end

    endtask
task automatic attempt_read_while_empty();
    @(negedge clk);
    if (empty) begin
        rd_en = 1'b1;
        @(posedge clk);
        @(negedge clk);
        rd_en = 1'b0;
        $display("[TEST] Read attempted while EMPTY");
    end
    else begin
        $error("[FAIL] FIFO was not EMPTY during blocked-read test");
    end
endtask
endmodule
