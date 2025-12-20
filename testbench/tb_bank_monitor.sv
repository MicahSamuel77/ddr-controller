`timescale 1ns / 10ps

/* verilator coverage_off */

`default_nettype none
`include "type_pkg.vh"

module tb_bank_monitor ();

    import type_pkg::*;

    localparam CLK_PERIOD = 100ns;

    localparam COLNRM = "\x1B[0m";
    localparam COLRED = "\x1B[31m";
    localparam COLGRN = "\x1B[32m";
    localparam COLCYA = "\x1B[36m";

    commands_t display_command;

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars;
    end

    logic clk, n_rst;

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
    task begin_test;
        input string new_test_name;
    begin
        test_name = new_test_name;
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

    // command / address
    logic CS, CAS, RAS, WE;
    logic [1:0] B;

    // burst sizes
    burst_size_t pool_rburst_size;
    burst_size_t pool_wburst_size;

    // bank status (output)
    bank_status_t [0:0] bank_status;    // [0:0] fix needed for qsim syn to run
                                        // gives it a wire type without
                                        // useless bus width like are we
                                        // serious
    bank_states_t bank_state;
    bank_monitor #() DUT (.*);

    task check_outputs;
        input bank_status_t expected_bs;
        input integer test_num;
    begin
        if (expected_bs != bank_status) begin
            $display("%sFailed Test #%d: %s%s", COLRED, test_num, test_name, COLNRM);
                if (expected_bs != bank_status) $display("bank_status expected %d got %d", expected_bs, bank_status);
        end else begin
            $display("%sPassed Test #%d: %s%s", COLGRN, test_num, test_name, COLNRM);
        end
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
        display_command     = NOP;
        {CS, RAS, CAS, WE}  = NOP;
        B                   = 0;
        pool_rburst_size    = ONE_BYTE;
        pool_wburst_size    = ONE_BYTE;
    end
    endtask

    task send_command;
        input commands_t command;
        // input logic [3:0] command;
        input logic [1:0] bank_addr;
    begin
        display_command     = command;
        {CS, RAS, CAS, WE}  = command;
        B                   = bank_addr;
        @(negedge clk);
        display_command     = NOP;
        {CS, RAS, CAS, WE}  = NOP;
        B                   = 0;
    end
    endtask

    initial begin
        n_rst = 1;
        reset_inputs;
        reset_dut;

        display_command = MODE_REGISTER_SET;

        begin_test_cluster("basic transitions");
        begin_test("idle");
        cycle_clock(10);
        check_outputs(BANK_FULL_READY, 1);

        begin_test("idle -> MRS");
        send_command(MODE_REGISTER_SET, 1);
        check_outputs(BANK_NOT_READY, 2);

        begin_test("MRS");
        cycle_clock(1);
        check_outputs(BANK_NOT_READY, 3);

        begin_test("MRS -> idle");
        cycle_clock(1);
        check_outputs(BANK_FULL_READY, 4);

        begin_test("idle -> activating");
        send_command(ACTIVE, 1);
        check_outputs(BANK_NOT_READY, 5);

        begin_test("activating");
        cycle_clock(1);
        check_outputs(BANK_NOT_READY, 6);

        begin_test("activating -> active");
        cycle_clock(1);
        check_outputs(BANK_FULL_READY, 7);

        begin_test("active");
        cycle_clock(10);
        check_outputs(BANK_FULL_READY, 8);

        begin_test_cluster("1 burst reads");
        begin_test("active -> reading");
        send_command(READ, 1);
        check_outputs(BANK_NOT_READY, 9);

        begin_test("reading -> read_semi_done");
        cycle_clock(1);
        check_outputs(BANK_READ_READY, 10);

        begin_test("read_semi_done");
        cycle_clock(1);
        check_outputs(BANK_READ_READY, 11);

        begin_test("read_semi_done -> active");
        cycle_clock(1);
        check_outputs(BANK_FULL_READY, 12);

        begin_test("active -> reading");
        send_command(READ, 1);
        check_outputs(BANK_NOT_READY, 13);

        begin_test("reading -> reading");
        send_command(READ, 1);
        check_outputs(BANK_NOT_READY, 14);

        begin_test("reading -> read_semi_done");
        cycle_clock(1);
        check_outputs(BANK_READ_READY, 15);

        begin_test("read_semi_done -> reading");
        send_command(READ, 1);
        check_outputs(BANK_NOT_READY, 16);

        begin_test("reading -> active");
        cycle_clock(3);
        check_outputs(BANK_FULL_READY, 17);

        begin_test_cluster("4 burst reads");
        pool_rburst_size = FOUR_BYTES;
        begin_test("active -> reading");
        send_command(READ, 1);
        check_outputs(BANK_NOT_READY, 18);

        begin_test("reading");
        cycle_clock(1);
        check_outputs(BANK_NOT_READY, 19);

        begin_test("reading -> read_semi_done");
        cycle_clock(1);
        check_outputs(BANK_READ_READY, 20);

        begin_test("read_semi_done -> active");
        cycle_clock(2);
        check_outputs(BANK_FULL_READY, 21);

        begin_test("active -> reading");
        send_command(READ, 1);
        check_outputs(BANK_NOT_READY, 22);

        begin_test("reading -> reading");
        cycle_clock(1);
        send_command(READ, 1);
        cycle_clock(1);
        check_outputs(BANK_NOT_READY, 23);

        begin_test("reading -> active");
        cycle_clock(3);
        check_outputs(BANK_FULL_READY, 24);

        begin_test_cluster("8 burst reads");
        pool_rburst_size = EIGHT_BYTES;
        begin_test("active -> reading");
        send_command(READ, 1);
        check_outputs(BANK_NOT_READY, 25);

        begin_test("reading");
        cycle_clock(3);
        check_outputs(BANK_NOT_READY, 26);

        begin_test("reading -> read_semi_done");
        cycle_clock(1);
        check_outputs(BANK_READ_READY, 27);

        begin_test("read_semi_done -> active");
        cycle_clock(2);
        check_outputs(BANK_FULL_READY, 28);

        begin_test("active -> reading");
        send_command(READ, 1);
        check_outputs(BANK_NOT_READY, 29);

        begin_test("reading -> reading");
        cycle_clock(3);
        send_command(READ, 1);
        cycle_clock(3);
        check_outputs(BANK_NOT_READY, 30);

        begin_test("reading -> active");
        cycle_clock(3);
        check_outputs(BANK_FULL_READY, 31);

        begin_test_cluster("1 burst writes");
        begin_test("active -> writing");
        send_command(WRITE, 1);
        check_outputs(BANK_NOT_READY, 32);

        begin_test("writing -> write_semi_done");
        cycle_clock(1);
        check_outputs(BANK_WRITE_READY, 33);

        begin_test("write_semi_done -> active");
        cycle_clock(1);
        check_outputs(BANK_FULL_READY, 34);

        begin_test("active -> writing");
        send_command(WRITE, 1);
        check_outputs(BANK_NOT_READY, 35);

        begin_test("writing -> writing");
        send_command(WRITE, 1);
        check_outputs(BANK_NOT_READY, 36);

        begin_test("writing -> write_semi_done");
        cycle_clock(1);
        check_outputs(BANK_WRITE_READY, 37);

        begin_test("write_semi_done -> writing");
        send_command(WRITE, 1);
        check_outputs(BANK_NOT_READY, 38);

        begin_test("writing -> active");
        cycle_clock(2);
        check_outputs(BANK_FULL_READY, 39);

        begin_test_cluster("4 burst writes");
        pool_wburst_size = FOUR_BYTES;
        begin_test("active -> writing");
        send_command(WRITE, 1);
        check_outputs(BANK_NOT_READY, 40);

        begin_test("writing");
        cycle_clock(1);
        check_outputs(BANK_NOT_READY, 41);

        begin_test("writing -> write_semi_done");
        cycle_clock(1);
        check_outputs(BANK_WRITE_READY, 42);

        begin_test("write_semi_done -> active");
        cycle_clock(1);
        check_outputs(BANK_FULL_READY, 43);

        begin_test("active -> writing");
        send_command(WRITE, 1);
        check_outputs(BANK_NOT_READY, 44);

        begin_test("writing -> writing");
        cycle_clock(1);
        send_command(WRITE, 1);
        cycle_clock(1);
        check_outputs(BANK_NOT_READY, 45);

        begin_test("writing -> active");
        cycle_clock(2);
        check_outputs(BANK_FULL_READY, 46);

        begin_test_cluster("8 burst writes");
        pool_wburst_size = EIGHT_BYTES;
        begin_test("active -> writing");
        send_command(WRITE, 1);
        check_outputs(BANK_NOT_READY, 47);

        begin_test("writing");
        cycle_clock(3);
        check_outputs(BANK_NOT_READY, 48);

        begin_test("writing -> write_semi_done");
        cycle_clock(1);
        check_outputs(BANK_WRITE_READY, 49);

        begin_test("write_semi_done -> active");
        cycle_clock(1);
        check_outputs(BANK_FULL_READY, 50);

        begin_test("active -> writing");
        send_command(WRITE, 1);
        check_outputs(BANK_NOT_READY, 51);

        begin_test("writing -> writing");
        cycle_clock(3);
        send_command(WRITE, 1);
        cycle_clock(3);
        check_outputs(BANK_NOT_READY, 52);

        begin_test("reading -> active");
        cycle_clock(2);
        check_outputs(BANK_FULL_READY, 53);

        begin_test_cluster("back to idle");
        begin_test("active -> precharge");
        send_command(PRECHARGE, 1);
        check_outputs(BANK_NOT_READY, 54);

        begin_test("precharge -> precharge");
        cycle_clock(1);
        check_outputs(BANK_NOT_READY, 55);

        begin_test("precharge -> idle");
        cycle_clock(1);
        check_outputs(BANK_FULL_READY, 56);

        cycle_clock(10);

        $finish;
    end
endmodule

/* verilator coverage_on */
