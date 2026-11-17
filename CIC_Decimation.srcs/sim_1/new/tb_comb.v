`timescale 1ns / 1ps
module tb_comb();
    reg clk, rst_n, valid;
    reg signed [27:0] din;
    wire signed [27:0] dout;

    comb #(.W(28), .M(1)) uut (
        .clk(clk), .rst_n(rst_n), .valid(valid), .din(din), .dout(dout)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst_n = 0; valid = 0; din = 0;
        #20 rst_n = 1;
        
        // Cấp xung Impulse: 10, sau đó là 0, 0, 0
        @(posedge clk); valid = 1; din = 28'd10;
        @(posedge clk); din = 28'd0;
        @(posedge clk); din = 28'd0;
        @(posedge clk); valid = 0;
        
        #20 $finish;
    end
endmodule