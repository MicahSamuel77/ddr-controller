`timescale 1ns / 10ps

`include "type_pkg.vh"

/* verilator coverage_off */

module tb_command_scheduler ();

    import type_pkg::*;

    localparam CLK_PERIOD = 100ns;

    localparam COLNRM = "\x1B[0m";
    localparam COLRED = "\x1B[31m";
    localparam COLGRN = "\x1B[32m";
    localparam COLCYA = "\x1B[36m";

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars;
    end

    logic clk, n_clk, n_rst;

    // clockgen
    always begin
        clk = 0;
        #(CLK_PERIOD / 2.0);
        clk = 1;
        #(CLK_PERIOD / 2.0);
    end

    always begin
        n_clk = 1;
        #(CLK_PERIOD / 2.0);
        n_clk = 0;
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

    // mode register settings from AXI
    logic [1:0] burst_size;
    logic MRS;

    // interface w/ maintenance command queue
    logic issue_cmd;
    logic cmd_issued;

    // interface w/ read command pool
    burst_size_t pool_rburst_size, pool_rburst_size2;
    logic rready, rready2, read_issued, raw;
    logic read_in_progress;
    logic [7:0] pool_raddr, pool_raddr2;
    
    // interface w/ timing control
    logic [2:0] last_row;
    logic [1:0] last_bank;
    logic all_banks_closed;
    priority_t write_priority, read_priority;

    // interface w/ write command pool
    burst_size_t pool_wburst_size, pool_wburst_size2;
    logic wready, wready2, write_issued;
    logic [7:0] pool_waddr, pool_waddr2;

    // interface w/ dram
    logic CK, N_CK, CKE, CS, RAS, CAS, WE;
    logic [1:0] B;
    logic [13:0] A;
    
    // interface w/ data controller
    logic DQ_oe;

    // interface w/ bank monitors
    bank_status_t bank_0_status;
    bank_status_t bank_1_status;
    bank_status_t bank_2_status;
    bank_status_t bank_3_status;
    bank_states_t  bank_0_state;
    bank_states_t  bank_1_state;
    bank_states_t  bank_2_state;
    bank_states_t  bank_3_state;

    commands_t display_cmd;
    assign display_cmd = commands_t'({CS, RAS, CAS, WE});

    command_scheduler #() DUT (.*);

    task check_outputs;
        input logic expected_CKE;
        input commands_t expected_cmd;
        input logic [1:0] expected_B;
        input logic [13:0] expected_A;
    begin
        if (expected_CKE    != CKE                  || 
            expected_cmd    != {CS, RAS, CAS, WE}   || 
            expected_B      != B                    ||
            expected_A      != A ) begin
            $display("%sFailed Test #%d: %s%s", COLRED, test_num, test_name, COLNRM);
                if (expected_CKE != CKE)                $display("CKE expected %d got %d", expected_CKE, CKE);
                if (expected_cmd != {CS, RAS, CAS, WE}) $display("cmd expected %d got %d", expected_cmd, {CS, RAS, CAS, WE});
                if (expected_B   != B)                  $display("B expected %d got %d", expected_B, B);
                if (expected_A   != A)                  $display("A expected %d got %d", expected_A, A);
        end else begin
            $display("%sPassed Test #%d: %s%s", COLGRN, test_num, test_name, COLNRM);
        end
    end
    endtask

    task cycle_clock;
        input integer n;
        integer i;
    begin
        repeat (n) @(negedge clk);
    end
    endtask

    task reset_inputs;
    begin
        burst_size          = 0;
        MRS                 = 0;

        issue_cmd           = 0;
        raw                 = 0;

        rready              = 0;
        wready              = 0;
        rready2             = 0;
        wready2             = 0;
        pool_raddr          = 0;
        pool_waddr          = 0;
        pool_raddr2         = 0;
        pool_waddr2         = 0;
        pool_rburst_size    = ONE_BYTE;
        pool_wburst_size    = ONE_BYTE;
        pool_rburst_size2   = ONE_BYTE;
        pool_wburst_size2   = ONE_BYTE;
        read_priority       = OPEN_PAGE_SAME_WE;
        write_priority      = OPEN_PAGE_SAME_WE;

        bank_0_status       = BANK_NOT_READY;
        bank_1_status       = BANK_NOT_READY;
        bank_2_status       = BANK_NOT_READY;
        bank_3_status       = BANK_NOT_READY;
        bank_0_state        = IDLE_B;
        bank_1_state        = IDLE_B;
        bank_2_state        = IDLE_B;
        bank_3_state        = IDLE_B;
    end
    endtask

    task set_burst_size;
    input burst_size_t new_size;
    begin
        MRS = 1;
        burst_size = new_size;

        @(negedge clk);

        MRS = 0;
    end
    endtask

    task set_all_banks;
        input bank_status_t new_bank_status;
    begin
        bank_0_status = new_bank_status;
        bank_1_status = new_bank_status;
        bank_2_status = new_bank_status;
        bank_3_status = new_bank_status;
    end
    endtask

    task queue_read;
        input burst_size_t  que_burst_size;
        input [7:0]         que_addr;
    begin
        rready              = 1;
        pool_raddr          = que_addr;
        pool_rburst_size    = que_burst_size;
    end
    endtask

    task queue_read_2;
        input burst_size_t  que_burst_size;
        input [7:0]         que_addr;
    begin
        rready2             = 1;
        pool_raddr2         = que_addr;
        pool_rburst_size2   = que_burst_size;
    end
    endtask


    task queue_write;
        input burst_size_t  que_burst_size;
        input [7:0]         que_addr;
    begin
        wready              = 1;
        pool_waddr          = que_addr;
        pool_wburst_size    = que_burst_size;
    end
    endtask

    task clear_read;
    begin
        rready              = 0;
        pool_raddr          = 0;
        pool_rburst_size    = ONE_BYTE;
    end
    endtask

    task clear_write;
    begin
        wready              = 0;
        pool_waddr          = 0;
        pool_wburst_size    = ONE_BYTE;
    end
    endtask

    function [7:0] random_address;
    begin
        random_address = $urandom_range(8'b1111_1111);
    end
    endfunction

    initial begin
        n_rst = 1;

        reset_inputs;
        reset_dut;

        begin_test_cluster("initialization");
        begin_test("initialization sequence start to finish");
        check_outputs(0, DESELECT, 0, 0);
        cycle_clock(2800);

        begin_test_cluster("mode register set");
        begin_test("burst_size to ONE_BYTE");
        set_burst_size(ONE_BYTE);
        cycle_clock(4);
        set_all_banks(BANK_FULL_READY);
        cycle_clock(4);
        check_outputs(1, MODE_REGISTER_SET, 0, 14'b0000000100000);
        set_all_banks(BANK_NOT_READY);
        cycle_clock(6);
        set_all_banks(BANK_FULL_READY);

        begin_test("burst_size to TWO_BYTES");
        set_burst_size(TWO_BYTES);
        cycle_clock(4);
        check_outputs(1, MODE_REGISTER_SET, 0, 14'b0000000100001);
        set_all_banks(BANK_NOT_READY);
        cycle_clock(6);
        set_all_banks(BANK_FULL_READY);

        begin_test("burst_size to FOUR_BYTES");
        set_burst_size(FOUR_BYTES);
        cycle_clock(4);
        check_outputs(1, MODE_REGISTER_SET, 0, 14'b0000000100010);
        set_all_banks(BANK_NOT_READY);
        cycle_clock(6);
        set_all_banks(BANK_FULL_READY);

        begin_test("burst_size to EIGHT_BYTES");
        set_burst_size(EIGHT_BYTES);
        cycle_clock(4);
        check_outputs(1, MODE_REGISTER_SET, 0, 14'b0000000100011);
        set_all_banks(BANK_NOT_READY);
        cycle_clock(6);
        set_all_banks(BANK_FULL_READY);

        begin_test("burst_size with old_bursts");
        queue_read(EIGHT_BYTES, 8'b101_11_100);
        set_burst_size(FOUR_BYTES);
        cycle_clock(7);
        clear_read;
        cycle_clock(10);

        begin_test_cluster("Refresh needed");
        begin_test("precharge before refresh");
        issue_cmd = 1;
        queue_read(FOUR_BYTES, 8'b101_11_100);
        queue_write(FOUR_BYTES, 8'b101_11_100);
        cycle_clock(1);
        issue_cmd = 0;
        clear_read;
        clear_write;
        check_outputs(1, PRECHARGE, 0, 14'b00_0100_0000_0000);

        begin_test("refresh");
        cycle_clock(3);
        check_outputs(1, REFRESH, 0, 0);

        cycle_clock(205);

        begin_test_cluster("reads and writes");
        begin_test("r/w same prio");
        read_priority = CLOSED_PAGE;
        write_priority = CLOSED_PAGE;
        queue_read(FOUR_BYTES, 8'b111_00_111);
        queue_write(FOUR_BYTES, 8'b111_00_111);
        cycle_clock(7);
        clear_read;
        clear_write;
        cycle_clock(5);

        begin_test("r prio > w prio, no active");
        read_priority = CLOSED_PAGE;
        write_priority = OPEN_PAGE_DIF_WE;
        queue_read(FOUR_BYTES, 8'b111_01_111);
        queue_write(FOUR_BYTES, 8'b111_00_111);
        cycle_clock(4);
        clear_read;
        clear_write;
        cycle_clock(3);

        begin_test("r prio < w prio, active needed");
        read_priority = CLOSED_PAGE;
        write_priority = CROSS_PAGE;
        queue_read(FOUR_BYTES, 8'b111_10_111);
        queue_write(FOUR_BYTES, 8'b001_11_111);
        cycle_clock(6);
        clear_read;
        clear_write;
        cycle_clock(3);

        begin_test("r prio = w prio, precharge needed");
        read_priority = CROSS_PAGE;
        write_priority = CROSS_PAGE;
        queue_read(FOUR_BYTES, 8'b101_10_111);
        queue_write(FOUR_BYTES, 8'b101_11_111);
        cycle_clock(8);
        clear_read;
        clear_write;
        cycle_clock(3);

        begin_test("back to back commands");
        set_burst_size(ONE_BYTE);
        cycle_clock(2);
        queue_read(ONE_BYTE, 8'b101_11_100);
        queue_read_2(ONE_BYTE, 8'b101_11_100);
        cycle_clock(20);

        cycle_clock(2);
        $finish;
    end
endmodule

/* verilator coverage_on */

