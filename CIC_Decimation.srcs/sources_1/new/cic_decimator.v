`timescale 1ns / 1ps

module cic_decimator #(
    parameter N = 4,       // Số tầng
    parameter R = 16,      // Hệ số Decimation
    parameter M = 1,       // Độ trễ vi phân
    parameter W_IN = 12,   // Độ rộng bit đầu vào
    parameter W_OUT = 12   // Độ rộng bit đầu ra
)(
    input  wire clk,
    input  wire rst_n,
    input  wire valid_in,
    input  wire signed [W_IN-1:0] data_in,
    
    output wire valid_out,
    output wire signed [W_OUT-1:0] data_out
);

    // Tính toán độ rộng bit động
    localparam W_GROWTH = $clog2(R * M) * N; // 16 bit tăng thêm
    localparam W_INT = W_IN + W_GROWTH;      // 12 + 16 = 28 bit

    // Dây dẫn kết nối giữa các tầng
    wire signed [W_INT-1:0] int_out [0:N-1];
    wire signed [W_INT-1:0] comb_out [0:N-1];
    wire dec_valid;

    // 1. Mở rộng dấu (Sign Extension) cho đầu vào
    wire signed [W_INT-1:0] data_in_ext = {{W_GROWTH{data_in[W_IN-1]}}, data_in};

    // 2. Chuỗi Integrator
    integrator #(.W(W_INT)) int_0 (
        .clk(clk), .rst_n(rst_n), .valid(valid_in), .din(data_in_ext), .dout(int_out[0])
    );

    genvar i;
    generate
        for (i = 1; i < N; i = i + 1) begin : gen_int
            integrator #(.W(W_INT)) int_inst (
                .clk(clk), .rst_n(rst_n), .valid(valid_in), .din(int_out[i-1]), .dout(int_out[i])
            );
        end
    endgenerate

    // 3. Bộ Decimator
    decimator #(.R(R)) dec_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .valid_out(dec_valid)
    );

    // 4. Chuỗi Comb
    comb #(.W(W_INT), .M(M)) comb_0 (
        .clk(clk), .rst_n(rst_n), .valid(dec_valid), .din(int_out[N-1]), .dout(comb_out[0])
    );

    generate
        for (i = 1; i < N; i = i + 1) begin : gen_comb
            comb #(.W(W_INT), .M(M)) comb_inst (
                .clk(clk), .rst_n(rst_n), .valid(dec_valid), .din(comb_out[i-1]), .dout(comb_out[i])
            );
        end
    endgenerate

    // 5. Cắt bit (Truncation) để lấy đầu ra W_OUT bit
    // Lấy W_OUT bit cao nhất của tầng Comb cuối cùng
    assign valid_out = dec_valid;
    assign data_out = comb_out[N-1][W_INT-1 : W_INT-W_OUT];

endmodule