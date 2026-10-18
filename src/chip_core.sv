// SPDX-License-Identifier: Apache-2.0
`default_nettype none

// ROM-only RV32I GPIO demonstrator. No SRAM macro or external firmware is needed.
module chip_core (
    input wire clk,
    input wire rst_n,
    input wire [7:0] input_in,
    output reg [7:0] output_out,
    input wire [7:0] bidir_in,
    output wire [7:0] bidir_out,
    output wire [7:0] bidir_oe
);
    wire trap;
    wire mem_valid;
    wire [31:0] mem_addr, mem_wdata;
    wire [3:0] mem_wstrb;
    reg [31:0] mem_rdata;
    reg [2:0] heartbeat;

    // Lower four bidirectional pads are inputs; upper four are status outputs.
    assign bidir_oe = 8'hf0;
    assign bidir_out = {trap, heartbeat, 4'b0000};

    picorv32 #(
        .ENABLE_COUNTERS(0),
        .ENABLE_COUNTERS64(0),
        .PROGADDR_RESET(32'h00000000)
    ) cpu (
        .clk(clk), .resetn(rst_n), .trap(trap),
        .mem_valid(mem_valid), .mem_instr(),
        .mem_ready(mem_valid), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .mem_la_read(), .mem_la_write(), .mem_la_addr(),
        .mem_la_wdata(), .mem_la_wstrb(),
        .pcpi_valid(), .pcpi_insn(), .pcpi_rs1(), .pcpi_rs2(),
        .pcpi_wr(1'b0), .pcpi_rd(32'b0),
        .pcpi_wait(1'b0), .pcpi_ready(1'b0),
        .irq(32'b0), .eoi(), .trace_valid(), .trace_data()
    );

    // Built-in program: copy input GPIO XOR the four input bidir pads to output
    // GPIO, then increment a heartbeat. All instructions are plain RV32I.
    always @* begin
        case (mem_addr)
            32'h00000000: mem_rdata = 32'h100000b7; // lui  x1, 0x10000
            32'h00000004: mem_rdata = 32'h00000193; // addi x3, x0, 0
            32'h00000008: mem_rdata = 32'h0000a103; // lw   x2, 0(x1)
            32'h0000000c: mem_rdata = 32'h0020a223; // sw   x2, 4(x1)
            32'h00000010: mem_rdata = 32'h00118193; // addi x3, x3, 1
            32'h00000014: mem_rdata = 32'h0030a423; // sw   x3, 8(x1)
            32'h00000018: mem_rdata = 32'hff1ff06f; // jal  x0, -16
            32'h10000000: mem_rdata = {24'b0, input_in ^ {4'b0, bidir_in[3:0]}};
            default: mem_rdata = 32'h00100073; // ebreak: trap on an invalid fetch
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            output_out <= 0;
            heartbeat <= 0;
        end else if (mem_valid && mem_wstrb[0]) begin
            case (mem_addr)
                32'h10000004: output_out <= mem_wdata[7:0];
                32'h10000008: heartbeat <= mem_wdata[2:0];
                default: begin end
            endcase
        end
    end
endmodule
`default_nettype wire
