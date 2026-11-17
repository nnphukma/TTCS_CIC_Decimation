`timescale 1ns / 1ps

module tb_hello_world();

    // Khai báo tín hiệu
    reg clk;
    reg rst_n;
    wire [3:0] count;

    // Khởi tạo module cần test (DUT - Device Under Test)
    hello_world uut (
        .clk(clk),
        .rst_n(rst_n),
        .count(count)
    );

    // Tạo xung clock 100MHz (chu kỳ 10ns)
    always #5 clk = ~clk;

    // Kịch bản mô phỏng
    initial begin
        // 1. IN RA MÀN HÌNH CONSOLE
        $display("=======================================");
        $display("Hello World! Moi truong Vivado da san sang.");
        $display("Bat dau mo phong bo dem CIC...");
        $display("=======================================");

        // 2. Khởi tạo giá trị ban đầu
        clk = 0;
        rst_n = 0;

        // 3. Giữ reset một lúc rồi thả
        #20;
        rst_n = 1;

        // 4. Chờ một số chu kỳ clock để xem bộ đếm chạy
        #100;
        
        // 5. Kết thúc mô phỏng
        $display("Mo phong ket thuc. Gia tri count cuoi cung = %d", count);
        $finish;
    end

endmodule