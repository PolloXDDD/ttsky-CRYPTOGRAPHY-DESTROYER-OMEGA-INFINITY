/*
 * Copyright (c) 2026 Kaoru Aguilera Katayama
 * SPDX-License-Identifier: Apache-2.0
 *
 * OMEGA INFINITY KAORU Processor
 * Universal Programmable Circuit-SAT Engine (RTL)
 */

`default_nettype none

module tt_um_omega_infinity_kaoru (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // Bidirectional IOs: Input path
    output wire [7:0] uio_out,  // Bidirectional IOs: Output path
    output wire [7:0] uio_oe,   // Bidirectional IOs: Output Enable path
    input  wire       ena,      // Power enable (always 1)
    input  wire       clk,      // System clock
    input  wire       rst_n     // Active-low asynchronous reset
);

    // Architectural parameters
    localparam integer N  = 8;  // 8 Boolean input variables (v0..v7)
    localparam integer G  = 24; // 24 Arbitrary programmable gates (g0..g23)
    localparam integer GW = 3;  // Opcode width (3 bits)
    localparam integer IW = 5;  // Node index width: ceil(log2(N + G)) = 5 bits (0..31)

    // Supported Boolean Gate Opcodes
    localparam [GW-1:0] OP_AND  = 3'd0;
    localparam [GW-1:0] OP_OR   = 3'd1;
    localparam [GW-1:0] OP_XOR  = 3'd2;
    localparam [GW-1:0] OP_XNOR = 3'd3;
    localparam [GW-1:0] OP_NAND = 3'd4;
    localparam [GW-1:0] OP_NOR  = 3'd5;
    localparam [GW-1:0] OP_NOT  = 3'd6; // Uses Operand A only
    localparam [GW-1:0] OP_BUF  = 3'd7; // Uses Operand A only

    // Control Interface (uio_in)
    wire          prog_en      = uio_in[0]; // 1 = Programming Mode, 0 = Evaluation Mode
    wire          prog_we      = uio_in[1]; // Write strobe: latches gate descriptor & increments pointer
    wire          prog_rst_ptr = uio_in[2]; // Resets gate write pointer to 0
    wire          grid_stable  = uio_in[3]; // Latch trigger: signals that inputs have settled
    wire [IW-1:0] prog_b_in    = uio_in[7:4] == 4'b0000 ? 5'd0 : {1'b0, uio_in[7:4]}; 
    wire [IW-1:0] cfg_out_gate = {1'b0, uio_in[7:4]};

    // Programming / Evaluation multiplexed inputs
    wire [GW-1:0] prog_op = ui_in[2:0];
    wire [IW-1:0] prog_a  = ui_in[7:3];
    wire [N-1:0]  grid_taps = ui_in; // In Evaluation Mode, all 8 pins are Boolean variables v0..v7

    // Programmable Instance Configuration Memory
    reg [GW-1:0] gate_op  [0:G-1];
    reg [IW-1:0] gate_ina [0:G-1];
    reg [IW-1:0] gate_inb [0:G-1];
    reg [IW-1:0] out_gate;
    reg [4:0]    gate_wr_ptr;

    // Node Array: [7:0] = Input Variables, [31:8] = Gate Outputs
    reg [N+G-1:0] node;

    // Decision Registers
    reg sat;
    reg unsat;
    reg done;

    // Output assignments
    assign uo_out[0]   = sat;
    assign uo_out[1]   = unsat;
    assign uo_out[2]   = done;
    assign uo_out[7:3] = prog_en ? gate_wr_ptr : node[7:3];

    // Configure bidirectional pins as dedicated inputs
    assign uio_oe  = 8'b00000000;
    assign uio_out = 8'b00000000;

    // -------------------------------------------------------------
    // Programming Plane: Universal In-System Configuration
    // -------------------------------------------------------------
    integer p;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gate_wr_ptr <= 5'd0;
            out_gate    <= 5'd0;
            for (p = 0; p < G; p = p + 1) begin
                gate_op[p]  <= OP_BUF;
                gate_ina[p] <= 5'd0;
                gate_inb[p] <= 5'd0;
            end
        end else if (prog_en) begin
            if (prog_rst_ptr) begin
                gate_wr_ptr <= 5'd0;
            end else if (prog_we) begin
                if (gate_wr_ptr < G) begin
                    gate_op[gate_wr_ptr]  <= prog_op;
                    gate_ina[gate_wr_ptr] <= prog_a;
                    gate_inb[gate_wr_ptr] <= prog_b_in;
                    gate_wr_ptr           <= gate_wr_ptr + 1'b1;
                end
            end else begin
                out_gate <= cfg_out_gate;
            end
        end
    end

    // -------------------------------------------------------------
    // Combinational Evaluation: Immediate DAG Reduction
    // -------------------------------------------------------------
    integer k;
    reg a_val, b_val;
    always @(*) begin
        node[N-1:0] = grid_taps;
        for (k = 0; k < G; k = k + 1) begin
            a_val = node[gate_ina[k]];
            b_val = node[gate_inb[k]];
            case (gate_op[k])
                OP_AND : node[N+k] = a_val & b_val;
                OP_OR  : node[N+k] = a_val | b_val;
                OP_XOR : node[N+k] = a_val ^ b_val;
                OP_XNOR: node[N+k] = a_val ~^ b_val;
                OP_NAND: node[N+k] = ~(a_val & b_val);
                OP_NOR : node[N+k] = ~(a_val | b_val);
                OP_NOT : node[N+k] = ~a_val;
                default: node[N+k] = a_val; // OP_BUF
            endcase
        end
    end

    // -------------------------------------------------------------
    // Decision Capture Stage
    // -------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sat   <= 1'b0;
            unsat <= 1'b0;
            done  <= 1'b0;
        end else if (prog_en) begin
            done  <= 1'b0;
            sat   <= 1'b0;
            unsat <= 1'b0;
        end else if (grid_stable) begin
            sat   <=  node[out_gate];
            unsat <= ~node[out_gate];
            done  <= 1'b1;
        end
    end

endmodule
