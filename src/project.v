/*
 * Copyright (c) 2026 Kaoru Aguilera Katayama
 * SPDX-License-Identifier: Apache-2.0
 *
 * OMEGA INFINITY KAORU Processor
 * 3D Volumetric Engine: 256 x 256 x 256 Lattice (16,777,215 Variables)
 */

`default_nettype none

module tt_um_omega_infinity_kaoru (
    input  wire [7:0] ui_in,    // Dedicated inputs: Multi-byte stream / Data
    output wire [7:0] uo_out,   // Dedicated outputs: Decision flags & Assignment
    input  wire [7:0] uio_in,   // Bidirectional IOs: Control bus
    output wire [7:0] uio_out,  // Bidirectional IOs: Unused
    output wire [7:0] uio_oe,   // Bidirectional IOs: Direction control
    input  wire       ena,      // Power enable
    input  wire       clk,      // System clock
    input  wire       rst_n     // Active-low asynchronous reset
);

    // =========================================================================
    // Lattice Dimensions: 256 x 256 x 256 = 16,777,216 Nodes
    // Node (0,0,0) = Source (+)
    // Remaining Nodes = 16,777,215 Active Boolean Variables (Index 1 to 16,777,215)
    // Variable Coordinate Width: 3 axes * 8 bits = 24 bits (ADDR_W = 24)
    // =========================================================================
    localparam integer ADDR_W  = 24; // 2^24 = 16,777,216 addresses (3 bytes)
    localparam integer G       = 16; // 16 Programmable intermediate gates
    localparam integer GW      = 3;  // Opcode width (3 bits)
    localparam integer CACHE_K = 8;  // 8 Active evaluation taps cached in local registers

    // Formal Opcodes
    localparam [GW-1:0] OP_AND  = 3'd0;
    localparam [GW-1:0] OP_OR   = 3'd1;
    localparam [GW-1:0] OP_XOR  = 3'd2;
    localparam [GW-1:0] OP_XNOR = 3'd3;
    localparam [GW-1:0] OP_NAND = 3'd4;
    localparam [GW-1:0] OP_NOR  = 3'd5;
    localparam [GW-1:0] OP_NOT  = 3'd6;
    localparam [GW-1:0] OP_BUF  = 3'd7;

    // Control Interface (uio_in)
    wire       prog_en      = uio_in[0]; // 1 = Configuration / Stream mode, 0 = Execution mode
    wire       stream_addr  = uio_in[1]; // 1 = Shift 24-bit lattice address, 0 = Write gate
    wire       we_pulse     = uio_in[2]; // Write strobe
    wire       grid_stable  = uio_in[3]; // Signals volumetric relaxation settling flag
    wire [1:0] byte_sel     = uio_in[5:4]; // 2'b00: X (Addr[7:0]), 2'b01: Y (Addr[15:8]), 2'b10: Z (Addr[23:16])
    wire       var_val_in   = uio_in[6]; // Quantized threshold bit (0 or 1) for addressed node
    wire       load_tap_val = uio_in[7]; // Latches var_val_in into cached tap register

    // Gate configuration inputs
    wire [GW-1:0] prog_op   = ui_in[2:0];
    wire [4:0]    prog_a    = ui_in[7:3]; // Indices 0..7 = Taps, 8..23 = Gate outputs
    wire [4:0]    prog_b    = {2'b00, uio_in[5:4], ui_in[2]};

    // 24-bit 3D Lattice Addressing Engine
    reg [ADDR_W-1:0] active_3d_addr;
    reg [CACHE_K-1:0] cached_taps; // Active 3D lattice variables mapped to current SAT instance

    // Gate Configuration Memory
    reg [GW-1:0] gate_op  [0:G-1];
    reg [4:0]    gate_ina [0:G-1];
    reg [4:0]    gate_inb [0:G-1];
    reg [3:0]    gate_wr_ptr;
    reg [4:0]    out_gate;

    // Node Array: [7:0] = 3D Lattice Variables, [23:8] = Gate outputs
    reg [CACHE_K+G-1:0] node;

    // Decision Registers
    reg sat;
    reg unsat;
    reg done;

    // Pin Assignments
    assign uo_out[0]   = sat;
    assign uo_out[1]   = unsat;
    assign uo_out[2]   = done;
    assign uo_out[7:3] = cached_taps[4:0]; // Direct readout of satisfied lattice taps

    assign uio_oe  = 8'b00000000;
    assign uio_out = 8'b00000000;

    // -------------------------------------------------------------
    // Configuration & 24-Bit 3D Variable Ingestion
    // -------------------------------------------------------------
    integer p;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_3d_addr <= {ADDR_W{1'b0}};
            cached_taps    <= {CACHE_K{1'b0}};
            gate_wr_ptr    <= 4'd0;
            out_gate       <= 5'd8; // Default: Gate 0 output
            for (p = 0; p < G; p = p + 1) begin
                gate_op[p]  <= OP_BUF;
                gate_ina[p] <= 5'd0;
                gate_inb[p] <= 5'd0;
            end
        end else if (prog_en) begin
            if (stream_addr) begin
                // Stream 24-bit coordinate: (X, Y, Z) aligned in 3 clean bytes
                case (byte_sel)
                    2'b00: active_3d_addr[7:0]   <= ui_in; // X coordinate (0..255)
                    2'b01: active_3d_addr[15:8]  <= ui_in; // Y coordinate (0..255)
                    2'b10: active_3d_addr[23:16] <= ui_in; // Z coordinate (0..255)
                    default: ;
                endcase
            end else if (load_tap_val) begin
                // Latch quantized node bit from (X, Y, Z) into tap cache
                cached_taps <= {cached_taps[CACHE_K-2:0], var_val_in};
            end else if (we_pulse) begin
                // Write gate descriptor in topological order
                if (gate_wr_ptr < G) begin
                    gate_op[gate_wr_ptr]  <= prog_op;
                    gate_ina[gate_wr_ptr] <= prog_a;
                    gate_inb[gate_wr_ptr] <= prog_b;
                    gate_wr_ptr           <= gate_wr_ptr + 1'b1;
                end
            end else begin
                out_gate <= prog_a;
            end
        end
    end

    // -------------------------------------------------------------
    // Combinational DAG Evaluation Network
    // -------------------------------------------------------------
    integer k;
    reg a_val, b_val;
    always @(*) begin
        node[CACHE_K-1:0] = cached_taps;
        for (k = 0; k < G; k = k + 1) begin
            a_val = node[gate_ina[k]];
            b_val = node[gate_inb[k]];
            case (gate_op[k])
                OP_AND : node[CACHE_K+k] = a_val & b_val;
                OP_OR  : node[CACHE_K+k] = a_val | b_val;
                OP_XOR : node[CACHE_K+k] = a_val ^ b_val;
                OP_XNOR: node[CACHE_K+k] = a_val ~^ b_val;
                OP_NAND: node[CACHE_K+k] = ~(a_val & b_val);
                OP_NOR : node[CACHE_K+k] = ~(a_val | b_val);
                OP_NOT : node[CACHE_K+k] = ~a_val;
                default: node[CACHE_K+k] = a_val;
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
