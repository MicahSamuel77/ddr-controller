`timescale 1ns / 10ps

module axi_read (
    input logic clk, n_rst,
    input logic ARVALID, 
    input logic [1:0] ARID,
    input logic [31:0] ARADDR,
    input logic [7:0] ARLEN,
    input logic [2:0] ARSIZE,
    input logic [1:0] ARBURST,
    output logic ARREADY,
    input logic RREADY,
    output logic [63:0] RDATA,
    output logic [1:0] RRESP,
    output logic RLAST,
    output logic RVALID,
    output logic [1:0] RID,
    input logic [63:0] rdata,
    input logic rvalid,
    input logic rfull,
    input logic [1:0] tid_out,
    input logic rerr,
    output logic [7:0] selected_addr,
    output logic [1:0] tid_in,
    output logic rstrobe,
    output logic ren
);
logic rid0_done, rid1_done, rid2_done, rid3_done, load, pop, scheduler_en, update_strobe, transaction_sent, rid0_sent, rid1_sent, rid2_sent, rid3_sent;
logic [3:0] num_transactions, rid_present;
logic [31:0] next_address;
logic [11:0] rid_indexes;
logic [1:0] current_rid, oldest_rid;
logic [127:0] rid_addresses;
logic [7:0] rid0_length, rid1_length, rid2_length, rid3_length; 
logic rid0_en, rid1_en, rid2_en, rid3_en;
logic [2:0] burst_size_sel;
logic processing_err;
logic [3:0] active_transactions;
logic [11:0] burst_sizes;
logic [31:0] chosen_addr;
logic [1:0] popped_rid;
logic [3:0] error;

assign selected_addr = chosen_addr[7:0];

assign tid_in = current_rid;
assign update_strobe = rstrobe;

read_fsm controller(.clk(clk), .n_rst(n_rst), .ARVALID(ARVALID), .rid_present(rid_present), .rid0_done(rid0_done), .rid1_done(rid1_done), .rid2_done(rid2_done), .rid3_done(rid3_done), .rid0_sent(rid0_sent), .rid1_sent(rid1_sent), .rid2_sent(rid2_sent), .rid3_sent(rid3_sent), .rfull(rfull), .num_transactions(num_transactions), .ARREADY(ARREADY), .pop(pop), .load(load), .scheduler_en(scheduler_en), .transaction_sent(transaction_sent));
transaction_fifo #(.DEPTH(8), .DATA_SIZE(32)) address_fifo (.clk(clk), .n_rst(n_rst), .pop(pop), .load(load), .data(ARADDR), .update_data(next_address), .update_strobe(update_strobe), .rid_indexes(rid_indexes), .current_rid(current_rid), .all_data(rid_addresses), .rid_present(rid_present), .popped_rid(popped_rid));
transaction_fifo #(.DEPTH(8), .DATA_SIZE(3)) bsize_fifo (.clk(clk), .n_rst(n_rst), .pop(pop), .load(load), .data(ARSIZE), .rid_indexes(rid_indexes), .current_rid(current_rid), .selected_data(burst_size_sel), .all_data(burst_sizes), .rid_present(rid_present), .popped_rid(popped_rid));
transaction_fifo #(.DEPTH(8), .DATA_SIZE(8)) blength_fifo (.clk(clk), .n_rst(n_rst), .pop(pop), .load(load), .data(ARLEN), .rid_indexes(rid_indexes), .current_rid(current_rid), .all_data({rid3_length, rid2_length, rid1_length, rid0_length}), .rid_present(rid_present), .popped_rid(popped_rid));
transaction_fifo #(.DEPTH(8), .DATA_SIZE(2)) btype_fifo (.clk(clk), .n_rst(n_rst), .pop(pop), .load(load), .data(ARBURST), .rid_indexes(rid_indexes), .current_rid(current_rid), .rid_present(rid_present), .popped_rid(popped_rid));
transaction_fifo #(.DEPTH(8), .DATA_SIZE(1)) tracking_fifo (.clk(clk), .n_rst(n_rst), .pop(pop), .load(load), .data(1'b0), .update_data(1'b1), .update_strobe(transaction_sent), .rid_indexes(rid_indexes), .current_rid(current_rid), .all_data(active_transactions), .rid_present(rid_present), .popped_rid(popped_rid));
rid_fifo #(.DEPTH(8)) arid_fifo(.clk(clk), .n_rst(n_rst), .pop(pop), .load(load), .arid(ARID), .current_rid(current_rid), .rid_present(rid_present), .rid_indexes(rid_indexes), .oldest_rid(oldest_rid), .num_transactions(num_transactions), .popped_rid(popped_rid));
rid_scheduler scheduler(.clk(clk), .n_rst(n_rst), .scheduler_en(scheduler_en), .rid_addresses(rid_addresses), .rid_present(rid_present), .active_transactions(active_transactions), .oldest_rid(oldest_rid), .rid0_en(rid0_en), .rid1_en(rid1_en), .rid2_en(rid2_en), .rid3_en(rid3_en), .chosen_rid(current_rid), .selected_addr(chosen_addr), .rstrobe(rstrobe));
address_increment incr(.address(chosen_addr), .ARSIZE(burst_size_sel), .new_address(next_address), .err(processing_err));
trans_counter rid0_counter(.clk(clk), .n_rst(n_rst), .rid_en(rid0_en), .rid_length(rid0_length), .rid_sent(rid0_sent));
trans_counter rid1_counter(.clk(clk), .n_rst(n_rst), .rid_en(rid1_en), .rid_length(rid1_length), .rid_sent(rid1_sent));
trans_counter rid2_counter(.clk(clk), .n_rst(n_rst), .rid_en(rid2_en), .rid_length(rid2_length), .rid_sent(rid2_sent));
trans_counter rid3_counter(.clk(clk), .n_rst(n_rst), .rid_en(rid3_en), .rid_length(rid3_length), .rid_sent(rid3_sent));
error_buffer rid_errors(.clk(clk), .n_rst(n_rst), .clear(pop), .err(processing_err|rerr), .chosen_rid(current_rid), .error(error));
read_response_buffer response_fsm (.clk(clk), .n_rst(n_rst), .rerr(error), .rvalid(rvalid), .RREADY(RREADY), .transaction_sent(rstrobe), .rid_out(tid_out), .chosen_rid(current_rid), .burst_lengths({rid3_length, rid2_length, rid1_length, rid0_length}), .burst_sizes(burst_sizes), .data_in(rdata), .RRESP(RRESP), .RDATA(RDATA), .RID(RID), .ren(ren), .rid0_done(rid0_done), .rid1_done(rid1_done), .rid2_done(rid2_done), .rid3_done(rid3_done), .RLAST(RLAST), .RVALID(RVALID), .popped_rid(popped_rid));


endmodule

