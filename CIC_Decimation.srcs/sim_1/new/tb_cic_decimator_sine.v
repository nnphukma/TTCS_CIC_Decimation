`timescale 1ns / 1ps

module tb_cic_decimator_sine;

    // CIC configuration: keep identical to the existing RTL.
    localparam integer N           = 4;
    localparam integer R           = 16;
    localparam integer M           = 1;
    localparam integer W_IN        = 12;
    localparam integer W_OUT       = 12;
    localparam integer NUM_SAMPLES = 5000;
    localparam integer NUM_OUTPUTS = NUM_SAMPLES / R;

    // Files are stored beside CIC_Decimation.xpr.
    localparam STIMULUS_FILE = "D:/Documents/KMA/TTCS1/CIC_Decimation/stimulus_sine.mem";
    localparam OUTPUT_FILE   = "D:/Documents/KMA/TTCS1/CIC_Decimation/rtl_sine_output.mem";

    reg clk;
    reg rst_n;
    reg valid_in;
    reg signed [W_IN-1:0] data_in;

    wire valid_out;
    wire signed [W_OUT-1:0] data_out;

    reg signed [W_IN-1:0] stimulus_mem [0:NUM_SAMPLES-1];

    integer i;
    integer out_idx;
    integer timeout_count;
    integer error_count;
    integer stimulus_fd;
    integer output_fd;

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

    // 100 MHz system clock.
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Capture every valid output after DUT nonblocking assignments settle.
    always @(posedge clk) begin
        if (rst_n) begin
            #1;
            if (valid_out) begin
                if (output_fd != 0)
                    $fwrite(output_fd, "%03h\n", data_out);

                if ((^data_out) === 1'bx) begin
                    begin
                        $display("ERROR: Unknown X/Z at output sample %0d: %h",
                                 out_idx, data_out);
                        error_count = error_count + 1;
                    end
                end

                if (out_idx >= NUM_OUTPUTS) begin
                    begin
                        $display("ERROR: More output samples than expected.");
                        error_count = error_count + 1;
                    end
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
        timeout_count = 0;
        error_count   = 0;
        output_fd     = 0;

        $display("===============================================");
        $display("       CIC SINGLE-TONE RTL SIMULATION          ");
        $display(" N=%0d, R=%0d, M=%0d, W_IN=%0d, W_OUT=%0d",
                 N, R, M, W_IN, W_OUT);
        $display(" Input samples: %0d | Expected outputs: %0d",
                 NUM_SAMPLES, NUM_OUTPUTS);
        $display("===============================================");

        // Check and load the single-tone stimulus.
        stimulus_fd = $fopen(STIMULUS_FILE, "r");
        if (stimulus_fd == 0)
            $fatal(1, "Cannot open stimulus file: %0s", STIMULUS_FILE);
        $fclose(stimulus_fd);

        $readmemh(STIMULUS_FILE, stimulus_mem);

        // Check that every requested stimulus entry was loaded.
        for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
            if ((^stimulus_mem[i]) === 1'bx)
                $fatal(1, "Stimulus memory incomplete at index %0d", i);
        end

        $display("Loaded %0d single-tone input samples.", NUM_SAMPLES);

        // Create/overwrite the RTL output file.
        output_fd = $fopen(OUTPUT_FILE, "w");
        if (output_fd == 0)
            $fatal(1, "Cannot create output file: %0s", OUTPUT_FILE);

        $display("RTL output file: %0s", OUTPUT_FILE);

        // Hold reset for five clock cycles; release on a falling edge.
        repeat (5) @(negedge clk);
        rst_n = 1'b1;

        // Drive input samples on falling edges to avoid a race with the DUT.
        for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
            @(negedge clk);
            valid_in = 1'b1;
            data_in  = stimulus_mem[i];
        end

        // Deassert valid after the final input sample.
        @(negedge clk);
        valid_in = 1'b0;
        data_in  = {W_IN{1'b0}};

        // Wait for all decimated outputs, with a timeout guard.
        while ((out_idx < NUM_OUTPUTS) &&
               (timeout_count < NUM_SAMPLES + 100)) begin
            @(negedge clk);
            timeout_count = timeout_count + 1;
        end

        // Allow the output monitor to finish before closing the file.
        #2;
        $fclose(output_fd);
        output_fd = 0;

        $display("===============================================");
        $display("Total RTL output samples: %0d / %0d",
                 out_idx, NUM_OUTPUTS);
        $display("Saved output: rtl_sine_output.mem");
        $display("Total errors: %0d", error_count);

        if (out_idx != NUM_OUTPUTS)
            $fatal(1, "FAIL: timeout, received %0d/%0d outputs.",
                   out_idx, NUM_OUTPUTS);
        else if (error_count != 0)
            $fatal(1, "FAIL: detected %0d unknown/extra output errors.", error_count);
        else begin
            $display("PASS: captured all %0d output samples.", NUM_OUTPUTS);
            $display("===============================================");
            $finish;
        end
    end

endmodule
