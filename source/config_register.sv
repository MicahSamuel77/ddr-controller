`timescale 1ns / 10ps

module config_register(
    input logic clk, n_rst, 
    input logic [7:0] waddr,
    input logic [63:0] wdata,
    input logic [2:0] wburst,
    output logic werr,
    input logic config_wstrobe,
    output logic [1:0] burst_size,
    output logic config_update
);

logic [1:0] next_size;
logic next_werr;
logic next_config_update;

always_ff @(posedge clk, negedge n_rst) begin
    if(~n_rst) begin
        burst_size <= 0;
        werr <= 0;
        config_update <= 0;
    end
    else begin
        burst_size <= next_size;
        werr <= next_werr;
        config_update <= next_config_update;
    end
end


always_comb begin
    next_werr = 1'b0;
    next_size = burst_size;
    next_config_update = 1'b0;
    if(config_wstrobe) begin
        if((waddr == 8'b0) && (wburst == 0)) begin
            next_size = wdata[1:0];
            next_config_update = 1'b1;
        end
        else begin
            next_werr = 1'b1;
        end
    end
end



endmodule

