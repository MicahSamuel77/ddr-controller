`timescale 1ns / 10ps

module top #(
    // parameters
) (
    input logic clk, n_clk, n_rst,
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
    output logic CK, N_CK, CKE, CS, RAS, CAS, WE,
    output logic [1:0] B,
    output logic [13:0] A,
    inout logic DQS,
    inout logic [7:0] DQ
);

    // Command Pool Signals
    logic rfull, rstrobe, rerr, wstrobe, wfull, werr;
    logic [1:0] tid_in, burst_size;
    logic [7:0] raddr, waddr;
    logic [63:0] wdata;

    // DDR Out Data Buffer Signals
    logic rvalid, ren;
    logic [1:0] tid_out;
    logic [63:0] rdata;

    // Config Update
    logic MRS;
    

    axi_subordinate axi_sub (.clk(clk), .n_rst(n_rst),
        .ARID(ARID), .ARADDR(ARADDR), .ARLEN(ARLEN), .ARSIZE(ARSIZE), .ARBURST(ARBURST),
        .ARVALID(ARVALID), .ARREADY(ARREADY), .RREADY(RREADY), .RID(RID), .RDATA(RDATA),
        .RRESP(RRESP), .RLAST(RLAST), .RVALID(RVALID), .AWID(AWID), .AWADDR(AWADDR), .AWLEN(AWLEN),
        .AWSIZE(AWSIZE), .AWBURST(AWBURST), .AWVALID(AWVALID), .AWREADY(AWREADY), .WDATA(WDATA),
        .WSTRB(WSTRB), .WLAST(WLAST), .WVALID(WVALID), .WREADY(WREADY), .BREADY(BREADY), .BID(BID),
        .BRESP(BRESP), .BVALID(BVALID), .raddr(raddr), .rdata(rdata), .rvalid(rvalid), .rfull(rfull),
        .waddr(waddr), .rstrobe(rstrobe), .wdata(wdata), .wstrobe(wstrobe), .wfull(wfull), .tid_in(tid_in),
        .tid_out(tid_out), .rerr(rerr), .werr(werr), .burst_size(burst_size), .config_update(MRS), .ren(ren)
    );
    ddr_controller ddr_ctrl (.*);


endmodule

