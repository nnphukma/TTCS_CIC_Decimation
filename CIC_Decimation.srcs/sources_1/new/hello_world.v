`timescale 1ns / 1ps

module hello_world (
    input  wire clk,
    input  wire rst_n,      // Reset tích cực mức thấp
    output reg  [3:0] count // Bộ đếm 4-bit
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 4'd0;
        end else begin
            count <= count + 1'b1;
        end
    end

endmodule