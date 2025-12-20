`timescale 1ns / 10ps

module error_buffer(
    input logic clk, n_rst,
    input logic clear, err,
    input logic [1:0] chosen_rid,
    output logic [3:0] error
);

logic [3:0] next_error;
logic enable, next_enable;

always_ff @(posedge clk, negedge n_rst) begin
    if(~n_rst) begin
        error <= 0;
        enable <= 0;
    end
    else begin
        error <= next_error;
        enable <= next_enable;
    end
end

always_comb begin
    next_error = error;
    next_enable = 1'b1;
    if(clear) begin
        next_error[chosen_rid] = 1'b0;
        next_enable = 1'b0;
    end
    else if(err && enable) begin
        next_error[chosen_rid] = 1'b1;
    end
end





endmodule

