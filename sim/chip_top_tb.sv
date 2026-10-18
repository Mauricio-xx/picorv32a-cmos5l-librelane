// SPDX-License-Identifier: Apache-2.0
`timescale 1ns/1ps
module chip_top_tb;
    reg clk = 0;
    reg rst_n = 0;
    reg [7:0] inputs = 0;
    reg [3:0] bidir_inputs = 0;
    wire [7:0] outputs;
    wire clk_pad = clk;
    wire rst_n_pad = rst_n;
    wire [7:0] input_pads = inputs;
    tri [7:0] bidirs;
    assign bidirs[3:0] = bidir_inputs;
    always #50 clk = ~clk;

    chip_top dut (
        .clk_PAD(clk_pad), .rst_n_PAD(rst_n_pad), .input_PAD(input_pads),
        .output_PAD(outputs), .bidir_PAD(bidirs)
    );

    task check_gpio(input [7:0] value, input [3:0] bidir_value);
        begin
            @(negedge clk);
            inputs = value;
            bidir_inputs = bidir_value;
            repeat (150) @(negedge clk);
            if (outputs !== (value ^ {4'b0, bidir_value}))
                $fatal(1, "GPIO mismatch: got %h", outputs);
            if (bidirs[7] !== 1'b0) $fatal(1, "CPU trapped");
            if (bidirs[3:0] !== bidir_value) $fatal(1, "Input pads are driven");
        end
    endtask

    reg [2:0] old_heartbeat;
    initial begin
        repeat (5) @(negedge clk);
        if (outputs !== 0 || bidirs[6:4] !== 0) $fatal(1, "Reset failed");
        rst_n = 1;
        check_gpio(8'ha5, 4'h3);
        old_heartbeat = bidirs[6:4];
        // A firmware iteration takes less than 100 cycles; wait for a change.
        fork : heartbeat_check
            begin
                wait (bidirs[6:4] !== old_heartbeat);
            end
            begin
                repeat (100) @(negedge clk);
                $fatal(1, "Heartbeat stalled");
            end
        join_any
        disable heartbeat_check;
        check_gpio(8'h5a, 4'hc);
        check_gpio(8'hff, 4'hf);
        @(negedge clk); rst_n = 0;
        repeat (5) @(negedge clk);
        if (outputs !== 0 || bidirs[6:4] !== 0) $fatal(1, "Second reset failed");
        rst_n = 1;
        check_gpio(8'h42, 4'h7);
        $display("PASS: PicoRV32 firmware, GPIO, bidirectional pads, heartbeat and reset");
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Simulation timed out");
    end
endmodule
