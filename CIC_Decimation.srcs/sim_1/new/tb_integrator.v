`timescale 1ns / 1ps
module tb_integrator();
    reg clk, rst_n, valid;
    reg signed [27:0] din; // SỬA THÀNH 28-BIT
    wire signed [27:0] dout;

    integrator #(.W(28)) uut (
        .clk(clk), .rst_n(rst_n), .valid(valid), .din(din), .dout(dout)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst_n = 1; valid = 0; din = 0; // Khởi tạo rst_n = 1
        #10 rst_n = 0; // Tạo xung reset (sườn âm)
        #20 rst_n = 1; // Thả reset
        
        // Cấp 3 mẫu: 10, 20, 30
        @(posedge clk); valid = 1; din = 28'd10;
        @(posedge clk); din = 28'd20;
        @(posedge clk); din = 28'd30;
        @(posedge clk); valid = 0;
        
        #20 $finish;
    end
endmodule