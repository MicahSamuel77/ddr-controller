`timescale 1ns / 10ps

module axi_subordinate (
    input logic clk, n_rst,
    input logic [1:0] ARID,
    input logic [31:0] ARADDR,
    input logic [7:0] ARLEN,
    input logic [2:0] ARSIZE,
    input logic [1:0] ARBURST,
    input logic ARVALID,
    output logic ARREADY,
    input logic RREADY,
    output logic [1:0] RID,
    output logic [63:0] RDATA,
    output logic [1:0] RRESP,
    output logic RLAST,
    output logic RVALID,
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
    output logic [7:0] raddr,
    input logic [63:0] rdata,
    input logic rvalid, rfull,
    output logic [7:0] waddr,
    output logic rstrobe,
    output logic [63:0] wdata,
    output logic wstrobe,
    input logic wfull,
    output logic [1:0] tid_in,
    input logic [1:0] tid_out,
    input logic rerr, werr,
    output logic [1:0] burst_size,
    output logic config_update,
    output logic ren
);

logic config_registers;
logic config_wstrobe;
logic config_werr;
logic [2:0] wburst;

axi_read read(.clk(clk), .n_rst(n_rst), .ARVALID(ARVALID), .ARID(ARID), .ARADDR(ARADDR), .ARLEN(ARLEN), .ARSIZE(ARSIZE), .ARBURST(ARBURST), .ARREADY(ARREADY), .RREADY(RREADY), .RDATA(RDATA), .RRESP(RRESP), .RLAST(RLAST), .RVALID(RVALID), .RID(RID), .rdata(rdata), .rvalid(rvalid), .rfull(rfull), .tid_out(tid_out), .rerr(rerr), .selected_addr(raddr), .tid_in(tid_in), .rstrobe(rstrobe), .ren(ren));
axi_write write(.clk(clk), .n_rst(n_rst), .AWID(AWID), .AWADDR(AWADDR), .AWLEN(AWLEN), .AWSIZE(AWSIZE), .AWBURST(AWBURST), .AWVALID(AWVALID), .AWREADY(AWREADY), .WDATA(WDATA), .WSTRB(WSTRB), .WLAST(WLAST), .WVALID(WVALID), .WREADY(WREADY), .BREADY(BREADY), .BID(BID), .BRESP(BRESP), .BVALID(BVALID), .wfull(wfull), .werr(werr|config_werr), .addr(waddr), .wdata(wdata), .wstrobe(wstrobe), .config_wstrobe(config_wstrobe), .wburst(wburst));
config_register configs(.clk(clk), .n_rst(n_rst), .waddr(waddr), .wburst(wburst), .wdata(wdata), .werr(config_werr), .config_wstrobe(config_wstrobe), .burst_size(burst_size), .config_update(config_update));


endmodule

