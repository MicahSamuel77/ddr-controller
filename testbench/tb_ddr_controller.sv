`timescale 1ns / 10ps

`include "type_pkg.vh"

/* verilator coverage_off */

module tb_ddr_controller ();

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

    // interface w/ AXI
    // read
    logic rstrobe, rfull, rerr;
    logic rvalid, ren;
    logic [7:0] raddr;
    logic [63:0] rdata;
    logic [1:0] tid_in, tid_out;
    // write
    logic wstrobe, wfull, werr;
    logic [7:0] waddr;
    logic [63:0] wdata;
    // config register
    logic MRS;
    logic [1:0] burst_size;

    // interface w/ dram
    // outputs
    logic CK, N_CK, CKE, CS, RAS, CAS, WE;
    logic [1:0] B;
    logic [13:0] A;
    // inouts
    wire DQS;
    wire [7:0] DQ;

    // displays
    commands_t display_cmd;
    assign display_cmd = commands_t'({CS, RAS, CAS, WE});

    logic verify_read_write_output  = 1;
    logic verify_MRS_output         = 1;

    ddr_controller DUT (.*);

    // clockgen
    always begin
        clk = 0;
        n_clk = 1;
        #(CLK_PERIOD / 2.0);
        clk = 1;
        n_clk = 0;
        #(CLK_PERIOD / 2.0);
    end

    // DRAM STUFF
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

    always begin : verify_reads
        @(negedge clk);
        if (verify_read_write_output) begin
            if (rvalid) begin
                #(SMALL_DELAY);
                ren = 1;
                test_num++;
                if (expected_read_queue[0].rdata != rdata || expected_read_queue[0].tid != tid_out) begin
                    $display("%sFailed %d: Read - %s%s", COLRED, test_num, test_name, COLNRM);
                    if (expected_read_queue[0].rdata != rdata)  $display("rdata expected %h got %h", expected_read_queue[0].rdata, rdata);
                    if (expected_read_queue[0].tid != tid_out)   $display("tid expected %d got %d", expected_read_queue[0].tid, tid_out);
                end else begin
                    $display("%sPassed %d: read data %h with tid %d in %s%s", COLGRN, test_num, expected_read_queue[0].rdata, expected_read_queue[0].tid, test_name, COLNRM);
                end
                expected_read_queue.pop_front();
                @(negedge clk);
                ren = 0;
            end
        end
    end

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
        if (verify_read_write_output) begin
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

    // TAKING IN WRITE DATA LOGIC
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
    always begin
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
        rstrobe = 0;
        wstrobe = 0;
        MRS = 0;
        ren = 0;
        burst_size = 0;
        tid_in = 0;
        raddr = 0;
        waddr = 0;
        wdata = 0;
        dram_strobe = 'z;
        dram_data = 'z;
    end
    endtask

    task check_outputs;
        input commands_t expected_cmd;
        input logic [1:0] expected_B;
        input logic [13:0] expected_A;
        input logic expected_DQS;
        input logic [7:0] expected_DQ;
    begin
        if (expected_cmd    != {CS, RAS, CAS, WE}   || 
            expected_B      != B                    ||
            expected_A      != A                    ||
            expected_DQS    != DQS                  || 
            expected_DQ     != DQ) begin
            $display("%sFailed Test #%d: %s%s", COLRED, test_num, test_name, COLNRM);
                // if (expected_CKE != CKE)                $display("CKE expected %d got %d", expected_CKE, CKE);
                if (expected_cmd != {CS, RAS, CAS, WE}) $display("cmd expected %d got %d", expected_cmd, {CS, RAS, CAS, WE});
                if (expected_B   != B)                  $display("B expected %d got %d", expected_B, B);
                if (expected_A   != A)                  $display("A expected %d got %d", expected_A, A);
        end else begin
            $display("%sPassed Test #%d: %s%s", COLGRN, test_num, test_name, COLNRM);
        end
    end
    endtask

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

    task queue_read;
        input logic [7:0] new_raddr;
        input logic [1:0] new_tid_in;
    begin
        raddr   = new_raddr;
        tid_in  = new_tid_in;
        rstrobe = 1;

        @(negedge clk);

        raddr = 0;
        tid_in = 0;
        rstrobe = 0;
    end
    endtask

    task queue_read_no_clock;
        input logic [7:0] new_raddr;
        input logic [1:0] new_tid_in;
    begin
        raddr   = new_raddr;
        tid_in  = new_tid_in;
        rstrobe = 1;
    end
    endtask

    task clear_read;
    begin
        raddr = 0;
        tid_in = 0;
        rstrobe = 0;
    end
    endtask;

    task clear_write;
    begin
        waddr   = 0;
        wdata   = 0;
        wstrobe = 0;
    end
    endtask

    task queue_write;
        input logic [7:0] new_waddr;
        input logic [63:0] new_wdata;
    begin
        waddr   = new_waddr;
        wdata   = new_wdata;
        wstrobe = 1;

        @(negedge clk);

        waddr   = 0;
        wdata   = 0;
        wstrobe = 0;
    end
    endtask

    task queue_write_no_clock;
        input logic [7:0] new_waddr;
        input logic [63:0] new_wdata;
    begin
        waddr   = new_waddr;
        wdata   = new_wdata;
        wstrobe = 1;
    end
    endtask

    task queue_write_then_read;
        input logic [7:0] new_raddr;
        input logic [1:0] new_tid_in;
        input logic [7:0] new_waddr;
        input logic [63:0] new_wdata;
    begin

        waddr   = new_waddr;
        wdata   = new_wdata;
        wstrobe = 1;

        @(negedge clk);

        raddr   = new_raddr;
        tid_in  = new_tid_in;
        rstrobe = 1;

        waddr   = 0;
        wdata   = 0;
        wstrobe = 0;

        @(negedge clk);

        raddr = 0;
        tid_in = 0;
        rstrobe = 0;
    end
    endtask


    // KEEP EDITING THIS
    task queue_random_raw;
        input burst_size_t wanted_burst_size;
        input logic [1:0] wanted_tid;
        logic [63:0] random_data;
        read_info_tb random_raw;
    begin
        case (wanted_burst_size)
            ONE_BYTE: begin
                random_raw.rdata = {56'b0, get_random_data()[7:0]};
                random_raw.addr = get_random_address();
                random_raw.tid = wanted_tid;
            end TWO_BYTES: begin
                random_raw.rdata = {48'b0, get_random_data()[15:0]};
                random_raw.addr = get_random_address();
                random_raw.tid = wanted_tid;
            end FOUR_BYTES: begin
                random_raw.rdata = {32'b0, get_random_data()[31:0]};
                random_raw.addr = get_random_address();
                random_raw.tid = wanted_tid;
            end EIGHT_BYTES: begin
                random_raw.rdata = {get_random_data()};
                random_raw.addr = get_random_address();
                random_raw.tid = wanted_tid;
            end
        endcase
        
        queue_write_then_read(random_raw.addr, random_raw.tid, random_raw.addr, random_raw.rdata);
        queue_expected_write(random_raw.addr, random_raw.rdata);
        queue_expected_read(random_raw.rdata, random_raw.tid);
    end
    endtask

    read_info_tb random_reads [$];

    task queue_random_write;
        input burst_size_t wanted_burst_size;
        input logic [1:0] wanted_tid;
        logic [63:0] random_data;
        read_info_tb random_read;
    begin
        case (wanted_burst_size)
            ONE_BYTE: begin
                random_read.rdata = {56'b0, get_random_data()[7:0]};
                random_read.addr = get_random_address();
                random_read.tid = wanted_tid;
            end TWO_BYTES: begin
                random_read.rdata = {48'b0, get_random_data()[15:0]};
                random_read.addr = get_random_address();
                random_read.tid = wanted_tid;
            end FOUR_BYTES: begin
                random_read.rdata = {32'b0, get_random_data()[31:0]};
                random_read.addr = get_random_address();
                random_read.tid = wanted_tid;
            end EIGHT_BYTES: begin
                random_read.rdata = {get_random_data()};
                random_read.addr = get_random_address();
                random_read.tid = wanted_tid;
            end
        endcase
        random_reads.push_back(random_read);
        queue_write(random_read.addr, random_read.rdata);
        queue_expected_write(random_read.addr, random_read.rdata);
    end
    endtask

    task check_command;
    input commands_t expected_cmd;
    begin
        test_num++;
        if (expected_cmd != display_cmd) begin
                $display("%sFailed %d: Priority - %s%s", COLRED, test_num, test_name, COLNRM);
                $display("Command output expected %s got %s", expected_cmd.name(), display_cmd.name());
            end else begin
                $display("%sPassed %d: command scheduler prioritized %s in %s%s", COLGRN, test_num, expected_cmd.name(), test_name, COLNRM);
        end
    end
    endtask

    task queue_random_read;
    begin
        queue_read(random_reads[0].addr, random_reads[0].tid);
        queue_expected_read(random_reads[0].rdata, random_reads[0].tid);
        random_reads.pop_front();
    end
    endtask

    burst_size_t expected_burst_size;
    task set_burst_size;
    input burst_size_t new_burst_size;
    begin
        unique case (new_burst_size)
            ONE_BYTE:       burst_size = 0;
            TWO_BYTES:      burst_size = 1;
            FOUR_BYTES:     burst_size = 2;
            EIGHT_BYTES:    burst_size = 3;
        endcase
        MRS = 1;
        expected_burst_size = new_burst_size;

        @(negedge clk);

        MRS = 0;
    end
    endtask

    always begin : verify_burst_size
        @(posedge clk)
        if (verify_MRS_output) begin
            if (display_cmd == MODE_REGISTER_SET) begin
                test_num++;
                if (A[1:0] != expected_burst_size) begin
                    $display("%sFailed %d: MRS - %s%s", COLRED, test_num, test_name, COLNRM);
                    $display("Mode register set expected %d got %d", expected_burst_size, A[1:0]);
                end else begin
                    $display("%sPassed %d: burst size set to %b in %s%s", COLGRN, test_num, A[1:0], test_name, COLNRM);
                end
            end
        end
    end

    task check_err;
    input logic expected_err;
    input logic read_if_true;
    begin
        test_num++;
        if (read_if_true) begin
            if (rerr != expected_err) begin
                $display("%sFailed %d: ERR - %s%s", COLRED, test_num, test_name, COLNRM);
                $display("rerr expected %d got %d", expected_err, rerr);
            end else begin
                $display("%sPassed %d: rerr is %b in %s%s", COLGRN, test_num, rerr, test_name, COLNRM);
            end
        end else begin
            if (werr != expected_err) begin
                $display("%sFailed %d: ERR - %s%s", COLRED, test_num, test_name, COLNRM);
                $display("werr expected %d got %d", expected_err, werr);
            end else begin
                $display("%sPassed %d: werr is %b in %s%s", COLGRN, test_num, werr, test_name, COLNRM);
            end
        end

    end
    endtask

    initial begin
        n_rst = 1;
        reset_inputs;
        reset_dut;
        
        begin_test_cluster("initialization", 1);
        begin_test("init sequence MRS");
        cycle_clock(2800);


        // CRITERIA 1
        begin_test_cluster("basic read/writes", 1);

        begin_test("basic burst size 1");
        set_burst_size(ONE_BYTE);
        begin_test("one byte reads/writes");
        queue_random_write(ONE_BYTE, 0);
        cycle_clock(15);
        queue_random_read();
        cycle_clock(15);

        queue_random_write(ONE_BYTE, 1);
        cycle_clock(15);
        queue_random_read();
        cycle_clock(15);

        queue_random_write(ONE_BYTE, 2);
        cycle_clock(15);
        queue_random_read();
        cycle_clock(15);

        queue_random_write(ONE_BYTE, 3);
        cycle_clock(15);
        queue_random_read();
        cycle_clock(15);

        queue_random_write(ONE_BYTE, 0);
        cycle_clock(15);
        queue_random_read();
        cycle_clock(15);

        queue_random_write(ONE_BYTE, 1);
        cycle_clock(15);
        queue_random_read();
        cycle_clock(15);

        queue_random_write(ONE_BYTE, 2);
        cycle_clock(15);
        queue_random_read();
        cycle_clock(15);

        queue_random_write(ONE_BYTE, 3);
        cycle_clock(15);
        queue_random_read();
        cycle_clock(15);


        // CRITERIA 2
        begin_test_cluster("configuration register set", 1);

        begin_test("basic mrs");
        set_burst_size(TWO_BYTES);
        cycle_clock(15);
        set_burst_size(FOUR_BYTES);
        cycle_clock(15);
        set_burst_size(EIGHT_BYTES);
        cycle_clock(15);

        begin_test("complex mrs");
        set_burst_size(ONE_BYTE);
        queue_random_write(ONE_BYTE, 2);
        queue_random_write(ONE_BYTE, 2);
        set_burst_size(TWO_BYTES);
        queue_random_write(TWO_BYTES, 2);
        queue_random_write(TWO_BYTES, 2);
        cycle_clock(60);
        set_burst_size(FOUR_BYTES);
        queue_random_write(FOUR_BYTES, 2);
        queue_random_write(FOUR_BYTES, 2);
        cycle_clock(60);
        set_burst_size(EIGHT_BYTES);
        queue_random_write(EIGHT_BYTES, 2);
        queue_random_write(EIGHT_BYTES, 2);
        cycle_clock(200);
        random_reads.delete();


        // CRITERIA 3
        begin_test_cluster("burst read / write", 1);
        begin_test("two byte read / write");
        set_burst_size(TWO_BYTES);
        queue_random_write(TWO_BYTES, 1);
        cycle_clock(15);
        queue_random_read();
        cycle_clock(15);

        begin_test("four byte read / write");
        set_burst_size(FOUR_BYTES);
        queue_random_write(FOUR_BYTES, 2);
        cycle_clock(15);
        queue_random_read();
        cycle_clock(15);

        begin_test("eight byte read / write");
        set_burst_size(EIGHT_BYTES);
        queue_random_write(EIGHT_BYTES, 3);
        cycle_clock(15);
        queue_random_read();
        cycle_clock(15);


        // CRITERIA 4
        begin_test_cluster("raw error handling", 1);
        begin_test("one byte raw");
        set_burst_size(ONE_BYTE);
        cycle_clock(15);
        queue_random_raw(ONE_BYTE, 1);
        cycle_clock(30);

        begin_test("two byte raw");
        set_burst_size(TWO_BYTES);
        cycle_clock(15);
        queue_random_raw(TWO_BYTES, 1);
        cycle_clock(15);
        queue_write_then_read(8'b100_01_011, 2, 8'b100_01_010, 64'h32_FE);
        queue_expected_read(64'hfE_32, 2);
        queue_expected_write(8'b100_01_010, 64'h32_FE);
        cycle_clock(30);

        begin_test("four byte raw");
        set_burst_size(FOUR_BYTES);
        cycle_clock(15);
        queue_random_raw(FOUR_BYTES, 1);
        cycle_clock(15);
        queue_write_then_read(8'b100_11_011, 2, 8'b100_11_001, 64'hE9_A3_12_A2);
        queue_expected_read(64'h12_A2_E9_A3, 2);
        queue_expected_write(8'b100_11_001, 64'hE9_A3_12_A2);
        cycle_clock(15);
        queue_write_then_read(8'b100_00_100, 0, 8'b100_00_111, 64'h8F_BB_6A_12);
        queue_expected_read(64'h12_8F_BB_6A, 0);
        queue_expected_write(8'b100_00_111, 64'h8F_BB_6A_12);
        cycle_clock(30);

        begin_test("eight byte raw");
        set_burst_size(EIGHT_BYTES);
        cycle_clock(15);
        queue_random_raw(EIGHT_BYTES, 1);
        cycle_clock(15);
        queue_write_then_read(8'b100_10_110, 2, 8'b100_10_001, 64'hBF_14_1E_AC_67_C9_00_D0);
        queue_expected_read(64'hAC_67_C9_00_D0_BF_14_1E, 2);
        queue_expected_write(8'b100_10_001, 64'hBF_14_1E_AC_67_C9_00_D0);
        cycle_clock(15);
        queue_write_then_read(8'b100_01_010, 0, 8'b100_01_111, 64'hAB_CD_FA_FE_3D_2A_A4_77);
        queue_expected_read(64'h2A_A4_77_AB_CD_FA_FE_3D, 0);
        queue_expected_write(8'b100_01_111, 64'hAB_CD_FA_FE_3D_2A_A4_77);
        cycle_clock(30);

        // CRITERIA 5
        begin_test_cluster("read priority < write priority", 1);
        begin_test("");
        verify_read_write_output = 0;
        verify_MRS_output = 0;
        set_burst_size(ONE_BYTE);
        cycle_clock(10);
        queue_read(8'b101_11_111, 1);
        cycle_clock(10);

        begin_test("open page read, closed page write");
        queue_read_no_clock(8'b101_11_111, 0);
        queue_write_no_clock(8'b101_10_111, 64'hEF);
        cycle_clock(1);
        clear_read;
        clear_write;
        cycle_clock(1);
        check_command(READ);
        cycle_clock(20);

        begin_test("open page read, cross page write");
        queue_read_no_clock(8'b101_10_111, 0);
        queue_write_no_clock(8'b111_11_111, 64'hEF);
        cycle_clock(1);
        clear_read;
        clear_write;
        cycle_clock(1);
        check_command(READ);
        cycle_clock(20);

        begin_test("closed page read, cross page write");
        queue_read_no_clock(8'b111_10_111, 0);
        queue_write_no_clock(8'b101_10_111, 64'hEF);
        cycle_clock(1);
        clear_read;
        clear_write;
        cycle_clock(4);
        check_command(READ);
        cycle_clock(20);

        begin_test("open page same we read, open page dif we write");
        queue_read(8'b101_11_111, 1);
        queue_read_no_clock(8'b101_11_100, 0);
        queue_write_no_clock(8'b101_11_101, 8'hCF);
        cycle_clock(1);
        clear_read;
        clear_write;
        cycle_clock(4);
        check_command(READ);

        begin_test_cluster("read priority > write priority", 1);
        begin_test("");
        cycle_clock(10);
        queue_read(8'b101_11_111, 1);
        cycle_clock(10);

        begin_test("closed page read, open page write");
        queue_read_no_clock(8'b101_10_111, 64'hEF);
        queue_write_no_clock(8'b101_11_111, 0);
        cycle_clock(1);
        clear_read;
        clear_write;
        cycle_clock(1);
        check_command(WRITE);
        cycle_clock(20);

        begin_test("cross page read, open page write");
        queue_write_no_clock(8'b101_10_111, 64'hEF);
        queue_read_no_clock(8'b111_11_111, 0);
        cycle_clock(1);
        clear_read;
        clear_write;
        cycle_clock(1);
        check_command(WRITE);
        cycle_clock(20);

        begin_test("cross page read, closed page write");
        queue_write_no_clock(8'b111_10_111, 64'hEF);
        queue_read_no_clock(8'b101_10_111, 0);
        cycle_clock(1);
        clear_read;
        clear_write;
        cycle_clock(4);
        check_command(WRITE);
        cycle_clock(20);

        begin_test("open page dif we read, open page same we write");
        queue_write(8'b101_11_111, 1);
        queue_write_no_clock(8'b101_11_100, 64'hEF);
        queue_read_no_clock(8'b101_11_101, 0);
        cycle_clock(1);
        clear_read;
        clear_write;
        cycle_clock(4);
        check_command(WRITE);
        cycle_clock(20);

        begin_test_cluster("b2b write bursts", 1);
        begin_test("b2b2b2b 2 byte write bursts");
        set_burst_size(TWO_BYTES);
        cycle_clock(10);
        queue_write(8'b100_11_000, 64'hA4_CC);
        queue_write_no_clock(8'b100_11_010, 64'h38_F2);
        cycle_clock(1);
        queue_write_no_clock(8'b100_11_100, 64'hBD_ED);
        cycle_clock(1);
        queue_write_no_clock(8'b100_11_111, 64'h11_22);
        cycle_clock(1);
        clear_write;
        cycle_clock(80);

        begin_test("b2b 4 byte write bursts");
        set_burst_size(FOUR_BYTES);
        cycle_clock(10);
        queue_write(8'b111_11_000, 64'h44_33_22_11);
        queue_write_no_clock(8'b111_11_100, 64'h88_77_66_55);
        cycle_clock(1);
        clear_write;
        cycle_clock(40);

        begin_test("b2b 8 byte write bursts");
        set_burst_size(EIGHT_BYTES);
        cycle_clock(10);
        queue_write(8'b000_11_111, 64'h77_66_55_44_33_22_11_00);
        queue_write_no_clock(8'b000_11_000, 64'hFF_EE_DD_CC_BB_AA_99_88);
        cycle_clock(1);
        clear_write;
        cycle_clock(40);

        begin_test_cluster("b2b read bursts", 1);
        begin_test("b2b2b2b 2 byte read bursts");
        set_burst_size(TWO_BYTES);
        cycle_clock(10);
        queue_read(8'b100_11_000, 0);
        queue_read(8'b100_11_010, 0);
        queue_read(8'b100_11_100, 0);
        queue_read(8'b100_11_111, 0);
        cycle_clock(80);

        begin_test("b2b 4 byte read bursts");
        set_burst_size(FOUR_BYTES);
        cycle_clock(10);
        queue_read(8'b111_11_000, 1);
        queue_read(8'b111_11_100, 1);
        cycle_clock(1);
        clear_read;
        cycle_clock(40);

        begin_test("b2b 8 byte read bursts");
        set_burst_size(EIGHT_BYTES);
        cycle_clock(10);
        queue_read(8'b000_11_111, 2);
        queue_read(8'b000_11_000, 2);
        clear_read;
        cycle_clock(4);
        cycle_clock(40);

        // CRITERIA 6
        begin_test_cluster("error cases", 1);
        begin_test("rerr high");
        queue_read(8'b100_00_000, 2);
        queue_read(8'b101_00_000, 2);
        queue_read(8'b110_00_000, 2);
        queue_read(8'b101_00_000, 2);
        queue_read(8'b100_00_000, 2);
        queue_read(8'b101_00_000, 2);
        queue_read(8'b100_00_000, 2);
        queue_read(8'b101_00_000, 2);
        queue_read(8'b100_00_000, 2);
        queue_read(8'b101_00_000, 2);
        queue_read(8'b100_00_000, 2);
        check_err(1, 1);
        cycle_clock(20);

        begin_test("werr high");
        queue_write(8'b100_00_000, 64'hCF);
        queue_write(8'b101_00_000, 64'hCF);
        queue_write(8'b110_00_000, 64'hCF);
        queue_write(8'b101_00_000, 64'hCF);
        queue_write(8'b100_00_000, 64'hCF);
        queue_write(8'b101_00_000, 64'hCF);
        queue_write(8'b100_00_000, 64'hCF);
        queue_write(8'b101_00_000, 64'hCF);
        queue_write(8'b100_00_000, 64'hCF);
        queue_write(8'b101_00_000, 64'hCF);
        queue_write(8'b100_00_000, 64'hCF);
        check_err(1, 0);

        cycle_clock(30);
        $finish;
    end
endmodule

/* verilator coverage_on */

