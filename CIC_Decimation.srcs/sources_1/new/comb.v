`timescale 1ns / 1ps

module comb #(
    parameter W = 28, // Độ rộng bit
    parameter M = 1   // Độ trễ M=1
)(
    input  wire clk,
    input  wire rst_n,
    input  wire valid,
    input  wire signed [W-1:0] din,
    output reg  signed [W-1:0] dout
);

    reg signed [W-1:0] delay_reg; // Thanh ghi trễ

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_reg <= 0;
            dout <= 0;
        end else if (valid) begin
            delay_reg <= din;
            dout <= din - delay_reg; // Phép trừ có dấu
        end
    end

endmodule