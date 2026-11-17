`timescale 1ns / 1ps

module cic_decimator #(
    parameter N = 4,       
    parameter R = 16,      
    parameter M = 1,       
    parameter W_IN = 12,   
    parameter W_OUT = 12   
)(
    input  wire clk,
    input  wire rst_n,
    input  wire valid_in,
    input  wire signed [W_IN-1:0] data_in,
    
    output wire valid_out,
    output wire signed [W_OUT-1:0] data_out
);

    localparam W_GROWTH = $clog2(R * M) * N; 
    localparam W_INT = W_IN + W_GROWTH;      

    wire signed [W_INT-1:0] int_out [0:N-1];
    wire signed [W_INT-1:0] comb_out [0:N-1];
    wire dec_valid;

    // 1. Mở rộng dấu (Sign Extension)
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

    // SỬA LỖI TẠI ĐÂY: Trễ dec_valid đi 1 chu kỳ để đợi Integrator cập nhật xong
    reg dec_valid_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) dec_valid_d <= 0;
        else dec_valid_d <= dec_valid;
    end

    // 4. Chuỗi Comb (Sử dụng dec_valid_d thay vì dec_valid)
    comb #(.W(W_INT), .M(M)) comb_0 (
        .clk(clk), .rst_n(rst_n), .valid(dec_valid_d), .din(int_out[N-1]), .dout(comb_out[0])
    );

    generate
        for (i = 1; i < N; i = i + 1) begin : gen_comb
            comb #(.W(W_INT), .M(M)) comb_inst (
                .clk(clk), .rst_n(rst_n), .valid(valid_pipe[i-1]), .din(comb_out[i-1]), .dout(comb_out[i])
            );
        end
    endgenerate

    // 5. Cắt bit (Truncation) để lấy đầu ra W_OUT bit
    assign data_out = comb_out[N-1][W_INT-1 : W_INT-W_OUT]; 

    // 6. Trễ valid_out đi N nhịp (tính từ dec_valid_d)
    reg [N-1:0] valid_pipe;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= 0;
        end else begin
            valid_pipe <= {valid_pipe[N-2:0], dec_valid_d};
        end
    end
    
    // valid_out trễ đúng N chu kỳ so với dec_valid_d
    assign valid_out = valid_pipe[N-1];

endmodule