`timescale 1ns / 10ps

`include "type_pkg.vh"
/* verilator coverage_off */

module tb_top ();

    import type_pkg::*;

    localparam CLK_PERIOD = 100ns;
    localparam SMALL_DELAY = 25ns;
    localparam THANKYOUSPENCER = 800ps;

    localparam COLNRM = "\x1B[0m";
    localparam COLRED = "\x1B[31m";
    localparam COLGRN = "\x1B[32m";
    localparam COLCYA = "\x1B[36m";

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars;
    end

    logic clk, n_clk, n_rst;

    // interface with AXI and DDR controller
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

    // interface w/ dram
    // outputs
    logic CK, N_CK, CKE, CS, RAS, CAS, WE;
    logic [1:0] B;
    logic [13:0] A;
    // inouts
    wire DQS;
    wire [7:0] DQ;

    // display for testbench
    commands_t display_cmd;
    assign display_cmd = commands_t'({CS, RAS, CAS, WE});

    // logging bools
    logic log_read_write_verification  = 1;
    logic log_MRS_verification         = 1;

    top #() DUT (.*);

    // clockgen
    always begin
        clk     = 0;
        n_clk   = 1;
        #(CLK_PERIOD / 2.0);
        clk     = 1;
        n_clk   = 0;
        #(CLK_PERIOD / 2.0);
    end

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
        DRAM VERIFICATION
    -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= */

    byte memory [3:0][7:0][7:0];
    logic dram_strobe;
    logic [7:0] dram_data;

    assign DQS  = dram_strobe;
    assign DQ   = dram_data;

    int dram_cycles [3:0];
    assign dram_cycles = {1, 1, 2, 4};
    logic [1:0] dram_burst_size;
    logic [2:0] dram_row;
    logic [1:0] dram_bank;
    logic [2:0] dram_column;
    always begin
        @(posedge clk);
        if (display_cmd == MODE_REGISTER_SET)                   dram_burst_size = A[1:0];
        if (display_cmd == ACTIVE)                              dram_row = A[2:0];
        if (display_cmd == READ || display_cmd == WRITE)        dram_bank = B;
        if (display_cmd == READ || display_cmd == WRITE)        dram_column = A[2:0];
    end

    typedef struct packed {
        logic [63:0] rdata;
        logic [1:0] tid;
        logic [7:0] addr;
    } read_info_tb;

    read_info_tb expected_read_queue [$];
    task queue_expected_read;
        input logic [63:0] expected_data;
        input logic [1:0] expected_tid;
        read_info_tb read_info;
    begin
        read_info.rdata = expected_data;
        read_info.tid = expected_tid;
        expected_read_queue.push_back(read_info);
    end
    endtask

    typedef struct packed {
        logic [63:0] expected_data;
        logic [1:0] expected_bank;
        logic [2:0] expected_row;
        logic [2:0] expected_col;
    } write_info_tb;

    write_info_tb expected_write_queue [$];
    logic [63:0] adjusted_memory_data;
    task queue_expected_write;
        input logic [7:0] expected_addr;
        input logic [63:0] expected_data;
        write_info_tb expected_write_info;
    begin
        expected_write_info.expected_data = expected_data;
        expected_write_info.expected_row = expected_addr[7:5];
        expected_write_info.expected_bank = expected_addr[4:3];
        expected_write_info.expected_col = expected_addr[2:0];
        expected_write_queue.push_back(expected_write_info);
    end
    endtask

    logic [63:0] expected_memory_data;
    logic [1:0] expected_bank;
    logic [2:0] expected_row;
    logic [2:0] expected_col;
    logic [1:0] burst4_col_temp;
    always begin : verify_writes
        @(negedge clk);
        if (log_read_write_verification) begin
            if (display_cmd == WRITE) begin
                expected_memory_data = expected_write_queue[0].expected_data;
                expected_bank        = expected_write_queue[0].expected_bank;
                expected_row         = expected_write_queue[0].expected_row;
                expected_col         = expected_write_queue[0].expected_col;
                burst4_col_temp      = expected_col[1:0];
                @(posedge clk);
                @(posedge clk);
                test_num++;
                if (dram_burst_size == 0) begin
                    @(posedge clk);
                    #(SMALL_DELAY);
                    adjusted_memory_data = {56'b0, memory[expected_bank][expected_row][expected_col]};
                    if (expected_memory_data != adjusted_memory_data) begin
                        $display("%sFailed %d: Write - %s%s", COLRED, test_num, test_name, COLNRM);
                        $display("Expected %h of burst size 1 at %b_%b_%b got %h", expected_memory_data, expected_bank, expected_row, expected_col, adjusted_memory_data);
                    end else begin
                        $display("%sPassed %d: wrote 1 byte %h to address %b_%b_%b in %s%s", COLGRN, test_num, expected_memory_data, expected_bank, expected_row, expected_col, test_name, COLNRM);
                    end
                    expected_write_queue.pop_front();
                end else if (dram_burst_size == 1) begin
                    @(posedge clk);
                    #(SMALL_DELAY);
                    adjusted_memory_data = {48'b0, memory[expected_bank][expected_row][{expected_col[2:1], ~expected_col[0]}], memory[expected_bank][expected_row][{expected_col[2:1], expected_col[0]}]};
                    if (expected_memory_data != adjusted_memory_data) begin
                        $display("%sFailed %d: Write - %s%s", COLRED, test_num, test_name, COLNRM);
                        $display("Expected %h of burst size 2 at %b_%b_%b got %h", expected_memory_data, expected_bank, expected_row, expected_col, adjusted_memory_data);
                    end else begin
                        $display("%sPassed %d: wrote two bytes %h to address %b_%b_%b in %s%s", COLGRN, test_num, expected_memory_data, expected_bank, expected_row, expected_col, test_name, COLNRM);
                    end
                    expected_write_queue.pop_front();
                end else if (dram_burst_size == 2) begin
                    @(posedge clk);
                    @(posedge clk);
                    @(posedge clk);
                    #(SMALL_DELAY);
                    adjusted_memory_data = {32'b0, 
                                            memory[expected_bank][expected_row][{expected_col[2], ((burst4_col_temp+ 2'b11) % 3'b100)<<1}>>1],
                                            memory[expected_bank][expected_row][{expected_col[2], ((burst4_col_temp+2'b10) % 3'b100)<<1}>>1],
                                            memory[expected_bank][expected_row][{expected_col[2], ((burst4_col_temp+2'b1) % 3'b100)<<1}>>1],
                                            memory[expected_bank][expected_row][{expected_col[2], ((burst4_col_temp) % 3'b100)<<1}>>1]};
                    if (expected_memory_data != adjusted_memory_data) begin
                        $display("%sFailed %d: Write - %s%s", COLRED, test_num, test_name, COLNRM);
                        $display("Expected %h of burst size 4 at %b_%b_%b got %h", expected_memory_data, expected_bank, expected_row, expected_col, adjusted_memory_data);
                    end else begin
                        $display("%sPassed %d: wrote four bytes %h of to address %b_%b_%b in %s%s", COLGRN, test_num, expected_memory_data, expected_bank, expected_row, expected_col, test_name, COLNRM);
                    end
                    expected_write_queue.pop_front();
                end else begin
                    @(posedge clk);
                    @(posedge clk);
                    @(posedge clk);
                    @(posedge clk);
                    #(SMALL_DELAY);
                    adjusted_memory_data = {memory[expected_bank][expected_row][(expected_col+7) % 8],
                                            memory[expected_bank][expected_row][(expected_col+6) % 8],
                                            memory[expected_bank][expected_row][(expected_col+5) % 8],
                                            memory[expected_bank][expected_row][(expected_col+4) % 8],
                                            memory[expected_bank][expected_row][(expected_col+3) % 8],
                                            memory[expected_bank][expected_row][(expected_col+2) % 8],
                                            memory[expected_bank][expected_row][(expected_col+1) % 8],
                                            memory[expected_bank][expected_row][(expected_col) % 8]};
                    if (expected_memory_data != adjusted_memory_data) begin
                        $display("%sFailed %d: Write - %s%s", COLRED, test_num, test_name, COLNRM);
                        $display("Expected %h of burst size 8 at %b_%b_%b got %h", expected_memory_data, expected_bank, expected_row, expected_col, adjusted_memory_data);
                    end else begin
                        $display("%sPassed %d: wrote eight bytes %h of to address %b_%b_%b in %s%s", COLGRN, test_num, expected_memory_data, expected_bank, expected_row, expected_col, test_name, COLNRM);
                    end
                    expected_write_queue.pop_front();
                end
            end
        end
    end

    /* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        DRAM MODEL
    -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= */

    int write_idx;
    logic first_clk;
    logic micah_loves_nico_harrison;
    logic [1:0] write_4_val;
    logic [2:0] write_8_val;
    logic [2:0] delay_dram_column, delay2_dram_column;
    commands_t delay_display_cmd, delay2_display_cmd;
    always @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            delay_display_cmd <= commands_t'(0);
            delay2_display_cmd <= commands_t'(0);
        end else begin
            delay_display_cmd <= display_cmd;
            delay2_display_cmd <= delay_display_cmd;
        end
    end
    always @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            delay_dram_column <= 0;
            delay2_dram_column <= 0;
        end else begin
            delay_dram_column <= dram_column;
            delay2_dram_column <= delay_dram_column;
        end
    end
    always begin : writing_data_on_dq
        @(posedge clk);
        first_clk = 1;
        if (delay_display_cmd == WRITE) begin
            if (dram_burst_size < 2) begin
                if (first_clk) first_clk = 0;
                else @(posedge clk);
                #(SMALL_DELAY);
                memory[dram_bank][dram_row][delay_dram_column[2:0]] = DQ;
                if (dram_burst_size == 1) begin
                    @(negedge clk);
                    #(SMALL_DELAY);
                    memory[dram_bank][dram_row][{delay_dram_column[2:1], ~delay_dram_column[0]}] = DQ;
                end
            end else if (dram_burst_size == 2) begin
                for (write_idx = 0; write_idx < 2; write_idx++) begin
                    if (first_clk) begin
                        first_clk = 0;
                        #(SMALL_DELAY);
                        micah_loves_nico_harrison = delay_dram_column[2];
                        write_4_val = delay_dram_column[1:0] - 1;
                    end
                    else begin
                        @(posedge clk);
                        #(SMALL_DELAY);
                    end
                    write_4_val++;
                    memory[dram_bank][dram_row][{micah_loves_nico_harrison, write_4_val}] = DQ;
                    @(negedge clk);
                    #(SMALL_DELAY);
                    write_4_val++;
                    memory[dram_bank][dram_row][{micah_loves_nico_harrison, write_4_val}] = DQ;
                end
            end else begin 
                for (write_idx = 0; write_idx < 4; write_idx++) begin
                    if (first_clk) begin
                        first_clk = 0;
                        #(SMALL_DELAY);
                        write_8_val = delay_dram_column[2:0] - 1;
                    end
                    else begin
                        @(posedge clk);
                        #(SMALL_DELAY);
                    end
                    write_8_val++;
                    memory[dram_bank][dram_row][write_8_val] = DQ;
                    @(negedge clk);
                    #(SMALL_DELAY);
                    write_8_val++;
                    memory[dram_bank][dram_row][write_8_val] = DQ;
                end
            end
        end
    end

     // SENDING OUT READ DATA LOGIC
    int read_idx;
    logic micah_wanted_to_trade_luca_doncic;
    logic kill_me_now;
    logic [1:0] read_4_val;
    logic [2:0] read_8_val;
    
    always begin
        @(posedge clk);
        #(THANKYOUSPENCER);
        dram_strobe = 'z;
        dram_data = 'z;
        kill_me_now = 0;
        if (delay2_display_cmd == READ) begin
            // @(posedge clk);
            if (dram_burst_size < 2) begin
                dram_strobe = 1;
                dram_data = memory[dram_bank][dram_row][delay2_dram_column[2:0]];
                if (dram_burst_size == 1) begin
                    @(negedge clk);
                    #(THANKYOUSPENCER);
                    dram_strobe = 0;
                    dram_data = memory[dram_bank][dram_row][{delay2_dram_column[2:1], ~delay2_dram_column[0]}];
                end else begin
                    @(negedge clk);
                    #(THANKYOUSPENCER);
                    dram_strobe = 0;
                    dram_data = 0;
                end
            end else if (dram_burst_size == 2) begin
                micah_wanted_to_trade_luca_doncic = delay2_dram_column[2];
                read_4_val = delay2_dram_column[1:0] - 1;
                for (read_idx = 0; read_idx < 2; read_idx++) begin
                    if (!kill_me_now) kill_me_now = 1;
                    else begin @(posedge clk); #(THANKYOUSPENCER); end
                    dram_strobe = 1;
                    read_4_val++;
                    dram_data = memory[dram_bank][dram_row][{micah_wanted_to_trade_luca_doncic, read_4_val}];
                    @(negedge clk);
                    dram_strobe = 0;
                    read_4_val++;
                    #(THANKYOUSPENCER);
                    dram_data = memory[dram_bank][dram_row][{micah_wanted_to_trade_luca_doncic, read_4_val}];
                end
            end else begin 
                read_8_val = delay2_dram_column[2:0] - 1;
                for (read_idx = 0; read_idx < 4; read_idx++) begin
                    if (!kill_me_now) kill_me_now = 1;
                    else begin @(posedge clk); #(THANKYOUSPENCER); end           
                    dram_strobe = 1;
                    read_8_val++;
                    dram_data = memory[dram_bank][dram_row][read_8_val];
                    @(negedge clk);
                    #(THANKYOUSPENCER);
                    dram_strobe = 0;
                    read_8_val++;
                    dram_data = memory[dram_bank][dram_row][read_8_val];
                end
            end
        end
    end

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

    task queue_read;
        input logic[31:0] address;
        input logic [7:0] num_transfers;
        input logic [2:0] transfer_size;
        input logic [1:0] transaction_id;
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
        $display("address has been queued");
    end
    endtask

    task queue_write_data;
        input logic [63:0] data;
        input logic last;
        input logic err;
        input logic write_full;
        input logic [7:0] write_strobe;
    begin
        @(negedge clk);
        WVALID = 1'b1;
        WDATA = data;
        WLAST = last;
        WSTRB = write_strobe;
        @(negedge WREADY);  
        WVALID = 1'b0;
        WLAST = 1'b0;
        @(posedge BVALID);
        BREADY = 1'b1;
        @(negedge BVALID);
        BREADY = 1'b0;
    end
    endtask

    /* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        INITIALIZATION
    -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= */

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

    task reset_inputs;
    begin
        ARID            = 0;
        ARADDR          = 0;
        ARLEN           = 0;
        ARSIZE          = 0;
        ARBURST         = 0;
        ARVALID         = 0;
        RREADY          = 0;

        AWID            = 0;
        AWADDR          = 0;
        AWLEN           = 0;
        AWSIZE          = 0;
        AWBURST         = 0;
        AWVALID         = 0;

        WDATA           = 0;
        WSTRB           = 0;
        WLAST           = 0;
        WVALID          = 0;

        BREADY          = 0;
        dram_strobe     = 'z;
        dram_data       = 'z;
    end
    endtask

    int verify_read_idx;
    logic [31:0][63:0] testvec;
    logic log_read = 1;
    always begin : read_data_verification
        @(posedge clk)
        if (log_read) begin
            if (RVALID) begin
                if (testvec[verify_read_idx] == RDATA) begin
                    $display("%sPassed %d: %h read successfully during %s%s", COLGRN, test_num, testvec[verify_read_idx], test_name, COLNRM);
                end else begin
                    $display("%sFailed %d: expected %h got %h during %s%s", COLRED, test_num, testvec[verify_read_idx], RDATA, test_name, COLNRM);
                end
                verify_read_idx++;
                test_num++;
            end
        end
    end
        
    int i;
    initial begin
        n_rst = 1;

        reset_inputs;
        reset_dut;

        log_MRS_verification        = 0;
        log_read_write_verification = 0;
        begin_test_cluster("initialization", 1);
        begin_test("init sequence");
        cycle_clock(2800);

        begin_test_cluster("basic reads / writes", 1);
        begin_test("one byte read / write");

        @(posedge clk);
        queue_write_address(2'd0, 8'd1, 3'd0, 32'd8);
        queue_write_data(64'hA5A5A5A5A5A5A5A5, 0, 0, 0, 8'hFF);
        queue_write_data(64'h5A5A5A5A5A5A5A5A, 1, 1, 0, 8'hFF);
        cycle_clock(200);

        queue_write_address(2'd1, 8'd2, 3'd0, 32'd16);
        queue_write_data(64'h0AA, 0, 0, 0, 8'hFF);
        queue_write_data(64'hBB00, 0, 0, 0, 8'hFF);
        queue_write_data(64'hCC0000, 1, 0, 0, 8'hFF);

        /* set bus size */
        queue_write_address(0, 0, 0, 32'h100);
        queue_write_data(64'h3, 1, 0, 0, 8'h01);

        begin_test_cluster("mass reads / writes", 1);
        begin_test("mass 8 byte writes");
        queue_write_address(2'd2, 8'd31, 3'd3, 32'd00);
        for (i = 0; i < 32; i++) testvec[i] = get_random_data();

        verify_read_idx = 0;
        for (i = 0; i < 32; i++) queue_write_data(testvec[i], i == 31, 0, 0, 8'hFF);
        cycle_clock(100);
        queue_read(0, 31, 3, 1);
        RREADY = 1'b1;

        begin_test("mass 8 byte reads");
        cycle_clock(1000);
        log_read = 0;

        queue_write_address(0, 0, 0, 32'h100);
        queue_write_data(0, 1, 0, 0, 8'h01);
        
        begin_test_cluster("interleaving demo", 0);
        begin_test("no tid interleaving");
        queue_read(0, 31, 0, 1);
        queue_read(0, 31, 0, 1);

        cycle_clock(500);
        
        begin_test("tid interleaving");
        queue_read(0, 31, 0, 1);
        queue_read(0, 31, 0, 2);

        cycle_clock(1000);

        $finish;
    end
endmodule

/* verilator coverage_on */

