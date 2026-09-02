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

    // Evitar que Verilator aborte por entradas requeridas por Tiny Tapeout no utilizadas
    wire _unused = &{ena, uio_in[2], 1'b0};

    // Pines bidireccionales en modo entrada pasiva
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    // Decodificación de buses de control y programación
    wire [2:0] prog_op = ui_in[2:0];
    wire [4:0] prog_a  = ui_in[7:3];
    wire [3:0] prog_b  = uio_in[7:4];
    wire       prog_en = uio_in[0];
    wire       prog_we = uio_in[1];
    wire       grid_st = uio_in[3];

    // =========================================================================
    // Entradas analógicas / Taps físicos cuantizados
    // =========================================================================
    wire [7:0] raw_grid_wire_taps = 8'b10101101; 
    wire [7:0] quantized_taps;

    // Detección de umbral
    assign quantized_taps = ~raw_grid_wire_taps;

    // =========================================================================
    // Matriz de compuertas programables (DAG Booleano)
    // =========================================================================
    reg [2:0] gate_op [0:15];
    reg [4:0] gate_a  [0:15];
    reg [4:0] gate_b  [0:15];
    reg [4:0] target_node;
    reg [3:0] wr_ptr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr      <= 4'd0;
            target_node <= 5'd0;
        end else if (prog_en && prog_we) begin
            gate_op[wr_ptr] <= prog_op;
            gate_a[wr_ptr]  <= prog_a;
            gate_b[wr_ptr]  <= {1'b0, prog_b};
            wr_ptr          <= wr_ptr + 1'b1;
        end else if (prog_en && !prog_we) begin
            target_node     <= prog_a;
        end
    end

    // Evaluación combinacional de nodos
    reg [31:0] node_val;
    integer k;
    always @(*) begin
        // Inicialización por defecto para evitar latches
        node_val = 32'd0;

        // Nodos 0 a 7 alimentados por los taps de la malla
        node_val[7:0] = quantized_taps;

        // Nodos 8 a 23 calculados por el DAG programado
        for (k = 0; k < 16; k = k + 1) begin
            case (gate_op[k])
                3'b000:  node_val[8 + k] = node_val[gate_a[k]] & node_val[gate_b[k]]; // AND
                3'b001:  node_val[8 + k] = node_val[gate_a[k]] | node_val[gate_b[k]]; // OR
                3'b010:  node_val[8 + k] = ~(node_val[gate_a[k]] & node_val[gate_b[k]]); // NAND
                3'b011:  node_val[8 + k] = ~(node_val[gate_a[k]] | node_val[gate_b[k]]); // NOR
                3'b100:  node_val[8 + k] = node_val[gate_a[k]] ^ node_val[gate_b[k]]; // XOR
                3'b101:  node_val[8 + k] = ~(node_val[gate_a[k]] ^ node_val[gate_b[k]]); // XNOR
                3'b110:  node_val[8 + k] = ~node_val[gate_a[k]];                     // NOT
                default: node_val[8 + k] = 1'b0;
            endcase
        end
    end

    // Salidas del resolvedor
    wire sat_eval = node_val[target_node];

    assign uo_out[0]   = sat_eval & grid_st;
    assign uo_out[1]   = (~sat_eval) & grid_st;
    assign uo_out[2]   = grid_st;
    assign uo_out[7:3] = quantized_taps[4:0];

endmodule
