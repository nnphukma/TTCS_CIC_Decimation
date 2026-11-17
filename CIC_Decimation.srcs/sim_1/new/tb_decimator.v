`timescale 1ns / 1ps
module tb_decimator();
    reg clk, rst_n, valid_in;
    wire valid_out;
    reg [4:0] count; // Biến đếm bên ngoài để đối chiếu

    decimator #(.R(16)) uut (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .valid_out(valid_out)
    );

    always #5 clk = ~clk;

    integer i;
    initial begin
        clk = 0; rst_n = 0; valid_in = 0; count = 0;
        #20 rst_n = 1;
        
        for (i = 0; i < 40; i = i + 1) begin
            @(posedge clk); valid_in = 1;
            @(posedge clk); valid_in = 0;
            #2; // Chờ một chút để xem valid_out
            if (valid_out) 
                $display("Tai chu ky thu %d: valid_out = 1", i+1);
        end
        #20 $finish;
    end
endmodule