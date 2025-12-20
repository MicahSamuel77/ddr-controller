`timescale 1ns / 10ps

`include "type_pkg.vh"

import type_pkg::burst_size_t;
import type_pkg::bank_status_t;
import type_pkg::bank_states_t;

module bank_monitor #(
    parameter BANK_NUM = 1
) (
    input logic clk, n_rst,

    // command / address
    input logic CS, CAS, RAS, WE,
    input logic [1:0] B,

    // burst sizes
    input burst_size_t pool_rburst_size,
    input burst_size_t pool_wburst_size,

    // status
    output bank_status_t bank_status,
    output bank_states_t bank_state
);
    import type_pkg::*;

    logic clear;
    logic count_enable;
    logic rollover_flag;
    logic [2:0] rollover_val;
    burst_size_t popped_burst_size, actual_burst_size;

    (* keep *) bank_states_t next_bank_state;
    commands_t command;

    assign command = commands_t'({CS, RAS, CAS, WE});

    single_edge_counter #(.SIZE(3)) bm_sec (
        .clk(clk), .n_rst(n_rst),
        .clear(clear),
        .count_enable(count_enable),
        .rollover_val(rollover_val),
        .rollover_flag(rollover_flag),

        /* verilator lint_off PINCONNECTEMPTY */
        .count_out()
        /* verilator lint_on PINCONNECTEMPTY */
    );

    always_ff @(posedge clk, negedge n_rst) begin : state_ff
        if (~n_rst) bank_state  <= IDLE_B;
        else        bank_state  <= next_bank_state;
    end

    always_ff @(posedge clk, negedge n_rst) begin : burst_size_ff
        if      (~n_rst)            popped_burst_size <= ONE_BYTE;
        else if (command == READ)   popped_burst_size <= pool_rburst_size;
        else if (command == WRITE)  popped_burst_size <= pool_wburst_size;
    end

    always_comb begin : burst_size_decider
        if      (command == READ)   actual_burst_size = pool_rburst_size;
        else if (command == WRITE)  actual_burst_size = pool_wburst_size;
        else                        actual_burst_size = popped_burst_size;
    end

    always_comb begin : bank_status_logic
        bank_status = BANK_NOT_READY;

        unique case (bank_state)
            IDLE_B:     bank_status = BANK_FULL_READY;
            ACTIVE_B:   bank_status = BANK_FULL_READY;
            READ_3:     bank_status = BANK_READ_READY;
            WRITE_2:    bank_status = BANK_WRITE_READY;
            READ_4:     bank_status = BANK_READ_READY;
            WRITE_3:    bank_status = BANK_WRITE_READY;
            default:    begin end
        endcase
    end

    always_comb begin : counter_logic
        clear           = 0;
        count_enable    = 0;
        rollover_val    = 0;

        unique case (bank_state)
            IDLE_B: begin
                clear        = 1;
            end PRECHARGING_B: begin
                count_enable = 1;
                rollover_val = 1;
            end ACTIVE_B: begin
                clear        = 1;
            end ACTIVATING_B: begin
                count_enable = 1;
                rollover_val = 1;
            end READ_3: begin
                count_enable = 1;
                rollover_val = (actual_burst_size == EIGHT_BYTES);
            end WRITE_1: begin
                count_enable = 1;
                rollover_val = 1;
            end WRITE_2: begin
                clear = 1;
            end MODE_REGISTER_SET_B: begin
                count_enable = 1;
                rollover_val = 1;
            end
            default: begin end
        endcase
    end

    always_comb begin : next_state_logic
        next_bank_state = bank_state;

        unique case(bank_state)
            IDLE_B: begin
                if      (command == MODE_REGISTER_SET)          next_bank_state = MODE_REGISTER_SET_B;
                else if (command == ACTIVE && B == BANK_NUM)    next_bank_state = ACTIVATING_B;
            end PRECHARGING_B: begin
                if      (rollover_flag)                         next_bank_state = IDLE_B;
            end ACTIVE_B: begin
                if      (command == READ && B == BANK_NUM)      next_bank_state = pool_rburst_size  < EIGHT_BYTES ? READ_3 : READ_1;
                else if (command == WRITE && B == BANK_NUM)     next_bank_state = pool_wburst_size  < EIGHT_BYTES ? WRITE_2 : WRITE_1;
                else if (command == PRECHARGE)                  next_bank_state = PRECHARGING_B; // TODO input A and check for A[10] || B == BANK_NUM
            end ACTIVATING_B: begin
                if      (rollover_flag)                         next_bank_state = ACTIVE_B;
            end READ_1: begin 
                                                                next_bank_state = READ_2;
            end READ_2: begin
                if ((command == READ && B == BANK_NUM)) begin
                    if      (actual_burst_size == EIGHT_BYTES)  next_bank_state = READ_1;
                    else if (actual_burst_size == FOUR_BYTES)   next_bank_state = READ_2;
                end else                                        next_bank_state = READ_3;
            end READ_3: begin
                if ((command == READ && B == BANK_NUM)) begin
                    if      (actual_burst_size == EIGHT_BYTES)  next_bank_state = READ_1;
                    else if (actual_burst_size == FOUR_BYTES)   next_bank_state = READ_2;
                    else                                        next_bank_state = READ_3;
                end else if (rollover_flag)                     next_bank_state = READ_4;
            end READ_4: begin
                if ((command == READ && B == BANK_NUM)) begin
                    if      (actual_burst_size == EIGHT_BYTES)  next_bank_state = READ_1;
                    else if (actual_burst_size == FOUR_BYTES)   next_bank_state = READ_2;
                    else                                        next_bank_state = READ_3;
                end else                                        next_bank_state = ACTIVE_B;
            end WRITE_1: begin
                if (rollover_flag && 
                    !(command == WRITE &&
                    B == BANK_NUM))                             next_bank_state = WRITE_2;
                else if (rollover_flag)                         next_bank_state = WRITE_1;
            end WRITE_2: begin
                if      (command == WRITE && B == BANK_NUM)     next_bank_state = pool_wburst_size < EIGHT_BYTES ? WRITE_2 : WRITE_1;
                else                                            next_bank_state = actual_burst_size < FOUR_BYTES ? ACTIVE_B : WRITE_3;
            end WRITE_3: begin
                if      (command == WRITE && B == BANK_NUM)     next_bank_state = pool_wburst_size < EIGHT_BYTES ? WRITE_2 : WRITE_1;
                else                                            next_bank_state = ACTIVE_B;
            end MODE_REGISTER_SET_B: begin
                if      (rollover_flag)                         next_bank_state = IDLE_B;
            end default: begin end
        endcase
    end

endmodule
