`timescale 1ns / 10ps

`include "type_pkg.vh"
/* verilator coverage_off */

module tb_timing_control ();

    localparam CLK_PERIOD = 10ns;

    localparam RANDOM_SEED = 11;

    localparam COLNRM = "\x1B[0m";
    localparam COLRED = "\x1B[31m";
    localparam COLGRN = "\x1B[32m";
    localparam COLCYA = "\x1B[36m";

    import type_pkg::*;

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars;
    end

    logic clk, n_rst;
    
    // information from pool
    logic [2:0] read_row, write_row;
    logic [1:0] read_bank, write_bank;
    
    // last command info
    logic read_issued, write_issued;
    logic [2:0] last_row;
    logic [1:0] last_bank;

    // priority outputs
    // priority_t read_priority;
    // priority_t write_priority;
    logic [1:0] read_priority;
    logic [1:0] write_priority;

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
    
    string test_name;
    integer test_num = 0;
    task begin_test;
        input string new_test_name;
    begin
        test_name = new_test_name;
        test_num++;
    end
    endtask

    string test_cluster_name;
    task begin_test_cluster;
        input string new_test_cluster_name;
    begin
        test_cluster_name = new_test_cluster_name;
        $display("---------------------------------");
        $display("%s", new_test_cluster_name);
        $display("---------------------------------");
    end
    endtask

    task check_outputs;
        input priority_t expected_rp;
        input priority_t expected_wp;
    begin
        if (expected_rp != read_priority || expected_wp != write_priority) begin
            $display("%sFailed Test #%d: %s%s", COLRED, test_num, test_name, COLNRM);
                if (expected_rp != read_priority)  $display("read_priority  expected %d got %d", expected_rp, read_priority);
                if (expected_wp != write_priority) $display("write_priority expected %d got %d", expected_wp, write_priority);
        end else begin
            $display("%sPassed Test #%d: %s%s", COLGRN, test_num, test_name, COLNRM);
        end

        if      (read_priority < write_priority) $display("\tmemory controller would issue a read command");
        else if (read_priority > write_priority) $display("\tmemory controller would issue a write command");
        else            $display("\tmemory controller would consult bank monitors for which command to issue");

    end
    endtask

    task cycle_clock;
        input integer n;
        integer i;
    begin
        for (i = 0; i < n; i++) begin
            @(negedge clk);
        end
    end
    endtask

    task reset_inputs;
    begin
        read_row        = 0;
        write_row       = 0;
        last_row        = 0;

        read_bank       = 0;
        write_bank      = 0;
        last_bank       = 0;

        read_issued     = 0;
        write_issued    = 0;
    end
    endtask

    task set_last_we;
        input logic desired_we;
    begin
        if (desired_we) read_issued = 1;
        else            write_issued = 1;

        @(negedge clk);

        read_issued     = 0;
        write_issued    = 0;
    end
    endtask

    task randomize_last_address;
    begin
        last_row  = $urandom_range(7);
        last_bank = $urandom_range(3);
    end
    endtask

    task set_read_location;
        input priority_t desired_priority;
    begin
        if (desired_priority == CROSS_PAGE) begin
            read_row  = last_row  ? last_row  - 1 : last_row  + 1;
            read_bank = last_bank ? last_bank - 1 : last_bank + 1;
        end else if (desired_priority == CLOSED_PAGE) begin
            read_row  = last_row;
            read_bank = last_bank ? last_bank - 1 : last_bank + 1;
        end else begin
            read_row  = last_row;
            read_bank = last_bank;
        end
    end
    endtask

    task set_write_location;
        input priority_t desired_priority;
    begin
        if (desired_priority == CROSS_PAGE) begin
            write_row  = last_row  ? last_row  - 1 : last_row  + 1;
            write_bank = last_bank ? last_bank - 1 : last_bank + 1;
        end else if (desired_priority == CLOSED_PAGE) begin
            write_row  = last_row;
            write_bank = last_bank ? last_bank - 1 : last_bank + 1;
        end else begin
            write_row  = last_row;
            write_bank = last_bank;
        end
    end
    endtask

    timing_control #() DUT (.*);

    initial begin
        n_rst = 1;

        reset_inputs;
        reset_dut;
        cycle_clock(3);

        begin_test_cluster("read priority < write_priority");
        begin_test("rp = 0, wp = 1");
        set_last_we(1);
        check_outputs(OPEN_PAGE_SAME_WE, OPEN_PAGE_DIF_WE);

        begin_test("rp = 0, wp = 2");
        randomize_last_address;
        set_read_location(OPEN_PAGE_SAME_WE);
        set_write_location(CLOSED_PAGE);
        @(negedge clk);
        check_outputs(OPEN_PAGE_SAME_WE, CLOSED_PAGE);

        begin_test("rp = 0, wp = 3");
        randomize_last_address;
        set_read_location(OPEN_PAGE_SAME_WE);
        set_write_location(CROSS_PAGE);
        @(negedge clk);
        check_outputs(OPEN_PAGE_SAME_WE, CROSS_PAGE);

        begin_test("rp = 1, wp = 2");
        randomize_last_address;
        set_read_location(OPEN_PAGE_DIF_WE);
        set_write_location(CLOSED_PAGE);
        set_last_we(0);
        check_outputs(OPEN_PAGE_DIF_WE, CLOSED_PAGE);

        begin_test("rp = 1, wp = 3");
        randomize_last_address;
        set_read_location(OPEN_PAGE_DIF_WE);
        set_write_location(CROSS_PAGE);
        set_last_we(0);
        check_outputs(OPEN_PAGE_DIF_WE, CROSS_PAGE);

        begin_test("rp = 2, wp = 3");
        randomize_last_address;
        set_read_location(CLOSED_PAGE);
        set_write_location(CROSS_PAGE);
        set_last_we(0);
        check_outputs(CLOSED_PAGE, CROSS_PAGE);

        begin_test_cluster("read priority < write_priority");
        begin_test("rp = 1, wp = 0");
        randomize_last_address;
        set_read_location(OPEN_PAGE_DIF_WE);
        set_write_location(OPEN_PAGE_SAME_WE);
        @(negedge clk);
        check_outputs(OPEN_PAGE_DIF_WE, OPEN_PAGE_SAME_WE);

        begin_test("rp = 2, wp = 0");
        randomize_last_address;
        set_read_location(CLOSED_PAGE);
        set_write_location(OPEN_PAGE_SAME_WE);
        @(negedge clk);
        check_outputs(CLOSED_PAGE, OPEN_PAGE_SAME_WE);
        
        begin_test("rp = 3, wp = 0");
        randomize_last_address;
        set_read_location(CROSS_PAGE);
        set_write_location(OPEN_PAGE_SAME_WE);
        @(negedge clk);
        check_outputs(CROSS_PAGE, OPEN_PAGE_SAME_WE);

        begin_test("rp = 2, wp = 1");
        randomize_last_address;
        set_read_location(CLOSED_PAGE);
        set_write_location(OPEN_PAGE_DIF_WE);
        set_last_we(1);
        check_outputs(CLOSED_PAGE, OPEN_PAGE_DIF_WE);

        begin_test("rp = 3, wp = 1");
        randomize_last_address;
        set_read_location(CROSS_PAGE);
        set_write_location(OPEN_PAGE_DIF_WE);
        @(negedge clk);
        check_outputs(CROSS_PAGE, OPEN_PAGE_DIF_WE);

        begin_test("rp = 3, wp = 2");
        randomize_last_address;
        set_read_location(CROSS_PAGE);
        set_write_location(CLOSED_PAGE);
        @(negedge clk);
        check_outputs(CROSS_PAGE, CLOSED_PAGE);

        begin_test_cluster("read priority = write priority");
        begin_test("rp = 2, wp = 2");
        randomize_last_address;
        set_read_location(CLOSED_PAGE);
        set_write_location(CLOSED_PAGE);
        @(negedge clk);
        check_outputs(CLOSED_PAGE, CLOSED_PAGE);

        begin_test("rp = 3, wp = 3");
        randomize_last_address;
        set_read_location(CLOSED_PAGE);
        set_write_location(CLOSED_PAGE);
        set_last_we(1);
        check_outputs(CLOSED_PAGE, CLOSED_PAGE);

        cycle_clock(5);

        $finish;
    end
endmodule

/* verilator coverage_on */

