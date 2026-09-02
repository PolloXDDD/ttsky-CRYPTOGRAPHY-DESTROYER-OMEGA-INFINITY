// Modelo de simulación para que la malla física entregue potenciales reales en el testbench
`ifndef GL_TEST
module omega_metal_grid_3d (
    output wire [7:0] taps
);
    // Asignación de prueba de potenciales físicos discretizados
    assign taps = 8'b10101101;
endmodule

module sky130_fd_sc_hd__inv_1 (
    input  wire A,
    output wire Y
);
    assign Y = ~A;
endmodule
`endif
