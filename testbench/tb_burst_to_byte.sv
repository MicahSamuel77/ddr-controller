`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_burst_to_byte ();

    localparam CLK_PERIOD = 10ns;

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars;
    end

    logic clk, n_clk, n_rst;
    logic dq_oe;
    logic [63:0] pool_wdata;
    logic [1:0] burst_size;

    // clockgen
    always begin
        clk = 0;
        n_clk = 1;
        #(CLK_PERIOD / 2.0);
        clk = 1;
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

    burst_to_byte DUT (
        .clk(clk),
        .n_rst(n_rst),
        .n_clk(n_clk),
        .start(dq_oe),
        .pool_wdata(pool_wdata),
        .burst_size(burst_size),
        .strobe(),
        .byte_out()
    );

    task write_single;
        input logic [1:0] size;
        input logic [63:0] data;
        integer i;
    begin
        @(posedge clk);
        pool_wdata = data;
        burst_size = size;
        dq_oe = 1;
        @(posedge clk);
        @(negedge clk);
        dq_oe = 0;
        for (i = 0; i < size; i++) begin
            @(posedge clk);
        end
        @(posedge clk);
        @(posedge clk);
    end
    endtask

    task write_burst;
        input logic [1:0] size;
        input logic [3:0] burst_num;
        input logic [7:0][63:0] data;
        integer i;
    begin
        @(posedge clk);
        burst_size = size;
        pool_wdata = data[0];
        dq_oe = 1;
        @(posedge clk);
        @(negedge clk);
        dq_oe = 0;
        for (i = 0; i < burst_num; i++) begin
            if (i != 0) begin
                pool_wdata = data[i];
                dq_oe = 1;
                @(posedge clk);
                @(negedge clk);
                dq_oe = 0;
            end
            if (size == 2'b10) begin
                @(posedge clk);
            end else if (size == 2'b11) begin
                @(posedge clk);
                @(posedge clk);
                @(posedge clk);
            end
        end
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
        n_rst = 1;
        dq_oe = 0;
        pool_wdata = 0;
        burst_size = 0;

        reset_dut;

        // TEST SINGLE WRITES
        write_single(.size(0), .data(64'h5a));
        write_single(.size(1), .data(64'he4f9));
        write_single(.size(2), .data(64'h485f8108));
        write_single(.size(3), .data(64'h44a874a4de89076b));

        // TEST BURST WRITES
        write_burst(.size(0), .burst_num(2), .data({384'b0, 64'h3a, 64'h30}));
        wait_clk(.num(5));
        write_burst(.size(1), .burst_num(4), .data({256'b0, 64'hc806, 64'h5d22, 64'hfc0d, 64'he40b}));
        wait_clk(.num(5));
        write_burst(.size(2), .burst_num(6), .data({128'b0,
                                                    64'h62433d2d,
                                                    64'h7929774c,
                                                    64'h53802527,
                                                    64'h11228b86,
                                                    64'ha734ac38,
                                                    64'h0aa01e5d
        }));
        wait_clk(.num(5));
        write_burst(.size(3), .burst_num(8), .data({64'h156879d226c47ba6,
                                                    64'h1532761b834eff0e, 
                                                    64'h7949c4692141cf7a, 
                                                    64'h5c252f2dfbfbff76, 
                                                    64'h6d58e14093cbc705, 
                                                    64'hb487d6ca8dfabff8, 
                                                    64'h9243177a58360ce5, 
                                                    64'he7bc65a255ec7d4b
        }));
        wait_clk(.num(5));

        $finish;
    end
endmodule

/* verilator coverage_on */

