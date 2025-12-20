`timescale 1ns / 10ps

`include "type_pkg.vh"

import type_pkg::priority_t;
import type_pkg::OPEN_PAGE_SAME_WE;
import type_pkg::OPEN_PAGE_DIF_WE;
import type_pkg::CLOSED_PAGE;
import type_pkg::CROSS_PAGE;

module timing_control #( ) (
    input logic clk, n_rst,

    // information from pool
    input logic [2:0] read_row, write_row,
    input logic [1:0] read_bank, write_bank,

    // last command info
    input logic read_issued, write_issued,
    input logic all_banks_closed,
    input logic [2:0] last_row,
    input logic [1:0] last_bank,

    // priority outputs
    output priority_t read_priority,
    output priority_t write_priority
);

    logic last_we;
    wire [4:0] read_addr;
    wire [4:0] write_addr;
    wire [4:0] last_addr;

    assign read_addr  = {read_row,  read_bank};
    assign write_addr = {write_row, write_bank};
    assign last_addr  = {last_row,  last_bank};
    
    always_ff @(posedge clk, negedge n_rst) begin : we_latch
        if      (~n_rst)        last_we <= 0;
        else if (read_issued)   last_we <= 1;
        else if (write_issued)  last_we <= 0;
    end

    always_comb begin : read_priority_calc
        if      (all_banks_closed)                      read_priority = CLOSED_PAGE;
        else if (read_addr == last_addr && last_we)     read_priority = OPEN_PAGE_SAME_WE;
        else if (read_addr == last_addr)                read_priority = OPEN_PAGE_DIF_WE;
        else if (read_row == last_row)                  read_priority = CLOSED_PAGE;
        else                                            read_priority = CROSS_PAGE;
    end

    always_comb begin : write_priority_calc
        if      (all_banks_closed)                      write_priority = CLOSED_PAGE;
        else if (write_addr == last_addr && ~last_we)   write_priority = OPEN_PAGE_SAME_WE;
        else if (write_addr == last_addr)               write_priority = OPEN_PAGE_DIF_WE;
        else if (write_row == last_row)                 write_priority = CLOSED_PAGE;
        else                                            write_priority = CROSS_PAGE;
    end

endmodule

