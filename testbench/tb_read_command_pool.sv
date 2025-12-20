`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_read_command_pool ();

    localparam CLK_PERIOD = 10ns;

    localparam DEPTH = 8;
    localparam LOG2_DEPTH = 3;
    localparam ADDR_SIZE = 8;
    localparam TID_SIZE = 2;
    logic clk, n_rst, rstrobe, read_issued, wready;
    logic [1:0] burst_size;
    logic [ADDR_SIZE-1:0] raddr, waddr;
    logic [TID_SIZE-1:0] rtid;

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

    read_command_pool DUT (
        .clk(clk),
        .n_rst(n_rst),
        .rstrobe(rstrobe),
        .pop(read_issued),
        .busy(1'b0),
        .wready(wready),
        .burst_size(burst_size),
        .raddr(raddr),
        .waddr(waddr),
        .rtid(rtid)
    );

    task push_read;
        input logic[ADDR_SIZE-1:0] addr;
        input logic[TID_SIZE-1:0] tid;
    begin
        @(negedge clk);
        raddr = addr;
        rtid = tid;
        rstrobe = 1;
        @(negedge clk);
        rstrobe = 0;
        @(negedge clk);
    end
    endtask

    task push_multiple_reads;
        input logic [TID_SIZE-1:0] tid;
        input integer num;
        input logic[7:0][ADDR_SIZE-1:0] addr;
        integer i;
    begin
        @(negedge clk);
        rstrobe = 1;
        rtid = tid;
        for (i = 0; i < num; i++) begin
            raddr = addr[i];
            @(negedge clk);
        end
        rstrobe = 0;
        @(negedge clk);
    end
    endtask

    task pop_fifo;
        input integer num;
        integer i;
    begin
        @(negedge clk);
        for (i = 0; i < num; i++) begin
            read_issued = 1;
            @(negedge clk);
        end
        read_issued = 0;
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
        rstrobe = 0;
        read_issued = 0;
        raddr = 0;
        waddr = 8'b0;
        wready = 0;
        rtid = 0;
        burst_size = 0;
        reset_dut();
        @(negedge clk);

        // BASIC PUSH
        push_read(.addr(8'h20), .tid(2'd0));
        push_read(.addr(8'h7), .tid(2'd0));
        push_read(.addr(8'h16), .tid(2'd0));

        // DO ONE RAW for burst = 0
        @(negedge clk);
        burst_size = 0;
        wready = 1;
        waddr = 8'h7; // FAIL BC TID
        wait_clk(.num(2));
        waddr = 8'h20; // SUCCESS
        wait_clk(.num(5));
        pop_fifo(.num(2));
        

        // RAW TESTING for burst = 1
        @(negedge clk);
        burst_size = 1;
        push_read(.addr(8'h2), .tid(2'd1));
        push_read(.addr(8'h3), .tid(2'd1));
        push_read(.addr(8'h4), .tid(2'd1));
        waddr = 8'h2; // SUCCESS
        waddr = 8'h4; // FAIL
        wait_clk(.num(5));
        pop_fifo(.num(2));
        waddr = 8'h40;

        // RAW TESTING for burst = 2
        @(negedge clk);
        burst_size = 2;
        push_read(.addr(8'h42), .tid(2'd0));
        push_read(.addr(8'h44), .tid(2'd1));
        push_read(.addr(8'h46), .tid(2'd3));
        push_read(.addr(8'h45), .tid(2'd3));
        waddr = 8'h45; // FAIL
        wait_clk(.num(2));
        waddr = 8'h46; // SAME RAW
        wait_clk(.num(5));
        pop_fifo(.num(3));

        // RAW TESTING for burst = 3
        @(negedge clk);
        burst_size = 3;
        push_read(.addr(8'h70), .tid(2'd0));
        push_read(.addr(8'h81), .tid(2'd1));
        push_read(.addr(8'h92), .tid(2'd2));
        push_read(.addr(8'ha3), .tid(2'd3));
        push_read(.addr(8'hb4), .tid(2'd0));
        push_read(.addr(8'hc5), .tid(2'd1));
        push_read(.addr(8'hd6), .tid(2'd2));
        push_read(.addr(8'he7), .tid(2'd3));
        waddr = 8'hd8; // NO RAW
        wait_clk(.num(2));
        waddr = 8'hd0; // BELOW RAW FAIL BC TID
        wait_clk(.num(2));
        waddr = 8'h90; // BELOW RAW
        wait_clk(.num(2));
        waddr = 8'hb7; // ABOVE RAW FAIL
        wait_clk(.num(2));
        waddr = 8'h77; // ABOVE RAW FAIL
        wait_clk(.num(2));
        waddr = 8'he7; // SAME RAW FAIL
        wait_clk(.num(2));
        waddr = 8'ha3; // SAME RAW
        wait_clk(.num(2));
        waddr = 8'he7; // SAME RAW
        wait_clk(.num(2));
        pop_fifo(.num(5));

        @(negedge clk);
        waddr = 8'hFF;
        burst_size = 0;
        // TEST RERR    
        push_multiple_reads(.addr('{0, 1, 2, 3, 4, 5, 6, 7}), .tid(0), .num(8));
        push_read(.addr(8'h7), .tid(2'd2));
        pop_fifo(.num(5));
        push_multiple_reads(.addr('{0, 0, 0, 0, 1, 60, 61, 62}), .tid(1), .num(4));
        @(negedge clk);

        // DO ONE MORE RAW AND CLEAR
        waddr = 8'd62;
        wait_clk(.num(10));
        pop_fifo(.num(4));
        wait_clk(.num(10));
        $finish;
    end
endmodule

/* verilator coverage_on */

