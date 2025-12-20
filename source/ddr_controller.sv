`timescale 1ns / 10ps

`include "type_pkg.vh"

import type_pkg::burst_size_t;

module ddr_controller #( ) (
    input logic clk, n_clk, n_rst,
    input logic rstrobe, wstrobe, MRS, ren,
    input logic [1:0] burst_size, tid_in,
    input logic [7:0] raddr, waddr,
    input logic [63:0] wdata,
    output logic werr, rerr,
    output logic rvalid, rfull, wfull,
    output logic [1:0] tid_out,
    output logic [63:0] rdata,
    output logic CK, N_CK, CKE, CS, RAS, CAS, WE,
    output logic [1:0] B,
    output logic [13:0] A,
    inout logic DQS,
    inout logic [7:0] DQ
);
    import type_pkg::*;

    // Command Pool Signals
    logic read_issued, write_issued;
    logic rready, wready, read_in_progress, rbusy;
    logic raw, tid_strobe;
    logic [1:0] tid_pop;
    burst_size_t pool_rburst_size, rburst_size_pop, pool_wburst_size, wburst_size_pop;
    logic [7:0] pool_raddr, pool_waddr;
    logic [63:0] pool_wdata;
    logic rready2, wready2;
    logic [7:0] pool_raddr2, pool_waddr2, raddr_raw;
    burst_size_t pool_rburst_size2, pool_wburst_size2, rburst_size_raw;

    assign rbusy = read_in_progress;

    // Command Scheduler Signals
    bank_status_t bank_0_status, bank_1_status, bank_2_status, bank_3_status;
    (* keep *) bank_states_t bank_0_state, bank_1_state, bank_2_state, bank_3_state;
    logic issue_cmd, cmd_issued, DQ_oe, all_banks_closed;
    logic [2:0] read_row, write_row, last_row;
    logic [1:0] read_bank, write_bank, last_bank;
    priority_t read_priority, write_priority;

    assign read_row = pool_raddr[7:5];
    assign write_row = pool_waddr[7:5];
    assign read_bank = pool_raddr[4:3];
    assign write_bank = pool_waddr[4:3];

    // Data Output Signals
    logic raw_strobe, dram_strobe, r_dqs;
    (* keep *) logic w_dqs;
    logic [7:0] ddr_byte, dq;
    logic [63:0] raw_data, dram_data, mux_data;

    read_command_pool #() rcp (.*);
    write_command_pool #() wcp (.*);
    timing_control time_ctrl (.*);
    maintenance_command_queue mcq (.*);
    command_scheduler cmd_sched (.*);
    bank_monitor #(.BANK_NUM(0)) bm0 (
        .clk(clk),
        .n_rst(n_rst),
        .CS(CS),
        .CAS(CAS),
        .RAS(RAS),
        .WE(WE),
        .B(B),
        .pool_rburst_size(pool_rburst_size),
        .pool_wburst_size(pool_wburst_size),
        .bank_status(bank_0_status),
        .bank_state(bank_0_state)
    );
    bank_monitor #(.BANK_NUM(1)) bm1 (
        .clk(clk),
        .n_rst(n_rst),
        .CS(CS),
        .CAS(CAS),
        .RAS(RAS),
        .WE(WE),
        .B(B),
        .pool_rburst_size(pool_rburst_size),
        .pool_wburst_size(pool_wburst_size),
        .bank_status(bank_1_status),
        .bank_state(bank_1_state)
    );
    bank_monitor #(.BANK_NUM(2)) bm2 (
        .clk(clk),
        .n_rst(n_rst),
        .CS(CS),
        .CAS(CAS),
        .RAS(RAS),
        .WE(WE),
        .B(B),
        .pool_rburst_size(pool_rburst_size),
        .pool_wburst_size(pool_wburst_size),
        .bank_status(bank_2_status),
        .bank_state(bank_2_state)
    );
    bank_monitor #(.BANK_NUM(3)) bm3 (
        .clk(clk),
        .n_rst(n_rst),
        .CS(CS),
        .CAS(CAS),
        .RAS(RAS),
        .WE(WE),
        .B(B),
        .pool_rburst_size(pool_rburst_size),
        .pool_wburst_size(pool_wburst_size),
        .bank_status(bank_3_status),
        .bank_state(bank_3_state)
    );
    raw_data_buffer raw_db (.*);
    burst_to_byte write_to_dram (.*);
    dram_data_buffer dram_db (.*);
    data_buffer out_to_axi (.*);

    // INOUT Logic for DDR Data
    logic next_writing, writing;

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            writing <= 0;
        end else begin
            writing <= next_writing;
        end
    end

    wire any_bank_writing;
    always_comb begin
        next_writing = writing;
        if   (any_bank_writing)     next_writing = 1;
        else                        next_writing = 0;
    end

    wire bank_0_writing, bank_1_writing, bank_2_writing, bank_3_writing;
    assign bank_0_writing = (bank_0_state == WRITE_1 || bank_0_state == WRITE_2 || bank_0_state == WRITE_3);
    assign bank_1_writing = (bank_1_state == WRITE_1 || bank_1_state == WRITE_2 || bank_1_state == WRITE_3);
    assign bank_2_writing = (bank_2_state == WRITE_1 || bank_2_state == WRITE_2 || bank_2_state == WRITE_3);
    assign bank_3_writing = (bank_3_state == WRITE_1 || bank_3_state == WRITE_2 || bank_3_state == WRITE_3);
    assign any_bank_writing = (bank_0_writing || bank_1_writing || bank_2_writing || bank_3_writing);

    assign DQ = writing ? ddr_byte : 'z;
    assign dq = DQ;
    assign DQS = writing ? w_dqs : 'z;
    assign r_dqs = DQS;

    // Multiplexer for Output FIFO to AXI
    assign mux_data = raw_strobe ? raw_data : dram_data;

endmodule
