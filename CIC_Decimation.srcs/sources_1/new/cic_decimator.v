`timescale 1ns / 1ps 

// CIC decimator: N integrator stages -> decimation by R -> N comb stages.
// The integrator next-state chain is calculated combinationally so that
// every input sample contributes to all N integrators in the same sample
// interval. The comb chain is updated only when an R-th valid input arrives.
module cic_decimator #(
    parameter integer N      = 4,
    parameter integer R      = 16,
    parameter integer M      = 1,
    parameter integer W_IN  = 12,
    parameter integer W_OUT = 12
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         valid_in,
    input  wire signed [W_IN-1:0]       data_in,
    output reg                          valid_out,
    output reg signed [W_OUT-1:0]       data_out
);

    // Full-precision CIC growth: N * ceil(log2(R*M)) bits.
    localparam integer LOG2_RM = (R*M > 1) ? $clog2(R*M) : 0;
    localparam integer W_GROWTH = N * LOG2_RM;
    localparam integer W_INT = W_IN + W_GROWTH;

    // Integrator states and their combinational next values.
    reg  signed [W_INT-1:0] int_state [0:N-1];
    wire signed [W_INT-1:0] int_next  [0:N-1];

    // Comb stage input/output and M-sample delay memories.
    wire signed [W_INT-1:0] comb_stage_in  [0:N-1];
    wire signed [W_INT-1:0] comb_stage_out [0:N-1];
    reg  signed [W_INT-1:0] comb_delay [0:(N*M)-1];

    wire signed [W_INT-1:0] data_in_ext;

    reg [31:0] decim_count;
    integer k;
    integer j;

    // Sign-extend the input to the internal CIC width.
    assign data_in_ext = {{W_GROWTH{data_in[W_IN-1]}}, data_in};

    // ------------------------------------------------------------
    // 1. Integrator cascade: calculate all next states for this
    //    accepted input sample.
    // ------------------------------------------------------------
    assign int_next[0] = int_state[0] + data_in_ext;

    genvar gi;
    generate
        for (gi = 1; gi < N; gi = gi + 1) begin : GEN_INTEGRATORS
            assign int_next[gi] = int_state[gi] + int_next[gi-1];
        end
    endgenerate

    // ------------------------------------------------------------
    // 2. Comb cascade. Its input is the final integrator value for
    //    the current sample, and it is clock-enabled at the decimated
    //    output rate only.
    // ------------------------------------------------------------
    assign comb_stage_in[0] = int_next[N-1];

    genvar gc;
    generate
        for (gc = 1; gc < N; gc = gc + 1) begin : GEN_COMB_INPUTS
            assign comb_stage_in[gc] = comb_stage_out[gc-1];
        end

        for (gc = 0; gc < N; gc = gc + 1) begin : GEN_COMB_STAGES
            assign comb_stage_out[gc] =
                comb_stage_in[gc] - comb_delay[gc*M + M-1];
        end
    endgenerate

    // ------------------------------------------------------------
    // 3. Sequential state update and decimation control.
    // ------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            decim_count <= 0;
            valid_out   <= 1'b0;
            data_out    <= {W_OUT{1'b0}};

            for (k = 0; k < N; k = k + 1)
                int_state[k] <= {W_INT{1'b0}};

            for (k = 0; k < N*M; k = k + 1)
                comb_delay[k] <= {W_INT{1'b0}};
        end
        else begin
            // Default: valid_out is a one-clock pulse.
            valid_out <= 1'b0;

            if (valid_in) begin
                // Every accepted input sample updates every integrator.
                for (k = 0; k < N; k = k + 1)
                    int_state[k] <= int_next[k];

                // Emit one output after every R accepted input samples.
                if (decim_count == R-1) begin
                    decim_count <= 0;
                    valid_out   <= 1'b1;

                    // Keep the W_OUT most-significant bits, matching
                    // the fixed-point format used by the reference data.
                    data_out <= comb_stage_out[N-1][W_INT-1 : W_INT-W_OUT];

                    // Update all M-sample comb delay lines once per
                    // decimated sample.
                    for (k = 0; k < N; k = k + 1) begin
                        comb_delay[k*M] <= comb_stage_in[k];
                        for (j = 1; j < M; j = j + 1)
                            comb_delay[k*M+j] <= comb_delay[k*M+j-1];
                    end
                end
                else begin
                    decim_count <= decim_count + 1'b1;
                end
            end
        end
    end

endmodule
