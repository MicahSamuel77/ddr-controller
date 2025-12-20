`timescale 1ns / 10ps

module write_fsm #(
    MAX_TRANSACTIONS = 8
) (
    input logic clk, n_rst,
    input logic AWVALID,
    input logic WVALID, 
    input logic BREADY,
    input logic WLAST,
    input logic err, 
    input logic wfull,
    input logic [3:0] num_transactions,
    input logic config_reg_write,
    output logic pop, load,
    output logic update_strobe,
    output logic wdata_load,
    output logic AWREADY,
    output logic WREADY,
    output logic BVALID,
    output logic [1:0] BRESP
);

logic next_AWREADY, next_WREADY, next_BVALID, next_update_strobe, next_pop, last_send, next_last_send;

assign load = AWREADY && AWVALID;
assign wdata_load = WREADY && WVALID && ~wfull;
assign BRESP = err ? 2'd2 : 0;


always_ff @(posedge clk, negedge n_rst) begin
    if(~n_rst) begin
        AWREADY <= 1'b0;
        WREADY <= 1'b0;
        BVALID <= 1'b0;
        update_strobe <= 1'b0;
        pop <= 1'b0;
        last_send <= 1'b0;
    end
    else begin
        AWREADY <= next_AWREADY;
        WREADY <= next_WREADY;
        BVALID <= next_BVALID;
        update_strobe <= next_update_strobe;
        pop <= next_pop;
        last_send <= next_last_send;
    end
end

always_comb begin 
    next_AWREADY = ~load && ~pop && (num_transactions < MAX_TRANSACTIONS);
    next_WREADY = !(WREADY & WVALID) && (~wfull);
    next_update_strobe = 1'b0;
    next_last_send = last_send;
    next_pop = 1'b0;
    next_BVALID = BVALID;

    if(num_transactions < 1) begin
        next_WREADY = ~wfull;
    end

    if(WREADY && WVALID) begin
        next_update_strobe = 1'b1;
    end

    if(WLAST && WREADY && WVALID) begin
        next_last_send = 1'b1;
    end

    if(last_send) begin
        next_pop = 1'b1;
        next_last_send = 1'b0;
    end

    if(update_strobe) begin
        next_BVALID = 1'b1;
    end

    if(BVALID && BREADY) begin
        next_BVALID = 1'b0;
    end
end


endmodule

