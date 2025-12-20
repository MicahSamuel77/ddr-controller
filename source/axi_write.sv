`timescale 1ns / 10ps

module axi_write(
    input logic clk, n_rst,
    input logic [1:0] AWID,
    input logic [31:0] AWADDR,
    input logic [7:0] AWLEN,
    input logic [2:0] AWSIZE,
    input logic [1:0] AWBURST,
    input logic AWVALID,
    output logic AWREADY,
    input logic [63:0] WDATA,
    input logic [7:0] WSTRB,
    input logic WLAST,
    input logic WVALID,
    output logic WREADY,
    input logic BREADY,
    output logic [1:0] BID,
    output logic [1:0] BRESP,
    output logic BVALID,
    input logic wfull,
    input logic werr, 
    output logic [7:0] addr,
    output logic [63:0] wdata,
    output logic wstrobe,
    output logic config_wstrobe,
    output logic [2:0] wburst
);

logic load, pop, update_strobe, strobe;
logic [1:0] oldest_rid;
logic [31:0] next_address, current_address, waddr;
logic [2:0] burst_size_sel;
logic [11:0] rid_indexes;
logic [3:0] num_transactions;

assign addr = waddr[7:0];
assign config_wstrobe = waddr[8] & strobe;

assign wstrobe = (~waddr[8]) & strobe; 

assign BID = oldest_rid;
assign wburst = burst_size_sel;

write_fsm #(.MAX_TRANSACTIONS(8)) controller (.clk(clk), .n_rst(n_rst), .AWVALID(AWVALID), .WVALID(WVALID), .BREADY(BREADY), .WLAST(WLAST), .err(processing_err | werr), .wfull(wfull), .num_transactions(num_transactions), .pop(pop), .load(load), .update_strobe(update_strobe), .wdata_load(wdata_load), .AWREADY(AWREADY), .WREADY(WREADY), .BVALID(BVALID), .BRESP(BRESP));
transaction_fifo #(.DEPTH(8), .DATA_SIZE(32)) address_fifo (.clk(clk), .n_rst(n_rst), .pop(pop), .load(load), .data(AWADDR), .update_data(next_address), .update_strobe(update_strobe), .rid_indexes(rid_indexes), .current_rid(oldest_rid), .selected_data(current_address), .popped_rid(BID));
transaction_fifo #(.DEPTH(8), .DATA_SIZE(3)) bsize_fifo (.clk(clk), .n_rst(n_rst), .pop(pop), .load(load), .data(AWSIZE), .rid_indexes(rid_indexes), .current_rid(oldest_rid), .selected_data(burst_size_sel), .popped_rid(BID));
transaction_fifo #(.DEPTH(8), .DATA_SIZE(2)) btype_fifo (.clk(clk), .n_rst(n_rst), .pop(pop), .load(load), .data(AWBURST), .rid_indexes(rid_indexes), .current_rid(oldest_rid), .popped_rid(BID));
rid_fifo #(.DEPTH(8)) arid_fifo(.clk(clk), .n_rst(n_rst), .pop(pop), .load(load), .arid(AWID), .current_rid(oldest_rid), .rid_indexes(rid_indexes), .oldest_rid(oldest_rid), .num_transactions(num_transactions), .popped_rid(BID));
address_increment incr(.address(waddr), .ARSIZE(burst_size_sel), .new_address(next_address), .err(processing_err));
address_hold_buffer hold_buff(.clk(clk), .n_rst(n_rst), .address(current_address), .write_enable(wdata_load), .waddr(waddr));
write_data_register data_reg(.clk(clk), .n_rst(n_rst), .WSTRB(WSTRB), .WLAST(WLAST), .burst_size(burst_size_sel), .WDATA(WDATA), .write_enable(wdata_load), .wdata(wdata), .wstrobe(strobe));
endmodule

