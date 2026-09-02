/*
 * Copyright (c) 2026 Kaoru Aguilera Katayama
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_omega_infinity_kaoru (
    input  wire [7:0] ui_in,    // [2:0] prog_op, [7:3] prog_a
    output wire [7:0] uo_out,   // [0] SAT, [1] UNSAT, [2] DONE, [7:3] tap_out
    input  wire [7:0] uio_in,   // [0] prog_en, [1] prog_we, [3] grid_stable, [7:4] prog_b
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // -------------------------------------------------------------------------
    // Pines bidireccionales en modo entrada pasiva
    // -------------------------------------------------------------------------
    assign uio_out = 8'b0000_0000;
    assign uio_oe  = 8'b0000_0000;

    // -------------------------------------------------------------------------
    // Decodificación de buses de control y programación
    // -------------------------------------------------------------------------
    wire [2:0] prog_op = ui_in[2:0];
    wire [4:0] prog_a  = ui_in[7:3];
    wire [3:0] prog_b  = uio_in[7:4];
    wire       prog_en = uio_in[0];
    wire       prog_we = uio_in[1];
    wire       grid_st = uio_in[3];

    // -------------------------------------------------------------------------
    // Entradas analógicas / Taps físicos cuantizados (constante)
    // -------------------------------------------------------------------------
    localparam [7:0] RAW_GRID_WIRE_TAPS = 8'b1010_1101;
    wire [7:0] quantized_taps = ~RAW_GRID_WIRE_TAPS;

    // -------------------------------------------------------------------------
    // Registros del DAG programable (16 gates -> nodos 8..23)
    // -------------------------------------------------------------------------
    reg [2:0] gate_op [0:15];
    reg [4:0] gate_a  [0:15];
    reg [4:0] gate_b  [0:15];
    reg [4:0] target_node;
    reg [3:0] wr_ptr;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr      <= 4'd0;
            target_node <= 5'd0;
            for (i = 0; i < 16; i = i + 1) begin
                gate_op[i] <= 3'd0;
                gate_a[i]  <= 5'd0;
                gate_b[i]  <= 5'd0;
            end
        end else if (prog_en && prog_we) begin
            gate_op[wr_ptr] <= prog_op;
            gate_a[wr_ptr]  <= prog_a;
            gate_b[wr_ptr]  <= {1'b0, prog_b};
            wr_ptr          <= wr_ptr + 1'b1;
        end else if (prog_en && !prog_we) begin
            target_node     <= prog_a;
        end
    end

    // -------------------------------------------------------------------------
    // DAG combinacional: optimizado con muxes eficientes
    // -------------------------------------------------------------------------

    // Nodos base (0..7): salidas de la malla física
    wire n00 = quantized_taps[0];
    wire n01 = quantized_taps[1];
    wire n02 = quantized_taps[2];
    wire n03 = quantized_taps[3];
    wire n04 = quantized_taps[4];
    wire n05 = quantized_taps[5];
    wire n06 = quantized_taps[6];
    wire n07 = quantized_taps[7];

    // Función de selección eficiente con prioritario
    function automatic select_node;
        input [4:0] idx;
        input wire n8, n9, n10, n11, n12, n13, n14, n15, n16, n17, n18, n19, n20, n21, n22, n23;
        begin
            case(idx)
                5'd0:  select_node = n00;
                5'd1:  select_node = n01;
                5'd2:  select_node = n02;
                5'd3:  select_node = n03;
                5'd4:  select_node = n04;
                5'd5:  select_node = n05;
                5'd6:  select_node = n06;
                5'd7:  select_node = n07;
                5'd8:  select_node = n8;
                5'd9:  select_node = n9;
                5'd10: select_node = n10;
                5'd11: select_node = n11;
                5'd12: select_node = n12;
                5'd13: select_node = n13;
                5'd14: select_node = n14;
                5'd15: select_node = n15;
                5'd16: select_node = n16;
                5'd17: select_node = n17;
                5'd18: select_node = n18;
                5'd19: select_node = n19;
                5'd20: select_node = n20;
                5'd21: select_node = n21;
                5'd22: select_node = n22;
                5'd23: select_node = n23;
                default: select_node = 1'b0;
            endcase
        end
    endfunction

    // GATE 0 (nodo 8)
    wire a_g0 = select_node(gate_a[0], 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire b_g0 = select_node(gate_b[0], 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire n08;
    gate_eval u_g0 (.op(gate_op[0]), .a(a_g0), .b(b_g0), .y(n08));

    // GATE 1 (nodo 9)
    wire a_g1 = select_node(gate_a[1], n08, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire b_g1 = select_node(gate_b[1], n08, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire n09;
    gate_eval u_g1 (.op(gate_op[1]), .a(a_g1), .b(b_g1), .y(n09));

    // GATE 2 (nodo 10)
    wire a_g2 = select_node(gate_a[2], n08, n09, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire b_g2 = select_node(gate_b[2], n08, n09, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire n10;
    gate_eval u_g2 (.op(gate_op[2]), .a(a_g2), .b(b_g2), .y(n10));

    // GATE 3 (nodo 11)
    wire a_g3 = select_node(gate_a[3], n08, n09, n10, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire b_g3 = select_node(gate_b[3], n08, n09, n10, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire n11;
    gate_eval u_g3 (.op(gate_op[3]), .a(a_g3), .b(b_g3), .y(n11));

    // GATE 4 (nodo 12)
    wire a_g4 = select_node(gate_a[4], n08, n09, n10, n11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire b_g4 = select_node(gate_b[4], n08, n09, n10, n11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire n12;
    gate_eval u_g4 (.op(gate_op[4]), .a(a_g4), .b(b_g4), .y(n12));

    // GATE 5 (nodo 13)
    wire a_g5 = select_node(gate_a[5], n08, n09, n10, n11, n12, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire b_g5 = select_node(gate_b[5], n08, n09, n10, n11, n12, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire n13;
    gate_eval u_g5 (.op(gate_op[5]), .a(a_g5), .b(b_g5), .y(n13));

    // GATE 6 (nodo 14)
    wire a_g6 = select_node(gate_a[6], n08, n09, n10, n11, n12, n13, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire b_g6 = select_node(gate_b[6], n08, n09, n10, n11, n12, n13, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire n14;
    gate_eval u_g6 (.op(gate_op[6]), .a(a_g6), .b(b_g6), .y(n14));

    // GATE 7 (nodo 15)
    wire a_g7 = select_node(gate_a[7], n08, n09, n10, n11, n12, n13, n14, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire b_g7 = select_node(gate_b[7], n08, n09, n10, n11, n12, n13, n14, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire n15;
    gate_eval u_g7 (.op(gate_op[7]), .a(a_g7), .b(b_g7), .y(n15));

    // GATE 8 (nodo 16)
    wire a_g8 = select_node(gate_a[8], n08, n09, n10, n11, n12, n13, n14, n15, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire b_g8 = select_node(gate_b[8], n08, n09, n10, n11, n12, n13, n14, n15, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire n16;
    gate_eval u_g8 (.op(gate_op[8]), .a(a_g8), .b(b_g8), .y(n16));

    // GATE 9 (nodo 17)
    wire a_g9 = select_node(gate_a[9], n08, n09, n10, n11, n12, n13, n14, n15, n16, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire b_g9 = select_node(gate_b[9], n08, n09, n10, n11, n12, n13, n14, n15, n16, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire n17;
    gate_eval u_g9 (.op(gate_op[9]), .a(a_g9), .b(b_g9), .y(n17));

    // GATE 10 (nodo 18)
    wire a_g10 = select_node(gate_a[10], n08, n09, n10, n11, n12, n13, n14, n15, n16, n17, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire b_g10 = select_node(gate_b[10], n08, n09, n10, n11, n12, n13, n14, n15, n16, n17, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire n18;
    gate_eval u_g10 (.op(gate_op[10]), .a(a_g10), .b(b_g10), .y(n18));

    // GATE 11 (nodo 19)
    wire a_g11 = select_node(gate_a[11], n08, n09, n10, n11, n12, n13, n14, n15, n16, n17, n18, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire b_g11 = select_node(gate_b[11], n08, n09, n10, n11, n12, n13, n14, n15, n16, n17, n18, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wire n19;
    gate_eval u_g11 (.op(gate_op[11]), .a(a_g11), .b(b_g11), .y(n19));

    // GATE 12 (nodo 20)
    wire a_g12 = select_node(gate_a[12], n08, n09, n10, n11, n12, n13, n14, n15, n16, n17, n18, n19, 1'b0, 1'b0, 1'b0, 1'b0);
    wire b_g12 = select_node(gate_b[12], n08, n09, n10, n11, n12, n13, n14, n15, n16, n17, n18, n19, 1'b0, 1'b0, 1'b0, 1'b0);
    wire n20;
    gate_eval u_g12 (.op(gate_op[12]), .a(a_g12), .b(b_g12), .y(n20));

    // GATE 13 (nodo 21)
    wire a_g13 = select_node(gate_a[13], n08, n09, n10, n11, n12, n13, n14, n15, n16, n17, n18, n19, n20, 1'b0, 1'b0, 1'b0);
    wire b_g13 = select_node(gate_b[13], n08, n09, n10, n11, n12, n13, n14, n15, n16, n17, n18, n19, n20, 1'b0, 1'b0, 1'b0);
    wire n21;
    gate_eval u_g13 (.op(gate_op[13]), .a(a_g13), .b(b_g13), .y(n21));

    // GATE 14 (nodo 22)
    wire a_g14 = select_node(gate_a[14], n08, n09, n10, n11, n12, n13, n14, n15, n16, n17, n18, n19, n20, n21, 1'b0, 1'b0);
    wire b_g14 = select_node(gate_b[14], n08, n09, n10, n11, n12, n13, n14, n15, n16, n17, n18, n19, n20, n21, 1'b0, 1'b0);
    wire n22;
    gate_eval u_g14 (.op(gate_op[14]), .a(a_g14), .b(b_g14), .y(n22));

    // GATE 15 (nodo 23)
    wire a_g15 = select_node(gate_a[15], n08, n09, n10, n11, n12, n13, n14, n15, n16, n17, n18, n19, n20, n21, n22, 1'b0);
    wire b_g15 = select_node(gate_b[15], n08, n09, n10, n11, n12, n13, n14, n15, n16, n17, n18, n19, n20, n21, n22, 1'b0);
    wire n23;
    gate_eval u_g15 (.op(gate_op[15]), .a(a_g15), .b(b_g15), .y(n23));

    // -------------------------------------------------------------------------
    // Vector combinado de nodos: SOLO lectura (usado por el mux de salida).
    // -------------------------------------------------------------------------
    wire [23:0] node_val = { n23, n22, n21, n20, n19, n18, n17, n16,
                             n15, n14, n13, n12, n11, n10, n09, n08,
                             n07, n06, n05, n04, n03, n02, n01, n00 };

    // -------------------------------------------------------------------------
    // Salida: target_node acotado a 0..23 con un mux.
    // -------------------------------------------------------------------------
    reg sat_eval;
    integer t;
    always @(*) begin
        sat_eval = 1'b0;
        for (t = 0; t < 24; t = t + 1) begin
            if (target_node == t[4:0]) sat_eval = node_val[t];
        end
    end

    assign uo_out[0]   = sat_eval & grid_st;
    assign uo_out[1]   = (~sat_eval) & grid_st;
    assign uo_out[2]   = grid_st;
    assign uo_out[7:3] = quantized_taps[4:0];

    // -------------------------------------------------------------------------
    // Señales requeridas por Tiny Tapeout pero no usadas por este diseño.
    // -------------------------------------------------------------------------
    wire _unused = &{ena,
                     uio_in[2],
                     quantized_taps[7:5],
                     1'b0};

endmodule


// =============================================================================
// Sub-módulo de evaluación de un gate Booleano de 2 entradas.
// Combinacional puro, sin dependencia circular.
// =============================================================================
module gate_eval (
    input  wire [2:0] op,
    input  wire       a,
    input  wire       b,
    output reg        y
);
    always @(*) begin
        case (op)
            3'b000:  y =  (a & b);        // AND
            3'b001:  y =  (a | b);        // OR
            3'b010:  y = ~(a & b);        // NAND
            3'b011:  y = ~(a | b);        // NOR
            3'b100:  y =  (a ^ b);        // XOR
            3'b101:  y = ~(a ^ b);        // XNOR
            3'b110:  y = ~a;              // NOT
            default: y = 1'b0;
        endcase
    end
endmodule
