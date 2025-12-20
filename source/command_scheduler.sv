`timescale 1ns / 10ps

`include "type_pkg.vh"

import type_pkg::burst_size_t;
import type_pkg::priority_t;
import type_pkg::bank_status_t;
import type_pkg::bank_states_t;

module command_scheduler #() (
    input logic clk, n_clk, n_rst,

    // mode register settings from AXI
    input logic [1:0] burst_size,
    input logic MRS,

    // interface w/ maintenance command queue
    input logic issue_cmd,
    output logic cmd_issued,

    // interface w/ read command pool
    input burst_size_t pool_rburst_size, pool_rburst_size2,
    input logic rready, rready2, raw,
    input logic [7:0] pool_raddr, pool_raddr2,
    output logic read_issued,
    output logic read_in_progress,
    
    // interface w/ timing control
    output logic [2:0] last_row,
    output logic [1:0] last_bank,
    output logic all_banks_closed,
    input priority_t write_priority, read_priority,

    // interface w/ write command pool
    input burst_size_t pool_wburst_size, pool_wburst_size2,
    input logic wready, wready2,
    input logic [7:0] pool_waddr, pool_waddr2,
    output logic write_issued,

    // interface w/ dram
    output logic CK, N_CK, CKE, CS, RAS, CAS, WE,
    output logic [1:0] B,
    output logic [13:0] A,
    
    // interface w/ data controller
    output logic DQ_oe,

    // interface w/ bank controllers
    input bank_status_t bank_0_status,
    input bank_status_t bank_1_status,
    input bank_status_t bank_2_status,
    input bank_status_t bank_3_status,
    input bank_states_t  bank_0_state,
    input bank_states_t  bank_1_state,
    input bank_states_t  bank_2_state,
    input bank_states_t  bank_3_state
);

    import type_pkg::*;

    typedef enum bit [5:0] {
        // init states
        INIT_0,
        INIT_1,
        INIT_2,
        POST_INIT_2,
        INIT_3,
        POST_INIT_3,
        INIT_4,
        INIT_5,
        POST_INIT_5,
        INIT_6,
        POST_INIT_6,
        INIT_7,
        POST_INIT_7,

        // basic states
        IDLE_C,
        REFRESH_C,
        POST_REFRESH_C,
        R_PRECHARGE_C,
        POST_R_PRECHARGE_C,
        MRS_PRECHARGE_C,
        POST_MRS_PRECHARGE_C,
        MODE_REGISTER_SET_C,
        POST_MODE_REGISTER_SET_C,

        // read states
        READ_PRECHARGE_C,
        POST_READ_PRECHARGE_C,
        READ_ACTIVE_C,
        POST_READ_ACTIVE_C,
        READ_C,

        // write states
        WRITE_PRECHARGE_C,
        POST_WRITE_PRECHARGE_C,
        WRITE_ACTIVE_C,
        POST_WRITE_ACTIVE_C,
        WRITE_C
    } command_states_t;
    command_states_t cmd_state, next_cmd_state;

    // logic clear;
    logic count_enable;
    logic rollover_flag;
    logic [10:0] rollover_val;

    single_edge_counter #(.SIZE(11)) cs_sec (
        .clk(clk), .n_rst(n_rst),
        .clear(1'b0),
        .count_enable(count_enable),
        .rollover_val(rollover_val),
        .rollover_flag(rollover_flag),

        /* verilator lint_off PINCONNECTEMPTY */
        .count_out()
        /* verilator lint_on PINCONNECTEMPTY */
    );

    // output assigns
    commands_t command;
    assign CK                   = clk;
    assign N_CK                 = n_clk;
    assign {CS, RAS, CAS, WE}   = command;
    assign DQ_oe                =  write_issued;

    // address splitting for more readable logic
    wire [2:0] read_row;
    wire [1:0] read_bank;
    wire [2:0] read_col;
    wire [2:0] write_row;
    wire [1:0] write_bank;
    wire [2:0] write_col;
    assign {read_row, read_bank, read_col}      = pool_raddr;
    assign {write_row, write_bank, write_col}   = pool_waddr;

    // status logic to help state logic / read command pool
    wire all_banks_ready;
    wire close_banks;
    wire open_a_bank;
    assign all_banks_ready      =   bank_0_status   == BANK_FULL_READY && 
                                    bank_1_status   == BANK_FULL_READY && 
                                    bank_2_status   == BANK_FULL_READY && 
                                    bank_3_status   == BANK_FULL_READY;
    assign close_banks          =   cmd_state       == MODE_REGISTER_SET_C ||
                                    cmd_state       == REFRESH_C;
    assign open_a_bank          =   cmd_state       == READ_ACTIVE_C || 
                                    cmd_state       == WRITE_ACTIVE_C;
    assign read_in_progress     =   cmd_state       == READ_PRECHARGE_C ||
                                    cmd_state       == READ_ACTIVE_C    ||
                                    cmd_state       == READ_C;

    // priority logic to help state logic 
    wire read_next;
    wire write_next;
    wire read_overlap;
    wire write_overlap;
    assign read_next                = (rready && (read_priority < write_priority)) || (rready && ~wready);
    assign write_next               = (wready && (write_priority < read_priority)) || (~rready && wready);
    assign read_overlap             = (rready2 && (pool_rburst_size == pool_rburst_size2) 
                                    && (pool_raddr[7:3] == pool_raddr2[7:3])
                                    && (pool_rburst_size < FOUR_BYTES));
    assign write_overlap            = (wready2 && (pool_wburst_size == pool_wburst_size2) 
                                    && (pool_waddr[7:3] == pool_waddr2[7:3])
                                    && (pool_wburst_size < FOUR_BYTES));

    // burst logic to prevent mismatch between command and mode register burst sizes
    wire old_burst_reads_left;
    wire old_burst_writes_left;
    wire no_old_bursts_left;
    assign old_burst_reads_left     = ((burst_size != pool_rburst_size) && rready);
    assign old_burst_writes_left    = ((burst_size != pool_wburst_size) && wready);
    assign no_old_bursts_left       = !old_burst_reads_left && !old_burst_writes_left;

    // page access logic to help state logic
    wire open_page_read;
    wire closed_page_read;
    wire cross_page_read;
    wire open_page_write;
    wire closed_page_write;
    wire cross_page_write;
    assign open_page_read           = ((read_row  == last_row) && (read_bank  == last_bank) && (!all_banks_closed));
    assign closed_page_read         = ((read_row  == last_row) && (read_bank  != last_bank) || ( all_banks_closed));
    assign cross_page_read          = ((read_row  != last_row) &&                              (!all_banks_closed));
    assign open_page_write          = ((write_row == last_row) && (write_bank == last_bank) && (!all_banks_closed));
    assign closed_page_write        = ((write_row == last_row) && (write_bank != last_bank) || ( all_banks_closed));
    assign cross_page_write         = ((write_row != last_row) &&                              (!all_banks_closed));

    // ready logic to help state logic
    logic read_can_send;
    logic write_can_send;
    logic bank_can_close;
    always_comb begin : ready_logic
        unique case (read_bank)
            2'b00:  read_can_send   = (bank_0_status == BANK_READ_READY)  || (bank_0_status == BANK_FULL_READY);
            2'b01:  read_can_send   = (bank_1_status == BANK_READ_READY)  || (bank_1_status == BANK_FULL_READY);
            2'b10:  read_can_send   = (bank_2_status == BANK_READ_READY)  || (bank_2_status == BANK_FULL_READY);
            2'b11:  read_can_send   = (bank_3_status == BANK_READ_READY)  || (bank_3_status == BANK_FULL_READY);
        endcase

        unique case (write_bank)
            2'b00: write_can_send   = (bank_0_status == BANK_WRITE_READY) || (bank_0_status == BANK_FULL_READY);
            2'b01: write_can_send   = (bank_1_status == BANK_WRITE_READY) || (bank_1_status == BANK_FULL_READY);
            2'b10: write_can_send   = (bank_2_status == BANK_WRITE_READY) || (bank_2_status == BANK_FULL_READY);
            2'b11: write_can_send   = (bank_3_status == BANK_WRITE_READY) || (bank_3_status == BANK_FULL_READY);
        endcase

        unique case (last_bank)
            2'b00: bank_can_close   = (bank_0_status == BANK_FULL_READY || bank_0_state == READ_4);
            2'b01: bank_can_close   = (bank_1_status == BANK_FULL_READY || bank_1_state == READ_4);
            2'b11: bank_can_close   = (bank_3_status == BANK_FULL_READY || bank_2_state == READ_4);
            2'b10: bank_can_close   = (bank_2_status == BANK_FULL_READY || bank_3_state == READ_4);
        endcase
    end

    // raw logic to signal ddr controller to pause
    wire pause_for_raw;
    assign pause_for_raw =  raw && ((read_next && read_can_send) || 
                            (!(write_next && write_can_send) && (rready && read_can_send)));

    always_ff @(posedge clk, negedge n_rst) begin : cmd_state_ff
        if (~n_rst) cmd_state <= INIT_0;
        else        cmd_state <= next_cmd_state;
    end

    always_ff @(posedge clk, negedge n_rst) begin : last_addr_ff
        if      (~n_rst)        {last_row, last_bank} <= '0;
        else if (read_issued)   {last_row, last_bank} <= pool_raddr[7:3];
        else if (write_issued)  {last_row, last_bank} <= pool_waddr[7:3];
    end

    logic MRS_queued;
    always_ff @(posedge clk, negedge n_rst) begin : MRS_ff
        if      (~n_rst)                            MRS_queued <= 0;
        else if (MRS)                               MRS_queued <= 1;
        else if (cmd_state == MRS_PRECHARGE_C)      MRS_queued <= 0;
    end

    always_ff @(posedge clk, negedge n_rst) begin : banks_closed_ff
        if      (~n_rst)                            all_banks_closed <= 1;
        else if (close_banks)                       all_banks_closed <= 1;
        else if (open_a_bank)                       all_banks_closed <= 0;
    end

    always_comb begin : next_cmd_state_logic
        next_cmd_state = cmd_state;
        unique case (cmd_state)
            INIT_0:                     if (rollover_flag)  next_cmd_state = INIT_1;
            INIT_1:                     if (rollover_flag)  next_cmd_state = INIT_2;
            INIT_2:                                         next_cmd_state = POST_INIT_2;
            POST_INIT_2:                if (rollover_flag)  next_cmd_state = INIT_3;
            INIT_3:                                         next_cmd_state = POST_INIT_3;
            POST_INIT_3:                if (rollover_flag)  next_cmd_state = INIT_4;
            INIT_4:                     if (rollover_flag)  next_cmd_state = INIT_5;
            INIT_5:                                         next_cmd_state = POST_INIT_5;
            POST_INIT_5:                if (rollover_flag)  next_cmd_state = INIT_6;
            INIT_6:                                         next_cmd_state = POST_INIT_6;
            POST_INIT_6:                if (rollover_flag)  next_cmd_state = INIT_7;
            INIT_7:                                         next_cmd_state = POST_INIT_7;
            POST_INIT_7:                if (rollover_flag)  next_cmd_state = MODE_REGISTER_SET_C;

            R_PRECHARGE_C:                                  next_cmd_state = POST_R_PRECHARGE_C;
            POST_R_PRECHARGE_C:         if (rollover_flag)  next_cmd_state = REFRESH_C;
            REFRESH_C:                                      next_cmd_state = POST_REFRESH_C;
            POST_REFRESH_C:             if (rollover_flag)  next_cmd_state = IDLE_C;
            MRS_PRECHARGE_C:                                next_cmd_state = POST_MRS_PRECHARGE_C;
            POST_MRS_PRECHARGE_C:       if (rollover_flag)  next_cmd_state = MODE_REGISTER_SET_C;
            MODE_REGISTER_SET_C:                            next_cmd_state = POST_MODE_REGISTER_SET_C;
            POST_MODE_REGISTER_SET_C:   if (rollover_flag)  next_cmd_state = IDLE_C;

            IDLE_C: begin                                               // command is prioritized above all
                if      (issue_cmd)                                 next_cmd_state = all_banks_ready ? R_PRECHARGE_C    : IDLE_C;
                else if (MRS_queued && no_old_bursts_left)          next_cmd_state = all_banks_ready ? MRS_PRECHARGE_C  : IDLE_C;
                else if (pause_for_raw)                             next_cmd_state = IDLE_C;
                else if     (read_next && read_can_send) begin          // read is prioritized and can send
                    if          (open_page_read)                    next_cmd_state = READ_C;
                    else if     (closed_page_read)                  next_cmd_state = bank_can_close ? READ_ACTIVE_C     : IDLE_C;
                    else if     (cross_page_read)                   next_cmd_state = bank_can_close ? READ_PRECHARGE_C  : IDLE_C;
                end else if (write_next && write_can_send)  begin       // write is prioritized and can send
                    if          (open_page_write)                   next_cmd_state = WRITE_C;
                    else if     (closed_page_write)                 next_cmd_state = bank_can_close ? WRITE_ACTIVE_C    : IDLE_C;
                    else if     (cross_page_write)                  next_cmd_state = bank_can_close ? WRITE_PRECHARGE_C : IDLE_C;
                end else if (rready && read_can_send) begin             // read prio = write prio and read can send
                    if          (open_page_read)                    next_cmd_state = READ_C;
                    else if     (closed_page_read)                  next_cmd_state = bank_can_close ? READ_ACTIVE_C     : IDLE_C;
                    else if     (cross_page_read)                   next_cmd_state = bank_can_close ? READ_PRECHARGE_C  : IDLE_C;
                end else if (wready && write_can_send) begin            // read prio = write prio and write can send
                    if          (open_page_write)                   next_cmd_state = WRITE_C;
                    else if     (closed_page_write)                 next_cmd_state = bank_can_close ? WRITE_ACTIVE_C    : IDLE_C;
                    else if     (cross_page_write)                  next_cmd_state = bank_can_close ? WRITE_PRECHARGE_C : IDLE_C;   
                end
            end

            READ_PRECHARGE_C:                               next_cmd_state = POST_READ_PRECHARGE_C;
            POST_READ_PRECHARGE_C:      if (rollover_flag)  next_cmd_state = READ_ACTIVE_C;
            READ_ACTIVE_C:                                  next_cmd_state = POST_READ_ACTIVE_C;
            POST_READ_ACTIVE_C:         if (rollover_flag)  next_cmd_state = READ_C;
            READ_C:                                         next_cmd_state = read_overlap ? READ_C : IDLE_C;

            WRITE_PRECHARGE_C:                              next_cmd_state = POST_WRITE_PRECHARGE_C;
            POST_WRITE_PRECHARGE_C:     if (rollover_flag)  next_cmd_state = WRITE_ACTIVE_C;
            WRITE_ACTIVE_C:                                 next_cmd_state = POST_WRITE_ACTIVE_C;
            POST_WRITE_ACTIVE_C:        if (rollover_flag)  next_cmd_state = WRITE_C;
            WRITE_C:                                        next_cmd_state = write_overlap ? WRITE_C : IDLE_C;

            default: begin end
        endcase
    end

    always_comb begin : counter_outputs
        count_enable    = 1;
        rollover_val    = 0;
        unique case (cmd_state)
            INIT_0:                     rollover_val = 2000;
            INIT_1:                     rollover_val = 0;
            INIT_2:                     count_enable = 0;
            POST_INIT_2:                rollover_val = 1;
            INIT_3:                     count_enable = 0;
            POST_INIT_3:                rollover_val = 1;
            INIT_4:                     rollover_val = 199;
            INIT_5:                     count_enable = 0;
            POST_INIT_5:                rollover_val = 1;
            INIT_6:                     count_enable = 0;
            POST_INIT_6:                rollover_val = 199;
            INIT_7:                     count_enable = 0;
            POST_INIT_7:                rollover_val = 199;

            R_PRECHARGE_C:              count_enable = 0;
            POST_R_PRECHARGE_C:         rollover_val = 1;
            REFRESH_C:                  count_enable = 0;
            POST_REFRESH_C:             rollover_val = 199;
            MRS_PRECHARGE_C:            count_enable = 0;
            POST_MRS_PRECHARGE_C:       rollover_val = 1;
            MODE_REGISTER_SET_C:        count_enable = 0;
            POST_MODE_REGISTER_SET_C:   rollover_val = 1;
            IDLE_C:                     count_enable = 0;

            READ_PRECHARGE_C:           count_enable = 0;
            POST_READ_PRECHARGE_C:      rollover_val = 1;
            READ_ACTIVE_C:              count_enable = 0;
            POST_READ_ACTIVE_C:         rollover_val = 1;
            READ_C:                     count_enable = 0;

            WRITE_PRECHARGE_C:          count_enable = 0;
            POST_WRITE_PRECHARGE_C:     rollover_val = 1;
            WRITE_ACTIVE_C:             count_enable = 0;
            POST_WRITE_ACTIVE_C:        rollover_val = 1;
            WRITE_C:                    count_enable = 0;

            default: begin end
        endcase
    end

    always_comb begin : output_strobes_logic
        cmd_issued      = 0;
        read_issued     = 0;
        write_issued    = 0;
        unique case (cmd_state)
            REFRESH_C:  cmd_issued              = 1;
            READ_C:     read_issued             = 1;
            WRITE_C:    write_issued            = 1;
            default: begin end
        endcase
    end

    always_comb begin : output_command_logic
        command = NOP;
        CKE     = 1;
        unique case (cmd_state)
            INIT_0:                 {CKE, command} = {1'b0, DESELECT};
            INIT_1:                 command = NOP;
            INIT_2:                 command = PRECHARGE;
            INIT_3:                 command = MODE_REGISTER_SET;
            INIT_4:                 command = NOP;
            INIT_5:                 command = PRECHARGE;
            INIT_6:                 command = REFRESH;
            INIT_7:                 command = REFRESH;

            IDLE_C:                 {CKE, command} = {1'b0, DESELECT};
            R_PRECHARGE_C:          command = PRECHARGE;
            REFRESH_C:              command = REFRESH;
            MRS_PRECHARGE_C:        command = PRECHARGE;
            MODE_REGISTER_SET_C:    command = MODE_REGISTER_SET;

            READ_PRECHARGE_C:       command = PRECHARGE;
            READ_ACTIVE_C:          command = ACTIVE;
            READ_C:                 command = READ;

            WRITE_PRECHARGE_C:      command = PRECHARGE;
            WRITE_ACTIVE_C:         command = ACTIVE;
            WRITE_C:                command = WRITE;

            default: begin end
        endcase
    end

    always_comb begin : output_address_logic
        {B, A} = 16'b0;
        unique case (cmd_state)
            INIT_2:                 A[10] = 1;
            INIT_3:                 {B, A[6:4], A[1:0]} = {2'b0, 3'b010, burst_size};
            INIT_5:                 A[10] = 1;

            R_PRECHARGE_C:          A[10] = 1;
            MRS_PRECHARGE_C:        A[10] = 1;
            MODE_REGISTER_SET_C:    {B, A[6:4], A[1:0]} = {2'b0, 3'b010, burst_size};
            
            READ_PRECHARGE_C:       {B, A[10]}  = {last_bank, 1'b0};
            READ_ACTIVE_C:          {B, A[2:0]} = {read_bank, read_row};
            READ_C:                 {B, A[2:0]} = {read_bank, read_col};

            WRITE_PRECHARGE_C:      {B, A[10]}  = {last_bank, 1'b0};
            WRITE_ACTIVE_C:         {B, A[2:0]} = {write_bank, write_row};
            WRITE_C:                {B, A[2:0]} = {write_bank, write_col};

            default: begin end
        endcase
    end

endmodule
