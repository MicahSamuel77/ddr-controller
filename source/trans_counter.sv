`timescale 1ns / 10ps

module trans_counter(
    input logic clk, n_rst,
    input logic rid_en,
    input logic [7:0] rid_length,
    output logic rid_sent
);

logic [8:0] count, next_count;

always_ff @(posedge clk, negedge n_rst) begin
    if(~n_rst) begin
        count <= 0;
    end
    else begin
        count <= next_count;
    end
end

always_comb begin
    next_count = count;
    rid_sent = 1'b0;
    if(count == rid_length && rid_en) begin
        next_count = 0;
        rid_sent = 1'b1;
    end
    else if(rid_en) begin
        next_count = count + 1;
    end
end




endmodule

