
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


    // =========================================================
    // SELF-CHECKING OUTPUT MONITOR
    // =========================================================

    // Capture and compare outputs after DUT nonblocking assignments settle.
    always @(posedge clk) begin
        if (rst_n) begin
            #1;

            if (valid_out) begin

                // Export every valid RTL output as 3-digit hexadecimal.
                if (output_fd != 0)
                    $fwrite(output_fd, "%03h\n", data_out);

                // Detect unexpected extra output samples.
                if (out_idx >= NUM_OUTPUTS) begin
                    $fatal(1,
                        "FAIL: EXTRA OUTPUT at sample %0d, data_out=%h",
                        out_idx, data_out);
                end

                exp_val = expected_mem[out_idx];

                // Detect unknown X/Z values.
                if ((^data_out) === 1'bx) begin
                    $fatal(1,
                        "FAIL: UNKNOWN X/Z at sample %0d, data_out=%h",
                        out_idx, data_out);
                end

                // Compare RTL output against golden reference.
                if (data_out !== exp_val) begin
                    $fatal(1,
                        "FAIL: MISMATCH at sample %0d | RTL=%h (%0d) | EXPECTED=%h (%0d)",
                        out_idx,
                        data_out, $signed(data_out),
                        exp_val, $signed(exp_val));
                end

                $display("PASS sample %0d: RTL=%0d, Expected=%0d",
                         out_idx, $signed(data_out), $signed(exp_val));

                out_idx = out_idx + 1;
            end
        end
    end


    // =========================================================
    // MAIN TEST SEQUENCE
    // =========================================================

    initial begin
        rst_n         = 1'b0;
        valid_in      = 1'b0;
        data_in       = {W_IN{1'b0}};
        out_idx       = 0;
        timeout_count = 0;
        exp_val       = {W_OUT{1'b0}};
        output_fd     = 0;

        $display("===============================================");
        $display("       BAT DAU MO PHONG TONG THE CIC           ");
        $display(" N=%0d, R=%0d, M=%0d, W_IN=%0d, W_OUT=%0d",
                 N, R, M, W_IN, W_OUT);
        $display(" So mau vao: %0d | So mau ra du kien: %0d",
                 NUM_SAMPLES, NUM_OUTPUTS);
        $display("===============================================");


        // -----------------------------------------------------
        // 1. CHECK AND LOAD INPUT / REFERENCE FILES
        // -----------------------------------------------------

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
                $fatal(1,
                    "stimulus.mem chua duoc nap day du, loi tai index %0d",
                    i);
        end

        for (i = 0; i < NUM_OUTPUTS; i = i + 1) begin
            if ((^expected_mem[i]) === 1'bx)
                $fatal(1,
                    "expected.mem chua duoc nap day du, loi tai index %0d",
                    i);
        end

        $display("Da nap thanh cong %0d mau stimulus va %0d mau expected.",
                 NUM_SAMPLES, NUM_OUTPUTS);


        // -----------------------------------------------------
        // 2. OPEN RTL OUTPUT FILE
        // -----------------------------------------------------

        output_fd = $fopen(OUTPUT_FILE, "w");
        if (output_fd == 0)
            $fatal(1,
                "Khong tao/mo duoc rtl_output.mem: %0s",
                OUTPUT_FILE);

        $display("File ket qua RTL: %0s", OUTPUT_FILE);


        // -----------------------------------------------------
        // 3. RESET DUT
        // -----------------------------------------------------

        // Hold reset beyond the 100 ns FPGA GSR initialization period.
        repeat (12) @(negedge clk);
        rst_n = 1'b1;


        // -----------------------------------------------------
        // 4. APPLY INPUT STIMULUS
        // -----------------------------------------------------

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


        // -----------------------------------------------------
        // 5. WAIT FOR ALL EXPECTED OUTPUTS
        // -----------------------------------------------------

        // Wait for all expected decimated outputs, with a timeout guard.
        while ((out_idx < NUM_OUTPUTS) &&
               (timeout_count < NUM_SAMPLES + 100)) begin

            @(negedge clk);
            timeout_count = timeout_count + 1;
        end


        // -----------------------------------------------------
        // 6. DRAIN AND CHECK FOR EXTRA OUTPUTS
        // -----------------------------------------------------

        // Drain a few clock cycles to detect unexpected extra outputs.
        repeat (2) @(negedge clk);

        // Allow the output monitor to finish its current event.
        #2;


        // -----------------------------------------------------
        // 7. CLOSE FILE AND REPORT RESULT
        // -----------------------------------------------------

        $fclose(output_fd);
        output_fd = 0;

        $display("===============================================");
        $display("          SELF-CHECKING TEST SUMMARY           ");
        $display("===============================================");
        $display("Expected outputs : %0d", NUM_OUTPUTS);
        $display("Received outputs : %0d", out_idx);

        if (out_idx != NUM_OUTPUTS) begin
            $fatal(1,
                "FAIL: OUTPUT COUNT MISMATCH - received %0d/%0d samples.",
                out_idx, NUM_OUTPUTS);
        end
        else begin
            $display("Matched outputs : %0d/%0d", out_idx, NUM_OUTPUTS);
            $display("===============================================");
            $display("RESULT: PASS");
            $display("All output samples match expected.mem.");
            $display("===============================================");

            $finish;
        end
    end

endmodule
