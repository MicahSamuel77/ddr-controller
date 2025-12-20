`timescale 1ns / 10ps

`include "type_pkg.vh"

import type_pkg::burst_size_t;

module read_command_pool #(
    parameter ADDR_SIZE = 8,
    parameter TID_SIZE = 2
) (
    input logic clk, n_rst,
    input logic rstrobe, read_issued, rbusy, wready,
    input logic [1:0] burst_size,
    input logic [ADDR_SIZE-1:0] raddr, pool_waddr,
    input logic [TID_SIZE-1:0] tid_in,
    input burst_size_t pool_wburst_size,
    output logic rfull, rerr, rready, raw, tid_strobe,
    output logic [ADDR_SIZE-1:0] pool_raddr, raddr_raw,
    output logic [TID_SIZE-1:0] tid_pop,
    output burst_size_t pool_rburst_size, rburst_size_pop, rburst_size_raw,
    output logic rready2,
    output logic [ADDR_SIZE-1:0] pool_raddr2,
    output burst_size_t pool_rburst_size2
);
    import type_pkg::read_info_t;
    import type_pkg::*;

    // Basic params for readability
    localparam DEPTH = 8;
    localparam LOG2_DEPTH = 3;
    localparam STRUCTSIZE = ADDR_SIZE + TID_SIZE + 2;
    localparam logic [STRUCTSIZE-1:0] ZERO = '0;

    read_info_t [DEPTH-1:0]read_pool, next_read_pool;
    logic [3:0] first_tid;
    logic [TID_SIZE-1:0] next_tid_pop;
    logic next_rerr, next_tid_strobe;
    logic [LOG2_DEPTH:0] size, next_size, postpop_size, raw_depth;
    burst_size_t next_rburst_size_pop;

    // Helper signals
    wire pop_command;
    assign pop_command = read_issued && rready;

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            read_pool <= '{default: 0};
            tid_pop <= 0;
            rerr <= 0;
            size <= 0;
            rburst_size_pop <= burst_size_t'(0);
            tid_strobe <= 0;
        end else begin
            read_pool <= next_read_pool;
            tid_pop <= next_tid_pop;
            rerr <= next_rerr;
            size <= next_size;
            rburst_size_pop <= next_rburst_size_pop;
            tid_strobe <= next_tid_strobe;
        end
    end

    // RAW CHECKING generate block (might need to register raw, could cause issue with write data stream for raw)
    always_comb begin
        raw = 0;
        raw_depth = 0;
        first_tid = 4'b0;
        
        if (!rbusy && wready && !pop_command) begin // don't do anything if rbusy, can be commented out (just to not have a raw and ddr data value pushing at the same time)
            for (integer i = 0; i < DEPTH; i++) begin : raw_check
                if (i < size) begin
                    if (!first_tid[read_pool[i].tid]) begin // check if tid is the first of its kind in the rcp
                        first_tid[read_pool[i].tid] = 1;
                        if (read_pool[i].burst_size == pool_wburst_size) begin // checkss to make sure same burst size
                            if (read_pool[i].addr[ADDR_SIZE-1:3] == pool_waddr[ADDR_SIZE-1:3]) begin // checks row and bank address
                                unique case (burst_size)
                                    EIGHT_BYTES: begin
                                        raw = 1;
                                        raw_depth = i[LOG2_DEPTH:0];
                                    end
                                    FOUR_BYTES: begin
                                        if (read_pool[i].addr[2] == pool_waddr[2]) begin
                                            raw = 1;
                                            raw_depth = i[LOG2_DEPTH:0];
                                        end
                                    end
                                    TWO_BYTES: begin
                                        if (read_pool[i].addr[2:1] == pool_waddr[2:1]) begin
                                            raw = 1;
                                            raw_depth = i[LOG2_DEPTH:0];
                                        end
                                    end
                                    ONE_BYTE: begin
                                        if (read_pool[i].addr[2:0] == pool_waddr[2:0]) begin
                                            raw = 1;
                                            raw_depth = i[LOG2_DEPTH:0];
                                        end
                                    end
                                endcase
                            end
                        end
                    end
                end
            end
        end
    end

    // POPPING / Removing from FIFO always_comb block
    // under assumption that a raw error showing and issuing a read command can't happen at the same time
    always_comb begin
        next_read_pool = read_pool;
        next_rburst_size_pop = burst_size_t'(rburst_size_pop);
        next_tid_pop = tid_pop;
        postpop_size = size;
        next_tid_strobe = 0;
        next_rerr = 0;
        rburst_size_raw = burst_size_t'(rburst_size_pop);
        raddr_raw = pool_raddr;
        if (pop_command) begin
            next_read_pool = read_pool >> (ADDR_SIZE+TID_SIZE+2);
            next_tid_pop = read_pool[0].tid;
            next_rburst_size_pop = read_pool[0].burst_size;
            next_tid_strobe = 1;
            postpop_size = size - 1;
        end else if (raw) begin
            // try to find a concept that allows this to variably expand depth (ask later)
            case (raw_depth)
                0: next_read_pool = {ZERO, read_pool[(DEPTH-1):1]};
                1: next_read_pool = {ZERO, read_pool[(DEPTH-1):2], read_pool[0]};
                2: next_read_pool = {ZERO, read_pool[(DEPTH-1):3], read_pool[1:0]};
                3: next_read_pool = {ZERO, read_pool[(DEPTH-1):4], read_pool[2:0]};
                4: next_read_pool = {ZERO, read_pool[(DEPTH-1):5], read_pool[3:0]};
                5: next_read_pool = {ZERO, read_pool[(DEPTH-1):6], read_pool[4:0]};
                6: next_read_pool = {ZERO, read_pool[(DEPTH-1)], read_pool[5:0]};
                7: next_read_pool = {ZERO, read_pool[6:0]};
                default:;
            endcase
            rburst_size_raw = read_pool[raw_depth].burst_size;
            raddr_raw = read_pool[raw_depth].addr;
            next_tid_pop = read_pool[raw_depth].tid;
            next_rburst_size_pop = read_pool[raw_depth].burst_size;
            next_tid_strobe = 1;
            postpop_size = size - 1;
        end
        // Adding another transaction
        next_size = postpop_size;
        if (rstrobe) begin
            if (next_size == DEPTH) begin
                next_rerr = 1;
            end else begin
                next_read_pool[next_size].burst_size = burst_size_t'(burst_size);
                next_read_pool[next_size].addr = raddr;
                next_read_pool[next_size].tid = tid_in;
                next_size = postpop_size + 1;
            end
        end
    end

    // Output signals
    assign rready = (size != 0);
    assign rfull = (next_size == DEPTH);
    assign pool_raddr = read_pool[0].addr;
    assign pool_rburst_size = read_pool[0].burst_size;

    assign rready2 = (size > 1);
    assign pool_raddr2 = read_pool[1].addr;
    assign pool_rburst_size2 = read_pool[1].burst_size;

endmodule
