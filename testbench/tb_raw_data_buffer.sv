`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_raw_data_buffer ();

    localparam CLK_PERIOD = 10ns;

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars;
    end

    localparam ADDR_SIZE = 8;
    localparam DATA_SIZE = 64;
    logic clk, n_rst, raw;
    logic [1:0] burst_size;
    logic [ADDR_SIZE-1:0] raddr, waddr;
    logic [DATA_SIZE-1:0] data;

    // clockgen
    always begin
        clk = 0;
        #(CLK_PERIOD / 2.0);
        clk = 1;
        #(CLK_PERIOD / 2.0);
    end

    task reset_dut;
    begin
        n_rst = 0;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        n_rst = 1;
        @(posedge clk);
        @(posedge clk);
    end
    endtask

    raw_data_buffer DUT (
        .clk(clk),
        .n_rst(n_rst),
        .raw(raw),
        .burst_size_pop(burst_size),
        .raddr_pop(raddr),
        .pool_waddr(waddr),
        .pool_wdata(data)
    );

    task raw_data_input;
        input logic [1:0] size;
        input logic [ADDR_SIZE-1:0] r_addr, w_addr;
        input logic [DATA_SIZE-1:0] wdata;
    begin
        @(negedge clk);
        raw = 1;
        burst_size = size;
        raddr = r_addr;
        waddr = w_addr;
        data = wdata;
        @(negedge clk);
        raw = 0;
        @(negedge clk);
    end
    endtask

    initial begin
        n_rst = 1;
        burst_size = 0;
        raw = 0;
        raddr = 0;
        waddr = 0;
        data = 0;

        reset_dut;

        // BURST_SIZE 0
        raw_data_input(.size(0), .r_addr(8'h9e), .w_addr(8'h9e), .wdata(64'haddb6f04fefee338));

        // BURST_SIZE 1
        raw_data_input(.size(1), .r_addr(8'ha4), .w_addr(8'ha4), .wdata(64'h659829ff4ebc7f61));

        // BURST_SIZE 2
        raw_data_input(.size(2), .r_addr(8'he1), .w_addr(8'he1), .wdata(64'ha9b0ff8f7c585a12));

        // BURST_SIZE 3
        // W > R
        raw_data_input(.size(3), .r_addr(8'h0), .w_addr(8'h6), .wdata(64'hf38fc74d3141c136)); // w 6> r
        raw_data_input(.size(3), .r_addr(8'hf8), .w_addr(8'hf9), .wdata(64'hbca7dbca1b3928b3)); // w 1> r
        
        // R > W
        raw_data_input(.size(3), .r_addr(8'h5), .w_addr(8'h0), .wdata(64'hf6677c2639c176ef)); // w <5 r
        raw_data_input(.size(3), .r_addr(8'he7), .w_addr(8'he4), .wdata(64'ha7ce5739b03a39e0)); // w <3 r

        // SAME
        raw_data_input(.size(3), .r_addr(8'hff), .w_addr(8'hff), .wdata(64'h0c6ab98ddae5d0e9));

        $finish;
    end
endmodule

/* verilator coverage_on */

