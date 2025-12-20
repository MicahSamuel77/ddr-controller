`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_write_command_pool ();

    localparam CLK_PERIOD = 10ns;

    localparam DEPTH = 8;
    localparam LOG2_DEPTH = 3;
    localparam DATA_SIZE = 64;
    localparam ADDR_SIZE = 8;
    localparam TID_SIZE = 4;
    logic clk, n_rst, wstrobe, write_issued;
    logic [1:0] burst_size;
    logic [DATA_SIZE-1:0] wdata;
    logic [ADDR_SIZE-1:0] waddr;
    logic [TID_SIZE-1:0] wtid;

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

    write_command_pool DUT (
        .clk(clk),
        .n_rst(n_rst),
        .wstrobe(wstrobe),
        .write_issued(write_issued),
        .burst_size(burst_size),
        .wdata(wdata),
        .waddr(waddr),
        /* verilator lint_off PINCONNECTEMPTY */
        .wfull(),
        .werr(),
        .wready(),
        .pool_wdata(),
        .pool_waddr()
        /* verilator lint_on PINCONNECTEMPTY */
    );

    task push_write;
        input logic[DATA_SIZE-1:0] data;
        input logic[ADDR_SIZE-1:0] addr;
        input logic[TID_SIZE-1:0] tid;
    begin
        @(negedge clk);
        wdata = data;
        waddr = addr;
        wstrobe = 1;
        @(negedge clk);
        wstrobe = 0;
        @(negedge clk);
    end
    endtask

    task push_multiple_writes;
        input logic [TID_SIZE-1:0] tid;
        input integer num;
        input logic[7:0][DATA_SIZE-1:0] data;
        input logic[7:0][ADDR_SIZE-1:0] addr;
        integer i;
    begin
        @(negedge clk);
        wstrobe = 1;
        for (i = 0; i < num; i++) begin
            wdata = data[i];
            waddr = addr[i];
            @(negedge clk);
        end
        wstrobe = 0;
        @(negedge clk);
    end
    endtask

    task pop_fifo;
        input integer num;
        integer i;
    begin
        @(negedge clk);
        for (i = 0; i < num; i++) begin
            write_issued = 1;
            @(negedge clk);
        end
        write_issued = 0;
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
        wstrobe = 0;
        write_issued = 0;
        wdata = 0;
        waddr = 0;
        burst_size = 0;
        reset_dut();
        push_write(.data(64'h8c), .addr(8'h20), .tid(4'd0));
        pop_fifo(.num(1));
        burst_size = 1;
        push_multiple_writes(.data('{34, 204, 123, 245, 294, 49, 88, 1}), .addr('{0, 1, 2, 3, 4, 5, 6, 7}), .tid(0), .num(8));
        push_write(.data(64'h8c), .addr(8'h7), .tid(4'd8)); // CHECK FOR ERROR
        pop_fifo(.num(4));
        burst_size = 3;
        push_multiple_writes(.data('{1, 2, 3, 4, 5, 6, 7, 8}), .addr('{0, 0, 0, 0, 0, 60, 61, 62}), .tid(8), .num(3));
        pop_fifo(.num(7));
        $finish;
    end
endmodule

/* verilator coverage_on */

