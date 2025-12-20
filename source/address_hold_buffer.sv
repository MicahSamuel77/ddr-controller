`timescale 1ns / 10ps

module address_hold_buffer(
    input logic clk, n_rst,
    input logic [31:0] address,
    input logic write_enable,
    output logic [31:0] waddr
);

logic [31:0] next_waddr;

always_ff @(posedge clk, negedge n_rst) begin
    if(~n_rst) begin
        waddr <= 0;
    end
    else begin
        waddr <= next_waddr;
    end
end

always_comb begin
    next_waddr = waddr;
    if(write_enable) begin
        next_waddr = address;
    end
end




endmodule

