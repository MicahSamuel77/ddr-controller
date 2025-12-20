`timescale 1ns / 10ps

`include "type_pkg.vh"

import type_pkg::write_info_t;
import type_pkg::burst_size_t;


module write_command_pool #(
    parameter DEPTH = 8,
    parameter LOG2_DEPTH = 3,
    parameter DATA_SIZE = 64,
    parameter ADDR_SIZE = 8
) (
    input logic clk, n_rst,
    input logic wstrobe, write_issued,
    input logic [1:0] burst_size,
    input logic [DATA_SIZE-1:0] wdata,
    input logic [ADDR_SIZE-1:0] waddr,
    // input logic [TID_SIZE-1:0] wtid,
    output logic werr, wfull, wready,
    output burst_size_t pool_wburst_size, wburst_size_pop,
    output logic [DATA_SIZE-1:0] pool_wdata,
    output logic [ADDR_SIZE-1:0] pool_waddr,
    output logic wready2,
    output burst_size_t pool_wburst_size2,
    output logic [ADDR_SIZE-1:0] pool_waddr2
    // output logic [TID_SIZE-1:0] pool_wtid
);
    import type_pkg::*;

    write_info_t [DEPTH-1:0] fifo, next_fifo;
    burst_size_t next_wburst_size_pop;
    logic [LOG2_DEPTH-1:0] wptr, next_wptr, rptr, next_rptr;
    logic [LOG2_DEPTH:0] count, write_count, next_count;
    logic empty, next_werr;
    logic rptr2;
    logic next_rptr2;

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            fifo <= '{default: 0};
            wptr <= 0;
            count <= 0;
            werr <= 0;
            rptr <= 0;
            rptr2 <= 1;
            wburst_size_pop <= ONE_BYTE;
        end else begin
            fifo <= next_fifo;
            wptr <= next_wptr;
            count <= next_count;
            werr <= next_werr;
            rptr <= next_rptr;
            rptr2 <= next_rptr2;
            wburst_size_pop <= next_wburst_size_pop;
        end
    end

    // FULL AND EMPTY FIFO LOGIC
    assign wfull = (count == DEPTH);
    assign empty = (count == 0);

    // WRITING LOGIC
    always_comb begin
        next_fifo = fifo;
        next_wptr = wptr;
        next_werr = 0;
        write_count = count;

        if (wstrobe) begin
            if (!wfull) begin
                next_fifo[wptr].data = wdata;
                next_fifo[wptr].addr = waddr;
                next_fifo[wptr].burst_size = burst_size_t'(burst_size);
                next_wptr = wptr + 1;
                write_count = count + 1;
            end else begin
                next_werr = 1;
            end
        end
    end

    // READING LOGIC
    always_comb begin
        next_rptr = rptr;
        next_rptr2 = rptr2;
        next_count = write_count;
        if (write_issued) begin
            next_rptr = rptr + 1;
            next_count = write_count - 1;
            next_rptr2 = rptr2 + 1;
        end
    end

    // OUTPUT LOGIC
    assign pool_wdata = fifo[rptr].data;
    assign pool_waddr = fifo[rptr].addr;
    assign pool_wburst_size = fifo[rptr].burst_size;
    assign wready = !empty;

    assign pool_waddr2 = fifo[rptr2].addr;
    assign pool_wburst_size2 = fifo[rptr2].burst_size;
    assign wready2 = count > 1;

    always_comb begin
        next_wburst_size_pop = wburst_size_pop;
        if (write_issued) begin
            next_wburst_size_pop = fifo[rptr].burst_size;
        end
    end
endmodule
