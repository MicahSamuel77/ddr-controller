`timescale 1ns / 10ps

module single_edge_counter #(
    parameter SIZE = 4
) (
    input logic clk, n_rst, clear, count_enable,
    input logic [SIZE - 1:0] rollover_val,
    output logic [SIZE - 1: 0] count_out,
    output logic rollover_flag
);

    logic [SIZE - 1: 0] next_count;
    logic count_rollover_flag;
    logic next_rollover_flag;

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            count_out               <= 0;
            count_rollover_flag     <= 0;
        end else begin
            count_out               <= next_count;
            count_rollover_flag     <= next_rollover_flag;
        end
    end

    always_comb begin
        if (clear) begin
            next_count          = 0;
            next_rollover_flag  = 0;
        end else if (count_enable) begin
            if (count_out < rollover_val) begin
                next_count          = count_out + 1;
                next_rollover_flag  = (count_out == rollover_val - 1);
            end else begin
                next_count          = 0;
                next_rollover_flag  = 0;
            end
        end else begin
            next_count          = count_out;
            next_rollover_flag  = count_rollover_flag;
        end
    end

    assign rollover_flag = count_rollover_flag || (rollover_val == 0 && count_enable);

endmodule
