`timescale 1ns / 10ps

module maintenance_command_queue #(
) (
    input logic clk, n_rst,

    // interface with command scheduler
    input logic cmd_issued,
    output logic issue_cmd
);
    localparam MAX_COUNT = 640000;

    // interface with flex counter
    logic count_enable;
    logic rollover_flag;
    logic [19:0] rollover_val;

    assign rollover_val = MAX_COUNT;

    single_edge_counter #(.SIZE(20)) mcq_sec (
        .clk(clk), .n_rst(n_rst),
        
        .clear(cmd_issued),
        .rollover_val(rollover_val),
        .count_enable(count_enable),
        .rollover_flag(rollover_flag),
        /* verilator lint_off PINCONNECTEMPTY */
        .count_out()
        /* verilator lint_on PINCONNECTEMPTY */
    );

    enum bit [1:0] {
        IDLE,
        REFRESH_ALL
    } state, next_state;

    always_ff @(posedge clk, negedge n_rst) begin
        if (~n_rst) state <= IDLE;
        else        state <= next_state;
    end

    always_comb begin
        case (state)
            IDLE: begin
                count_enable                    = 1;
                issue_cmd                       = 0;
                next_state = rollover_flag ?    REFRESH_ALL : IDLE;
            end REFRESH_ALL: begin
                count_enable                    = 0;
                issue_cmd                       = 1;
                next_state = cmd_issued ?       IDLE : REFRESH_ALL;
            end default: begin
                count_enable                    = 0;
                issue_cmd                       = 0;
                next_state =                    IDLE;
            end
        endcase
    end

endmodule
