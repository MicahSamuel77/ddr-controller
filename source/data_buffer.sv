`timescale 1ns / 10ps

`include "type_pkg.vh"

module data_buffer #(
    parameter DEPTH = 64,
    parameter LOG2_DEPTH = 6,
    parameter DATA_SIZE = 64,
    parameter TID_SIZE = 2
) (
    input logic clk, n_rst,
    input logic dram_strobe, raw_strobe, ren, tid_strobe,
    input logic [DATA_SIZE-1:0] mux_data,
    input logic [TID_SIZE-1:0] tid_pop,
    output logic rvalid,
    output logic [DATA_SIZE-1:0] rdata,
    output logic [TID_SIZE-1:0] tid_out
);
    import type_pkg::controller_outputs_t;

    // FIFO logic
    controller_outputs_t [DEPTH-1:0] fifo, next_fifo;
    logic [LOG2_DEPTH-1:0] wptr, next_wptr, tid_wptr, next_tid_wptr, rptr, next_rptr;
    logic [LOG2_DEPTH:0] count, write_count, next_count, tid_count, write_tid_count, next_tid_count;
    logic empty, full, tid_full;

    // Output Logic
    // logic [DATA_SIZE-1:0] next_rdata;
    // logic [TID_SIZE-1:0] next_tid_out;
    logic next_rvalid;


    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            fifo <= '{default: 0};
            wptr <= 0;
            rptr <= 0;
            tid_wptr <= 0;
            count <= 0;
            tid_count <= 0;
        end else begin
            fifo <= next_fifo;
            wptr <= next_wptr;
            rptr <= next_rptr;
            tid_wptr <= next_tid_wptr;
            count <= next_count;
            tid_count <= next_tid_count;
        end
    end

    // FULL AND EMPTY FIFO LOGIC
    assign full = (count == DEPTH);
    assign tid_full = (tid_count == DEPTH);
    assign empty = (count == 0);

    // WRITING LOGIC
    always_comb begin
        next_fifo = fifo;
        next_wptr = wptr;
        next_tid_wptr = tid_wptr;
        write_count = count;
        write_tid_count = tid_count;

        if (dram_strobe || raw_strobe) begin
            if (!full) begin
                next_fifo[wptr].data = mux_data;
                next_wptr = wptr + 1;
                write_count = count + 1;
            end
        end
        if (tid_strobe) begin
            if (!tid_full) begin
                next_fifo[tid_wptr].tid = tid_pop;
                next_tid_wptr = tid_wptr + 1;
                write_tid_count = tid_count + 1;
            end
        end
    end

    // READING LOGIC
    always_comb begin
        next_rptr = rptr;
        next_count = write_count;
        next_tid_count = write_tid_count;
        if (!empty && ren) begin
            next_rptr = rptr + 1;
            next_count = write_count - 1;
            next_tid_count = write_tid_count - 1;
        end
    end

    // OUTPUT LOGIC
    always_comb begin
        rdata = fifo[rptr].data;
        tid_out = fifo[rptr].tid;
        next_rvalid = (!(next_count == 0));
    end
    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            rvalid <= 0;
        end else begin
            rvalid <= next_rvalid;
        end
    end
endmodule
