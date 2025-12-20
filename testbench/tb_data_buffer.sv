`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_data_buffer ();

    localparam CLK_PERIOD = 10ns;

    localparam DEPTH = 4;
    localparam LOG2_DEPTH = 2;
    localparam DATA_SIZE = 64;
    localparam TID_SIZE = 2;
    logic clk, n_rst, dram_strobe, raw_strobe, ren, tid_strobe;
    logic [DATA_SIZE-1:0] mux_data;
    logic [TID_SIZE-1:0] tid_in;

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars;
    end

    // clockgen
    always begin
        clk = 0;
        #(CLK_PERIOD / 2.0);
        clk = 1;
        #(CLK_PERIOD / 2.0);
    end

    assign n_clk = ~clk;

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

    data_buffer #(
    ) DUT (
        .clk(clk),
        .n_rst(n_rst),
        .strobe(dram_strobe),
        .raw_strobe(raw_strobe),
        .ren(ren),
        .tid_strobe(tid_strobe),
        .mux_data(mux_data),
        .tid_pop(tid_in),
        /* verilator lint_off PINCONNECTEMPTY */
        .rvalid(),
        .err(),
        .rdata(),
        .tid_out()
        /* verilator lint_on PINCONNECTEMPTY */
    );

    task push_write;
        input logic[DATA_SIZE-1:0] data;
        input logic[TID_SIZE-1:0] tid_f, tid_p;
        input logic raw;
    begin
        @(negedge clk);
        mux_data = data;
        tid_first = tid_f;
        tid_pop = tid_p;
        raw_strobe = raw;
        strobe = ~raw;
        @(posedge clk);
        raw_strobe = 0;
        strobe = 0;
        @(negedge clk);
    end
    endtask

    task push_multiple_writes;
        input logic [TID_SIZE-1:0] tid_f, tid_p;
        input integer num;
        input logic[3:0][DATA_SIZE-1:0] data;
        input logic raw;
        integer i;
    begin
        @(negedge clk);
        raw_strobe = raw;
        strobe = ~raw;
        for (i = 0; i < num; i++) begin
            mux_data = data[i];
            tid_first = tid_f;
            tid_pop = tid_p;
            if (i[0] == 0) @(posedge clk);
            else @(negedge clk);
        end
        raw_strobe = 0;
        strobe = 0;
        @(negedge clk);
    end
    endtask

    task wait_clk;
        input integer num;
        integer i;
    begin
        for (i = 0; i < num; i++) begin
            @(negedge clk);
        end
    end
    endtask

    initial begin
        @(negedge clk);
        strobe = 0;
        raw_strobe = 0;
        mux_data = 0;
        tid_first = 0;
        tid_pop = 0;
        reset_dut();
        push_write(.data(64'h969a715486742821), .tid_f(2'd0), .tid_p(2'd0), .raw(0));
        wait_clk(.num(2));
        push_multiple_writes(.data({64'h58cfc76aeb65e251, 64'ha2189777a7ae5f05, 64'h096f19ca7556b648, 64'h4fa3a67a1b4c680b}), .tid_f(1), .tid_p(1), .raw(1), .num(4));
        push_multiple_writes(.data({64'h5, 64'h6, 64'h7, 64'h8}), .tid_f(2), .tid_p(2), .raw(0), .num(4));
        wait_clk(.num(4));
        push_write(.data(64'hf9), .tid_f(2'd3), .tid_p(2'd3), .raw(1));
        wait_clk(.num(2));
        $finish;
    end
endmodule

/* verilator coverage_on */

