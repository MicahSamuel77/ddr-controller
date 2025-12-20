`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_maintenance_command_queue ();

    localparam CLK_PERIOD = 100ns;
    localparam MAINTENANCE_DELAY = 64ms;

    localparam COLNRM = "\x1B[0m";
    localparam COLRED = "\x1B[31m";
    localparam COLGRN = "\x1B[32m";
    localparam COLCYA = "\x1B[36m";


    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars;
    end

    logic clk, n_rst;
    logic cmd_issued;
    logic issue_cmd;
    string test_name;
    string test_cluster_name;

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
        cmd_issued = 0;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        n_rst = 1;
        @(posedge clk);
        @(posedge clk);
    end
    endtask

    task check_output;
        input logic expected_output;
        input integer test_num;
    begin
        if (issue_cmd != expected_output) begin
            $display("%sFailed Test #%d: %s%s", COLRED, test_num, test_name, COLNRM);
        end else begin
            $display("%sPassed Test #%d: %s%s", COLGRN, test_num, test_name, COLNRM);
        end
    end
    endtask

    task strobe_cmd_issued;
    begin
        @(negedge clk);
        cmd_issued = 1;
        @(negedge clk);
        cmd_issued = 0;
    end
    endtask

    task begin_test;
        input string new_test_name;
    begin
        test_name = new_test_name;
    end
    endtask

    task begin_test_cluster;
        input string new_test_cluster_name;
    begin
        test_cluster_name = new_test_cluster_name;
        $display("---------------------------------");
        $display("%s", new_test_cluster_name);
        $display("---------------------------------");
    end
    endtask

    maintenance_command_queue #() DUT ( .* );

    initial begin
        n_rst = 1;
        reset_dut;

        begin_test_cluster("outputting high");
        begin_test("basic output high");
        #(MAINTENANCE_DELAY);
        @(posedge clk);
        @(negedge clk);
        check_output(01, 1);

        begin_test("extended output high");
        #(MAINTENANCE_DELAY / 10);
        check_output(01, 2);

        begin_test_cluster("outputting low");
        begin_test("cmd_issued strobed");
        strobe_cmd_issued;
        @(negedge clk);
        check_output(00, 3);

        begin_test("cmd_issued strobed then delay");
        #(MAINTENANCE_DELAY / 2);
        check_output(00, 4);

        begin_test("cmd_issued strobed in middle of count");
        strobe_cmd_issued;
        #(MAINTENANCE_DELAY - 1ms);
        check_output(00, 5);

        $finish;
    end
endmodule

/* verilator coverage_on */

