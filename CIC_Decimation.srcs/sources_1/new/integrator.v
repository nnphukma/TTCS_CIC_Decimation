`timescale 1ns / 1ps

module integrator #(
    parameter W = 28 // Độ rộng bit mặc định là 28
)(
    input  wire clk,
    input  wire rst_n,
    input  wire valid,               // Chỉ tích lũy khi valid = 1
    input  wire signed [W-1:0] din,
    output reg  signed [W-1:0] dout
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= 0;
        end else if (valid) begin
            dout <= dout + din;      // Phép cộng có dấu
        end
    end

endmodule