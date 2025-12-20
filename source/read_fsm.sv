`timescale 1ns / 10ps

module read_fsm #(
    MAX_TRANSACTIONS = 8
) (
    input logic clk, n_rst,
    input logic ARVALID,
    input logic rid0_done, rid1_done, rid2_done, rid3_done,
    input logic rid0_sent, rid1_sent, rid2_sent, rid3_sent,
    input logic [3:0] rid_present,
    input logic rfull,
    input logic [3:0] num_transactions,
    output logic ARREADY,
    output logic pop,
    output logic load,
    output logic scheduler_en,
    output logic transaction_sent
); 

logic next_arready, next_pop;

assign scheduler_en = (num_transactions <= MAX_TRANSACTIONS) && (!rid0_done && !rid1_done && !rid2_done && !rid3_done) && !load && !pop && !rfull && !transaction_sent;
assign load = ARREADY && ARVALID;
assign transaction_sent = rid0_sent&rid_present[0] | rid1_sent&rid_present[1] | rid2_sent&rid_present[2] | rid3_sent&rid_present[3];


always_ff @(posedge clk, negedge n_rst) begin
    if(~n_rst) begin
        pop <= 1'b0;
        ARREADY <= 1'b0;
    end
    else begin
        pop <= next_pop;
        ARREADY <= next_arready;
    end
end

always_comb begin
    next_arready = !pop && !load && (num_transactions < MAX_TRANSACTIONS);
    next_pop = rid0_done | rid1_done | rid2_done | rid3_done;
end


endmodule

