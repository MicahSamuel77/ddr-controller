`timescale 1ns / 10ps

`include "type_pkg.vh"

import type_pkg::write_burst_states_t;
import type_pkg::burst_size_t;


module burst_to_byte (
    input logic clk, n_rst,
    input logic DQ_oe,
    input logic [63:0] pool_wdata,
    input burst_size_t wburst_size_pop,
    output logic w_dqs,
    output logic [7:0] ddr_byte
);
    import type_pkg::*;

    write_burst_states_t state, next_state;
    logic [63:0] reg_wdata, next_reg_wdata, delay_reg_wdata;
    logic[15:0] twobyte;
    logic next_w_dqs, preclk_w_dqs, b2b, next_b2b;

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            state <= WIDLE;
            preclk_w_dqs <= 0;
            b2b <= 0;
            reg_wdata <= 0;
        end else begin
            state <= next_state;
            preclk_w_dqs <= next_w_dqs;
            b2b <= next_b2b;
            reg_wdata <= next_reg_wdata;
        end
    end

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst)
            delay_reg_wdata <= 0;
        else
            delay_reg_wdata <= reg_wdata;
    end

    always_comb begin
        next_reg_wdata = reg_wdata;
        next_b2b = 0;
        if (DQ_oe) begin
            next_reg_wdata = pool_wdata;
            next_b2b = 1;
        end
    end

    // NEXT STATE LOGIC
    always_comb begin
        next_state = state;
        if (state == WIDLE) begin
            if (b2b)        next_state = WBURST12;
            else if (DQ_oe) next_state = WWAIT;
        end else if (state == WWAIT) begin
            next_state = WBURST12;
        end else if (state == WBURST12) begin
            if (wburst_size_pop == FOUR_BYTES || wburst_size_pop == EIGHT_BYTES) next_state = WBURST4;
            else if (b2b)                                                        next_state = WBURST12;
            else                                                                 next_state = WIDLE;
        end else if (state == WBURST4) begin
            if (wburst_size_pop == EIGHT_BYTES) next_state = WBURST6;
            else if (b2b)                       next_state = WBURST12;
            else                                next_state = WIDLE;
        end else if (state == WBURST6) begin
            next_state = WBURST8;
        end else if (state == WBURST8) begin
            if (b2b)                            next_state = WBURST12;
            else                                next_state = WIDLE;
        end
    end

    // NEXT TWOBYTE LOGIC
    always_comb begin
        twobyte = 16'b0;
        unique case (state)
            WIDLE:    twobyte = 'z;
            WWAIT:    twobyte = 'z;
            WBURST12: twobyte = delay_reg_wdata[15:0];
            WBURST4:  twobyte = delay_reg_wdata[31:16];
            WBURST6:  twobyte = delay_reg_wdata[47:32];
            WBURST8:  twobyte = delay_reg_wdata[63:48];
            default:;
        endcase
    end

    // NEXT w_dqs LOGIC
    always_comb begin
        next_w_dqs = 0;
        if (next_state == WBURST12 || next_state == WBURST4 || next_state == WBURST6 || next_state == WBURST8) begin
            next_w_dqs = 1;
        end
    end

    assign ddr_byte = clk ? twobyte[7:0]: twobyte[15:8];
    assign w_dqs = (state == WIDLE || state == WWAIT) ? 'z : clk ? preclk_w_dqs : 1'b0;

endmodule
