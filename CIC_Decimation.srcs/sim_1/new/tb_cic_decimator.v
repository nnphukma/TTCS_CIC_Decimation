`timescale 1ns / 1ps

module tb_cic_decimator();

    parameter N = 4;
    parameter R = 16;
    parameter W_IN = 12;
    parameter W_OUT = 12;
    parameter NUM_SAMPLES = 5000; 

    reg clk, rst_n, valid_in;
    reg signed [W_IN-1:0] data_in;
    wire valid_out;
    wire signed [W_OUT-1:0] data_out;

    // Khai báo mảng lưu dữ liệu
    reg [W_IN-1:0] stimulus_mem [0:NUM_SAMPLES-1];
    reg [W_OUT-1:0] expected_mem [0:NUM_SAMPLES-1];

    // Khởi tạo module (Đảm bảo gọi đúng tên top module của bạn)
    cic_decimator #(
        .N(N), .R(R), .W_IN(W_IN), .W_OUT(W_OUT)
    ) uut (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .data_in(data_in),
        .valid_out(valid_out), .data_out(data_out)
    );

    always #5 clk = ~clk;

    initial begin
        // ĐỌC FILE MEM
        $readmemh("D:/Documents/KMA/TTCS1/CIC_Decimation/stimulus.mem", stimulus_mem);
        $readmemh("D:/Documents/KMA/TTCS1/CIC_Decimation/expected.mem", expected_mem);
    end

    integer i;
    integer out_idx;
    reg signed [W_OUT-1:0] exp_val;
    integer error_count;

    initial begin
        clk = 0; rst_n = 0; valid_in = 0; data_in = 0; out_idx = 0; error_count = 0;
        
        #20 rst_n = 1;
        #10;
        
        $display("=== BAT DAU MO PHONG TONG THE CIC ===");

        // Cấp dữ liệu đầu vào
        for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
            @(posedge clk);
            valid_in = 1;
            data_in = stimulus_mem[i]; 
            @(posedge clk);
            valid_in = 0;
            #10;
        end

        // Chờ cho các mẫu cuối cùng ra khỏi pipeline
        repeat (20) @(posedge clk);
        
        $display("=== KET THUC MO PHONG ===");
        $display("Tong so mau dau ra: %d", out_idx);
        $display("Tong so loi (Mismatch): %d", error_count);
        
        if (error_count == 0) 
            $display("=> PASS: THIET KE VERILOG CHINH XAC TUYET DOI!");
        else 
            $display("=> FAIL: CO LOI XAY RA!");
            
        $finish;
    end

    // Tự động kiểm tra kết quả
    always @(posedge clk) begin
        if (valid_out && rst_n) begin
            exp_val = expected_mem[out_idx];
            
            if (data_out !== exp_val) begin
                error_count = error_count + 1;
                // Chỉ in 10 lỗi đầu tiên để tránh rác console
                if (error_count <= 10)
                    $display("LOI TAI MAU %d: Verilog = %d, Ky vong = %d", out_idx, data_out, exp_val);
            end
            out_idx = out_idx + 1;
        end
    end

endmodule