`timescale 1ns / 1ps

module decimator #(
    parameter R = 16 // Hệ số giảm mẫu
)(
    input  wire clk,
    input  wire rst_n,
    input  wire valid_in,
    output reg  valid_out // Xung báo hiệu có 1 mẫu mới ra khỏi bộ lọc
);

    reg [4:0] count; // Đủ rộng để đếm đến R=16 (cần 5 bit)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
            valid_out <= 0;
        end else if (valid_in) begin
            if (count == R - 1) begin
                count <= 0;
                valid_out <= 1; // Đã đủ R mẫu, phát xung valid_out
            end else begin
                count <= count + 1;
                valid_out <= 0;
            end
        end else begin
            valid_out <= 0;
        end
    end

endmodule