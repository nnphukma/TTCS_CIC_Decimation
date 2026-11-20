`timescale 1ns / 1ps
 
module tb_cic_decimator;

    // Keep these parameters consistent with the generated memory files.
    localparam integer N           = 4;
    localparam integer R           = 16;
    localparam integer M           = 1;
    localparam integer W_IN        = 12;
    localparam integer W_OUT       = 12;
    localparam integer NUM_SAMPLES = 5000;
    localparam integer NUM_OUTPUTS = NUM_SAMPLES / R;

    // The .mem files and output file are stored beside CIC_Decimation.xpr.
    // Absolute paths are used because XSim runs from its simulation directory.
    localparam STIMULUS_FILE = "D:/Documents/KMA/TTCS1/CIC_Decimation/stimulus.mem";
    localparam EXPECTED_FILE = "D:/Documents/KMA/TTCS1/CIC_Decimation/expected.mem";
    localparam OUTPUT_FILE   = "D:/Documents/KMA/TTCS1/CIC_Decimation/rtl_output.mem";

    reg clk;
    reg rst_n;
    reg valid_in;
    reg signed [W_IN-1:0] data_in;

    wire valid_out;
    wire signed [W_OUT-1:0] data_out;

    reg signed [W_IN-1:0]  stimulus_mem [0:NUM_SAMPLES-1];
    reg signed [W_OUT-1:0] expected_mem [0:NUM_OUTPUTS-1];

    integer i;
    integer out_idx;
    integer error_count;
    integer timeout_count;
    integer stimulus_fd;
    integer expected_fd;
    integer output_fd;

    reg signed [W_OUT-1:0] exp_val;

    cic_decimator #(
        .N(N),
        .R(R),
        .M(M),
        .W_IN(W_IN),
        .W_OUT(W_OUT)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .data_in(data_in),
        .valid_out(valid_out),
        .data_out(data_out)
    );

    // 100 MHz clock.
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Capture and compare outputs after DUT nonblocking assignments settle.
    always @(posedge clk) begin
        if (rst_n) begin
            #1;
            if (valid_out) begin
                // Export every valid RTL output as 3-digit hexadecimal.
                // Keep this independent of the comparison result so that
                // mismatching/unknown samples are also preserved for debug.
                if (output_fd != 0)
                    $fwrite(output_fd, "%03h\n", data_out);

                if (out_idx < NUM_OUTPUTS) begin
                    exp_val = expected_mem[out_idx];

                    // Do not allow X/Z values to be reported as PASS.
                    if ((^data_out === 1'bx) || (^exp_val === 1'bx)) begin
                        $display("LOI UNKNOWN TAI MAU %0d: Verilog=%h, Expected=%h",
                                 out_idx, data_out, exp_val);
                        error_count = error_count + 1;
                    end
                    else if (data_out !== exp_val) begin
                        $display("LOI TAI MAU %0d: Verilog=%0d, Ky vong=%0d",
                                 out_idx, $signed(data_out), $signed(exp_val));
                        error_count = error_count + 1;
                    end
                    else begin
                        $display("DUNG TAI MAU %0d: Gia tri=%0d",
                                 out_idx, $signed(data_out));
                    end
                end
                else begin
                    $display("LOI: Phat sinh nhieu mau dau ra hon du kien.");
                    error_count = error_count + 1;
                end

                out_idx = out_idx + 1;
            end
        end
    end

    initial begin
        rst_n         = 1'b0;
        valid_in      = 1'b0;
        data_in       = {W_IN{1'b0}};
        out_idx       = 0;
        error_count   = 0;
        timeout_count = 0;
        exp_val       = {W_OUT{1'b0}};
        output_fd     = 0;

        $display("===============================================");
        $display("       BAT DAU MO PHONG TONG THE CIC           ");
        $display(" N=%0d, R=%0d, M=%0d, W_IN=%0d, W_OUT=%0d", N, R, M, W_IN, W_OUT);
        $display(" So mau vao: %0d | So mau ra du kien: %0d", NUM_SAMPLES, NUM_OUTPUTS);
        $display("===============================================");

        // Check that input/reference files exist before calling $readmemh.
        stimulus_fd = $fopen(STIMULUS_FILE, "r");
        if (stimulus_fd == 0)
            $fatal(1, "Khong mo duoc stimulus.mem: %0s", STIMULUS_FILE);
        $fclose(stimulus_fd);

        expected_fd = $fopen(EXPECTED_FILE, "r");
        if (expected_fd == 0)
            $fatal(1, "Khong mo duoc expected.mem: %0s", EXPECTED_FILE);
        $fclose(expected_fd);

        $readmemh(STIMULUS_FILE, stimulus_mem);
        $readmemh(EXPECTED_FILE, expected_mem);

        // Check that all requested memory entries were actually loaded.
        for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
            if ((^stimulus_mem[i]) === 1'bx)
                $fatal(1, "stimulus.mem chua duoc nap day du, loi tai index %0d", i);
        end

        for (i = 0; i < NUM_OUTPUTS; i = i + 1) begin
            if ((^expected_mem[i]) === 1'bx)
                $fatal(1, "expected.mem chua duoc nap day du, loi tai index %0d", i);
        end

        $display("Da nap thanh cong %0d mau stimulus va %0d mau expected.",
                 NUM_SAMPLES, NUM_OUTPUTS);

        // Open output file in write mode (overwrite previous simulation result).
        output_fd = $fopen(OUTPUT_FILE, "w");
        if (output_fd == 0)
            $fatal(1, "Khong tao/mo duoc rtl_output.mem: %0s", OUTPUT_FILE);

        $display("File ket qua RTL: %0s", OUTPUT_FILE);

        // Hold reset for five clock cycles; release on a falling edge.
        repeat (5) @(negedge clk);
        rst_n = 1'b1;

        // Drive input data on falling edges to avoid a race with the DUT.
        for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
            @(negedge clk);
            valid_in = 1'b1;
            data_in  = stimulus_mem[i];
        end

        // Deassert valid after the final input sample has been accepted.
        @(negedge clk);
        valid_in = 1'b0;
        data_in  = {W_IN{1'b0}};

        // Wait for all expected decimated outputs, with a timeout guard.
        while ((out_idx < NUM_OUTPUTS) && (timeout_count < NUM_SAMPLES + 100)) begin
            @(negedge clk);
            timeout_count = timeout_count + 1;
        end

        // Allow the output monitor to finish its current event before closing.
        #2;
        $fclose(output_fd);
        output_fd = 0;

        $display("===============================================");
        $display("Tong so mau dau ra: %0d / %0d", out_idx, NUM_OUTPUTS);
        $display("Tong so loi: %0d", error_count);
        $display("Da ghi ket qua vao rtl_output.mem");

        if (out_idx != NUM_OUTPUTS)
            $fatal(1, "FAIL: TIMEOUT - chi nhan %0d/%0d mau dau ra.", out_idx, NUM_OUTPUTS);
        else if (error_count != 0)
            $fatal(1, "FAIL: Co %0d loi mismatch/unknown.", error_count);
        else begin
            $display("KET LUAN: PASS - Tat ca mau dau ra khop expected.mem.");
            $display("KET QUA: %0d/%0d mau da duoc ghi.", out_idx, NUM_OUTPUTS);
            $display("===============================================");
            $finish;
        end
    end

endmodule
