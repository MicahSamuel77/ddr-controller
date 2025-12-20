`timescale 1ns / 10ps

`include "type_pkg.vh"

import type_pkg::read_burst_states_t;
import type_pkg::burst_size_t;

module dram_data_buffer #() (
    input logic clk, n_clk, n_rst,
    input logic r_dqs, read_issued,
    input burst_size_t rburst_size_pop,
    input logic [7:0] dq,
    output logic dram_strobe,
    output logic [63:0] dram_data
);
    import type_pkg::*;

    read_burst_states_t state, next_state;
    logic [63:0] next_dram_data;
    logic [7:0] negedge_dq;
    logic next_dram_strobe, negedge_r_dqs;

    // HELPER LOGIC
    wire burst_4_or_8;
    wire burst12_reached;
    wire burst4_reached;
    wire burst8_reached;
    assign burst_4_or_8 = (rburst_size_pop == FOUR_BYTES || rburst_size_pop == EIGHT_BYTES) && negedge_r_dqs;
    assign burst12_reached = (rburst_size_pop == ONE_BYTE || rburst_size_pop == TWO_BYTES) && negedge_r_dqs && state == RBURST12;
    assign burst4_reached = rburst_size_pop == FOUR_BYTES && state == RBURST4;
    assign burst8_reached = rburst_size_pop == EIGHT_BYTES && state == RBURST8;

    logic reading_dqs;
    logic [7:0] reading_data, a_reading_data, b_reading_data;
    logic delay1_read_issued, delay2_read_issued, delay3_read_issued;
    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            delay1_read_issued <= 0;
            delay2_read_issued <= 0;
        end else begin
            delay1_read_issued <= read_issued;
            delay2_read_issued <= delay1_read_issued;
        end
    end

    assign reading_dqs = (delay2_read_issued || state != RBURST12) ? r_dqs : 1'b0;
    assign reading_data = (delay2_read_issued || state != RBURST12) ? dq : 8'b0;

    // negedge reading of dq and r_dqs ff
    always_ff @(posedge n_clk, negedge n_rst) begin
        if (!n_rst) begin
            negedge_dq <= 0;
            negedge_r_dqs <= 0;
        end else begin
            negedge_dq <= reading_data;
            negedge_r_dqs <= reading_dqs;
        end
    end

    // dram_data ff
    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            state <= RIDLE;
            dram_data <= 0;
            dram_strobe <= 0;
        end else begin
            state <= next_state;
            dram_data <= next_dram_data;
            dram_strobe <= next_dram_strobe;
        end
    end

    // NEXT STATE LOGIC
    always_comb begin
        next_state = state;
        unique case (state)
            RIDLE:                              next_state = RBURST12;
            RBURST12: begin
                if (burst_4_or_8)               next_state = RBURST4;
                else                            next_state = RBURST12;
            end 
            RBURST4: begin
                if (rburst_size_pop == EIGHT_BYTES)  next_state = RBURST6;
                else                            next_state = RBURST12;
            end
            RBURST6:                            next_state = RBURST8;
            RBURST8:                            next_state = RBURST12;
            default:;
        endcase
    end

    // NEXT DRAM DATA LOGIC
    always_comb begin
        next_dram_data = dram_data;
        if (delay2_read_issued || state != RBURST12) begin
            unique case (state)
                RIDLE:   next_dram_data = 0;
                RBURST12: begin
                        if (rburst_size_pop == ONE_BYTE) next_dram_data = {56'b0, negedge_dq};
                        else next_dram_data = {48'b0, reading_data, negedge_dq};
                end
                RBURST4:  if (negedge_r_dqs) next_dram_data = {32'b0, reading_data, negedge_dq, dram_data[15:0]};
                RBURST6:  if (negedge_r_dqs) next_dram_data = {16'b0, reading_data, negedge_dq, dram_data[31:0]};
                RBURST8:  next_dram_data = {reading_data, negedge_dq, dram_data[47:0]};
                default:;
            endcase
        end
    end

    // PUSH / STROBE LOGIC
    always_comb begin
        next_dram_strobe = 0;
        if (burst12_reached)        next_dram_strobe = 1;
        else if (burst4_reached)    next_dram_strobe = 1;
        else if (burst8_reached)    next_dram_strobe = 1;
    end

endmodule

