`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_axi_subordinate ();

    localparam CLK_PERIOD = 10ns;
    localparam COLNRM = "\x1B[0m";
    localparam COLRED = "\x1B[31m";
    localparam COLGRN = "\x1B[32m";
    localparam COLCYA = "\x1B[36m";

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars;
    end

    logic clk, n_rst;
    logic [1:0] ARID;
    logic [31:0] ARADDR;
    logic [7:0] ARLEN;
    logic [2:0] ARSIZE;
    logic [1:0] ARBURST;
    logic ARVALID;
    logic ARREADY;
    logic RREADY;
    logic [1:0] RID;
    logic [63:0] RDATA;
    logic [1:0] RRESP;
    logic RLAST;
    logic RVALID;
    logic [1:0] AWID;
    logic [31:0] AWADDR;
    logic [7:0] AWLEN;
    logic [2:0] AWSIZE;
    logic [1:0] AWBURST;
    logic AWVALID;
    logic AWREADY;
    logic [63:0] WDATA;
    logic [7:0] WSTRB;
    logic WLAST;
    logic WVALID;
    logic WREADY;
    logic BREADY;
    logic [1:0] BID;
    logic [1:0] BRESP;
    logic BVALID;
    logic [7:0] raddr;
    logic [63:0] rdata;
    logic rvalid, rfull;
    logic [7:0] waddr;
    logic [63:0] wdata;
    logic wstrobe;
    logic rstrobe;
    logic wfull;
    logic [1:0] tid_in;
    logic [1:0] tid_out;
    logic rerr, werr;
    logic [1:0] burst_size;
    logic config_update;
    logic ren;

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

    axi_subordinate DUT (.*);


    /* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        TEST NAMING
    -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= */

    string test_name;
    integer test_num = 0;
    task begin_test;
        input string new_test_name;
    begin
        test_name = new_test_name;
    end
    endtask

    string test_cluster_name;
    task begin_test_cluster;
        input string new_test_cluster_name;
        input logic cluster_should_display = 1;
    begin
        test_cluster_name = new_test_cluster_name;
        if (cluster_should_display) begin
            $display("---------------------------------");
            $display("%s", new_test_cluster_name);
            $display("---------------------------------");
        end
    end
    endtask

    /* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        RANDOM FUNCTIONS
    -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= */

    function [7:0] get_random_address;
    begin
        get_random_address = $urandom_range(8'b111_11_111);
    end
    endfunction

    function [63:0] get_random_data;
    begin
        get_random_data = {$urandom_range(32'hFF_FF_FF_FF), $urandom_range(32'hFF_FF_FF_FF)};
    end
    endfunction

    task cycle_clock;
        input integer n;
    begin
        repeat (n) @(negedge clk);
    end
    endtask

    /* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        INTERFACE WITH AXI
    -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= */
    int i;
    logic [31:0] temp_address;
    task queue_read;
        input logic[31:0] address;
        input logic [7:0] num_transfers;
        input logic [2:0] transfer_size;
        input logic [1:0] transaction_id;
        input logic check_in_order;
    begin
        @(negedge clk);
        ARID = transaction_id;
        ARADDR = address;
        ARLEN = num_transfers;
        ARSIZE = transfer_size;
        ARVALID = 1'b1;
        @(posedge clk);
        @(negedge ARREADY);
        ARVALID = 1'b0;
        $display("Sending address to rdata");
        if(check_in_order) begin
            temp_address = address;
            for(i = 0; i <= num_transfers; i++) begin
                wait(rstrobe);
                @(negedge clk);
                if(temp_address[7:0] == raddr) begin
                    $display("%sPassed %d: %h sent successfully during %s%s", COLGRN, test_num, raddr, test_name, COLNRM);
                end else begin
                    $display("%sFailed %d: expected %h got %h during %s%s", COLRED, test_num, temp_address, raddr, test_name, COLNRM);
                end
                temp_address += transfer_size == 0 ? 1 : transfer_size == 1 ? 2 : transfer_size == 2 ? 4 : transfer_size == 3 ? 8 : 0;
                @(posedge clk);
            end
        end
    end
    endtask

    task queue_read_response;
        input logic [1:0] transaction_id;
        input logic err;
        input logic [63:0] data_in;
        input logic rlast;
        input logic [1:0] expected_rresp;
        input logic [63:0] expected_data;
    begin
        wait (ren);
        @(negedge clk);
        RREADY = 1'b1;
        tid_out = transaction_id;
        rerr = err;
        rdata = data_in;
        rvalid = 1'b1;
        @(posedge clk);
        wait (RVALID && RREADY);
        @(posedge clk);
        if(RDATA == expected_data) begin
            $display("%sPassed %d: RDATA %h read successfully during %s%s", COLGRN, test_num, expected_data, test_name, COLNRM);
        end else begin
            $display("%sFailed %d: RDATA expected %h got %h during %s%s", COLRED, test_num, expected_data, RDATA, test_name, COLNRM);
        end
        if(RRESP == expected_rresp) begin
            $display("%sPassed %d: RRESP %h read successfully during %s%s", COLGRN, test_num, expected_rresp, test_name, COLNRM);
        end else begin
            $display("%sFailed %d: RRESP expected %h got %h during %s%s", COLRED, test_num, expected_rresp, RRESP, test_name, COLNRM);
        end
        if(RLAST == rlast) begin
            $display("%sPassed %d: RLAST %h read successfully during %s%s", COLGRN, test_num, RLAST, test_name, COLNRM);
        end else begin
            $display("%sFailed %d: RLAST expected %h got %h during %s%s", COLRED, test_num, rlast, RLAST, test_name, COLNRM);
        end
        if(RLAST) test_num++;
        @(negedge RVALID);
        RREADY = 1'b0;
        rvalid = 1'b0;
    end
    endtask

    task queue_write_address;
        input logic [1:0] transaction_id;
        input logic [7:0] num_transfers;
        input logic [2:0] transfer_size;
        input logic [31:0] address;
    begin
        @(negedge clk);
        AWVALID = 1'b1;
        AWADDR = address;
        AWID = transaction_id;
        AWLEN = num_transfers;
        AWSIZE = transfer_size;
        @(posedge clk);
        @(negedge AWREADY);
        AWVALID = 1'b0;
    end
    endtask

    task queue_write_data;
        input logic [63:0] data;
        input logic last;
        input logic err;
        input logic write_full;
        input logic [7:0] write_strobe;
        input logic [7:0] expected_waddr;
        input logic [63:0] expected_data;
    begin
        @(negedge clk);
        WVALID = 1'b1;
        WDATA = data;
        WLAST = last;
        WSTRB = write_strobe;
        @(negedge WREADY);  
        WVALID = 1'b0;
        WLAST = 1'b0;
        wfull = write_full;
        @(posedge clk);
        $display("Sending address to memory controller");
        if(expected_waddr == waddr) begin
            $display("%sPassed %d:  %h sent successfully during %s%s", COLGRN, test_num, expected_waddr, test_name, COLNRM);
        end else begin
            $display("%sFailed %d: expected %h got %h during %s%s", COLRED, test_num, expected_waddr, waddr, test_name, COLNRM);
        end
        $display("Sending data to memory controller");
        if(expected_data == wdata) begin
            $display("%sPassed %d:  %h sent successfully during %s%s", COLGRN, test_num, expected_data, test_name, COLNRM);
        end else begin
            $display("%sFailed %d:  expected %h got %h during %s%s", COLRED, test_num, expected_data, wdata, test_name, COLNRM);
        end
        @(posedge BVALID);
        werr = err;
        BREADY = 1'b1;
        @(negedge BVALID);
        BREADY = 1'b0;
        werr = 1'b0;
    end
    endtask

    initial begin
        n_rst = 1;
        ARVALID = 1'b0;
        AWVALID = 1'b0;
        WVALID = 1'b0;
        BREADY = 1'b0;
        wfull = 1'b0;
        rfull = 1'b0;
        werr = 1'b0;
        ARID = 2'd0;
        ARADDR = 32'd0;
        ARLEN = 8'd0;
        ARBURST = 2'b01;
        RREADY = 1'b0;
        AWID = 2'd0;
        AWADDR = 32'd0;
        AWLEN = 8'd0;
        AWSIZE = 3'd0;
        AWBURST = 2'd1;
        WDATA = 64'd0;
        WSTRB = 8'hFF;
        WLAST = 1'b0;
        rdata = 64'h0;
        rvalid = 1'b0;
        tid_out = 2'd0;
        rerr = 1'b0;
        werr = 1'b0;
        reset_dut;

        begin_test_cluster("in order execution", 1);
        begin_test("axi_incr_read");

        @(posedge clk);

        queue_read(32'd0, 8'd1, 3'd3, 2'd0, 1'b1);
        queue_read_response(2'd0, 1'b0, 64'hA5A5A5A5A5A5A5A5, 0, 0, 64'hA5A5A5A5A5A5A5A5);
        queue_read_response(2'd0, 1'b0, 64'hBBBBBBBBBBBBBBBB, 1, 0, 64'hBBBBBBBBBBBBBBBB);
        queue_read(32'd0, 8'd1, 3'd2, 2'd0, 1'b1);
        queue_read_response(2'd0, 1'b0, 64'h5A5A5A5A, 0, 0, 64'h5A5A5A5A);
        queue_read_response(2'd0, 1'b0, 64'hCCCCCCCC, 1, 0, 64'hCCCCCCCC00000000);
        queue_read(32'd0, 8'd1, 3'd1, 2'd0, 1'b1);
        queue_read_response(2'd0, 1'b0, 64'hDEF0, 0, 0, 64'hDEF0);
        queue_read_response(2'd0, 1'b0, 64'hDEF0, 1, 0, 64'hDEF00000);
        queue_read(32'd0, 8'd1, 3'd0, 2'd0, 1'b1);
        queue_read_response(2'd0, 1'b0, 64'h72, 0, 0, 64'h72);
        queue_read_response(2'd0, 1'b0, 64'h34, 1, 0, 64'h3400);

        begin_test("axi_incr_write");
        @(posedge clk);
        queue_write_address(2'd0, 8'd1, 3'd3, 32'd0);
        queue_write_address(2'd0, 8'd1, 3'd2, 32'd0);
        queue_write_address(2'd0, 8'd1, 3'd1, 32'd0);
        queue_write_address(2'd0, 8'd8, 3'd0, 32'd0);
        queue_write_data(64'hAAAAAAAAAAAAAAAA, 0, 0, 0, 8'hFF, 8'h0, 64'hAAAAAAAAAAAAAAAA);
        queue_write_data(64'hBBBBBBBBBBBBBBBB, 1, 0, 0, 8'hFF, 8'h8, 64'hBBBBBBBBBBBBBBBB);
        test_num++;
        queue_write_data(64'hA5A5A5A5, 0, 0, 0, 8'h0F, 8'h0, 64'hA5A5A5A5);
        queue_write_data(64'h1647383900000000, 1, 0, 0, 8'hF0, 8'h4, 64'h16473839);
        test_num++;
        queue_write_data(64'h1234, 0, 0, 0, 8'h03, 8'h0, 64'h1234);
        queue_write_data(64'h45680000, 1, 0, 0, 8'h0C, 8'h2, 64'h4568);
        test_num++;
        queue_write_data(64'h04, 0, 0, 0, 8'h1, 8'h0, 64'h4);
        queue_write_data(64'h4300, 0, 0, 0, 8'h2, 8'h1, 64'h43);
        queue_write_data(64'h390000, 0, 0, 0, 8'h4, 8'h2, 64'h39);
        queue_write_data(64'h23000000, 0, 0, 0, 8'h8, 8'h3, 64'h23);
        queue_write_data(64'h4200000000, 0, 0, 0, 8'h10, 8'h4, 64'h42);
        queue_write_data(64'h480000000000, 0, 0, 0, 8'h20, 8'h5, 64'h48);
        queue_write_data(64'hAC000000000000, 0, 0, 0, 8'h40, 8'h6, 64'hAC);
        queue_write_data(64'hBF00000000000000, 0, 0, 0, 8'h80, 8'h7, 64'hBF);
        queue_write_data(64'h5D, 1, 0, 0, 8'h1, 8'h8, 64'h5D);
        test_num++;

        begin_test("write to config register");
        queue_write_address(2'd0, 8'd0, 3'd0, 32'h100);
        queue_write_data(64'h2, 1, 0, 0, 8'h00, 8'h00, 64'h0);
        test_num++;

        begin_test("error when writing outside memory space");
        queue_write_address(2'd0, 8'd0, 3'd0, 32'h329320);
        queue_write_data(64'h0, 1, 0, 0, 8'h00, 8'h20, 64'h0);
        queue_write_address(2'd0, 8'd0, 3'd0, 32'h101);
        queue_write_data(64'h02, 1, 0, 0, 8'h00, 8'h01, 64'h0);
        test_num++;

        begin_test("error when reading outside memory space");
        queue_read(32'h100, 8'h0, 3'd0, 2'd0, 1);
        queue_read_response(2'd0, 0, 64'h0, 1, 2, 64'h0);
        //test_num++;

        begin_test_cluster("read out of order interleaving", 1);
        begin_test("read OoO interleaving, tid = 2");
        queue_read(32'd3, 8'd1, 3'd3, 2'd1, 0);
        queue_read(32'd0, 8'd2, 3'd3, 2'd2, 0);
        //queue_read(32'd4, 8'd3, 3'd3, 2'd3, 0);
        //queue_read(32'd6, 8'd2, 3'd3, 2'd0, 0);
        queue_read_response(2'd1, 0, 64'h00000000AAAAAAAA, 0, 0, 64'h00000000AAAAAAAA);
        queue_read_response(2'd1, 0, 64'h00000000BBBBBBBB, 1, 0, 64'h00000000BBBBBBBB);
        queue_read_response(2'd2, 0, 64'hCCCC, 0, 0, 64'hCCCC);
        queue_read_response(2'd2, 0, 64'hDDDD, 0, 0, 64'hDDDD);
        queue_read_response(2'd2, 0, 64'hEEEE, 1, 0, 64'hEEEE);

        //test_num++;
        begin_test("read OoO interleaving, tid = 3");        
        queue_read(32'd3, 8'd1, 3'd3, 2'd1, 0);
        queue_read(32'd0, 8'd2, 3'd3, 2'd2, 0);
        queue_read(32'd4, 8'd3, 3'd3, 2'd3, 0);
        //queue_read(32'd6, 8'd2, 3'd3, 2'd0, 0);
        queue_read_response(2'd1, 0, 64'h00000000AAAAAAAA, 0, 0, 64'h00000000AAAAAAAA);
        queue_read_response(2'd1, 0, 64'h00000000BBBBBBBB, 1, 0, 64'h00000000BBBBBBBB);
        queue_read_response(2'd2, 0, 64'hCCCC, 0, 0, 64'hCCCC);
        queue_read_response(2'd2, 0, 64'hDDDD, 0, 0, 64'hDDDD);
        queue_read_response(2'd2, 0, 64'hEEEE, 1, 0, 64'hEEEE);
        queue_read_response(2'd3, 0, 64'd9784924828, 0, 0, 64'd9784924828);
        queue_read_response(2'd3, 0, 64'd34283049390, 0, 0, 64'd34283049390);
        queue_read_response(2'd3, 0, 64'd8593924893894, 0, 0, 64'd8593924893894);
        queue_read_response(2'd3, 0, 64'h0000000066666666, 1, 0, 64'h0000000066666666);

        //test_num++;
        begin_test("read OoO interleaving, tid = 4");     
        queue_read(32'd3, 8'd1, 3'd3, 2'd1, 0);
        queue_read(32'd0, 8'd2, 3'd3, 2'd2, 0);
        queue_read(32'd4, 8'd3, 3'd3, 2'd3, 0);
        queue_read(32'd6, 8'd2, 3'd3, 2'd0, 0);
        queue_read_response(2'd1, 0, 64'h00000000AAAAAAAA, 0, 0, 64'h00000000AAAAAAAA);
        queue_read_response(2'd1, 0, 64'h00000000BBBBBBBB, 1, 0, 64'h00000000BBBBBBBB);
        queue_read_response(2'd2, 0, 64'hCCCC, 0, 0, 64'hCCCC);
        queue_read_response(2'd2, 0, 64'hDDDD, 0, 0, 64'hDDDD);
        queue_read_response(2'd2, 0, 64'hEEEE, 1, 0, 64'hEEEE);
        queue_read_response(2'd3, 0, 64'd9784924828, 0, 0, 64'd9784924828);
        queue_read_response(2'd3, 0, 64'd34283049390, 0, 0, 64'd34283049390);
        queue_read_response(2'd3, 0, 64'd8593924893894, 0, 0, 64'd8593924893894);
        queue_read_response(2'd3, 0, 64'h0000000066666666, 1, 0, 64'h0000000066666666);
        queue_read_response(2'd0, 0, 64'hAAAAAAAAAAAAAAAA, 0, 0, 64'hAAAAAAAAAAAAAAAA);
        queue_read_response(2'd0, 0, 64'hBBBBBBBBBBBBBBBB, 0, 0, 64'hBBBBBBBBBBBBBBBB);
        queue_read_response(2'd0, 0, 64'h9999999999999999, 1, 0, 64'h9999999999999999);
        $finish;


    end
endmodule

/* verilator coverage_on */

