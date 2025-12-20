`timescale 1ns / 10ps

module read_response_buffer (
    input logic clk, n_rst,
    input logic [3:0] rerr,
    input logic rvalid,
    input logic RREADY,
    input logic transaction_sent,
    input logic [1:0] rid_out,
    input logic [1:0] chosen_rid,
    input logic [31:0] burst_lengths, 
    input logic [11:0] burst_sizes, 
    input logic [63:0] data_in,
    output logic [1:0] RRESP,
    output logic [63:0] RDATA,
    output logic [1:0] RID,
    output logic ren,
    output logic rid0_done, rid1_done, rid2_done, rid3_done,
    output logic RLAST,
    output logic RVALID,
    output logic [1:0] popped_rid
);

typedef enum logic[3:0] {IDLE, LOAD_TRANS_VAL, WAIT, RECIEVE_DATA_1, RECIEVE_DATA_2, RECIEVE_DATA_4, RECIEVE_DATA_8, DATA_SENT, RECIEVE_DATA_LAST_1, RECIEVE_DATA_LAST_2, RECIEVE_DATA_LAST_4, RECIEVE_DATA_LAST_8, DATA_SENT_LAST, ERROR} state_t;

state_t rid0_state, next_rid0_state, rid1_state, next_rid1_state, rid2_state, next_rid2_state, rid3_state, next_rid3_state;
logic [7:0] rid0_count, rid1_count, rid2_count, rid3_count, next_rid0_count, next_rid1_count, next_rid2_count, next_rid3_count;
logic [63:0] next_RDATA;
logic next_RLAST, next_RVALID, next_ren, next_rid0_done, next_rid1_done, next_rid2_done, next_rid3_done;
logic [7:0] rollover_val_0, rollover_val_1, rollover_val_2, rollover_val_3, next_rollover_val_0, next_rollover_val_1, next_rollover_val_2, next_rollover_val_3;
logic [2:0] burst_size_0, burst_size_1, burst_size_2, burst_size_3, next_burst_size_0, next_burst_size_1, next_burst_size_2, next_burst_size_3;
logic [1:0] next_RID, next_RRESP, next_popped_rid;

always_ff @(posedge clk, negedge n_rst) begin
    if(~n_rst) begin
        rid0_count <= 0;
        rid1_count <= 0;
        rid2_count <= 0;
        rid3_count <= 0;
        RDATA <= 0;
        RLAST <= 0;
        RVALID <= 0;
        {rollover_val_0, rollover_val_1, rollover_val_2, rollover_val_3} <= 0;
        {burst_size_0, burst_size_1, burst_size_2, burst_size_3} <= 0;
        RRESP <= 0;
        {rid0_state, rid1_state, rid2_state, rid3_state} <= {IDLE, IDLE, IDLE, IDLE};
        ren <= 0;
        RID <= 0;
        rid0_done <= 0;
        rid1_done <= 0;
        rid2_done <= 0;
        rid3_done <= 0;
        popped_rid <= 0;
    end
    else begin
        rid0_count <= next_rid0_count;
        rid1_count <= next_rid1_count;
        rid2_count <= next_rid2_count;
        rid3_count <= next_rid3_count;
        RDATA <= next_RDATA;
        RLAST <= next_RLAST;
        RVALID <= next_RVALID;
        {rollover_val_0, rollover_val_1, rollover_val_2, rollover_val_3} <= {next_rollover_val_0, next_rollover_val_1, next_rollover_val_2, next_rollover_val_3};
        {burst_size_0, burst_size_1, burst_size_2, burst_size_3} <= {next_burst_size_0, next_burst_size_1, next_burst_size_2, next_burst_size_3};
        {rid0_state, rid1_state, rid2_state, rid3_state} <= {next_rid0_state, next_rid1_state, next_rid2_state, next_rid3_state};
        RRESP <= next_RRESP;
        ren <= next_ren;
        RID <= next_RID;
        rid0_done <= next_rid0_done;
        rid1_done <= next_rid1_done;
        rid2_done <= next_rid2_done;
        rid3_done <= next_rid3_done;
        popped_rid <= next_popped_rid;
    end
end



always_comb begin
    next_rid0_done = 0;
    next_rid1_done = 0;
    next_rid2_done = 0;
    next_rid3_done = 0;
    next_ren = ren;
    next_rid0_state = rid0_state;
    next_rid1_state = rid1_state;
    next_rid2_state = rid2_state;
    next_rid3_state = rid3_state;
    next_rollover_val_0 = rollover_val_0;
    next_rollover_val_1 = rollover_val_1;
    next_rollover_val_2 = rollover_val_2;
    next_rollover_val_3 = rollover_val_3;
    next_burst_size_0 = burst_size_0;
    next_burst_size_1 = burst_size_1;
    next_burst_size_2 = burst_size_2;
    next_burst_size_3 = burst_size_3;
    next_rid0_count = rid0_count;
    next_rid1_count = rid1_count;
    next_rid2_count = rid2_count;
    next_rid3_count = rid3_count;
    next_RVALID = RVALID;
    next_RID = RID;
    next_RDATA = RDATA;
    next_RLAST = RLAST;
    next_RRESP = RRESP;
    next_popped_rid = popped_rid;
    unique case(rid0_state)
        IDLE: begin
            if(transaction_sent && (chosen_rid == 2'd0)) begin
                next_rid0_state = LOAD_TRANS_VAL;
            end
        end
        LOAD_TRANS_VAL: begin
            next_rollover_val_0 = burst_lengths[7:0];
            next_burst_size_0 = burst_sizes[2:0];
            next_rid0_state = WAIT;
            next_ren = 1'b1;
        end
        WAIT: begin
            if(rvalid && (rid_out == 2'd0)) begin
                next_RDATA = data_in;
                next_RID = 2'd0;
                next_ren = 1'b0;
                next_RVALID = 1'b0;
                next_RRESP = rerr[0] ? 2'd2 : 0;
                if(rid0_count < rollover_val_0) next_rid0_state = burst_size_0 == 0 ? RECIEVE_DATA_1 : (burst_size_0 == 1) ? RECIEVE_DATA_2 : (burst_size_0 == 2) ? RECIEVE_DATA_4 : burst_size_0 == 3 ? RECIEVE_DATA_8 : ERROR;
                else next_rid0_state = burst_size_0 == 0 ? RECIEVE_DATA_LAST_1 : (burst_size_0 == 1) ? RECIEVE_DATA_LAST_2 : (burst_size_0 == 2) ? RECIEVE_DATA_LAST_4 : burst_size_0 == 3 ? RECIEVE_DATA_LAST_8 : ERROR;
            end
        end
        RECIEVE_DATA_1: begin
            if(rid0_count[2:0] == 0) begin
                next_RDATA = {56'b0, RDATA[7:0]};
            end
            else if(rid0_count[2:0] == 1) begin
                next_RDATA = {48'b0, RDATA[7:0], 8'b0};
            end
            else if(rid0_count[2:0] == 2) begin
                next_RDATA = {40'b0, RDATA[7:0], 16'b0};
            end
            else if(rid0_count[2:0] == 3) begin
                next_RDATA = {32'b0, RDATA[7:0], 24'b0};
            end
            else if(rid0_count[2:0] == 4) begin
                next_RDATA = {24'b0, RDATA[7:0], 32'b0};
            end
            else if(rid0_count[2:0] == 5) begin
                next_RDATA = {16'b0, RDATA[7:0], 40'b0};
            end
            else if(rid0_count[2:0] == 6) begin
                next_RDATA = {8'b0, RDATA[7:0], 48'b0};
            end
            else if(rid0_count[2:0] == 7) begin
                next_RDATA = {RDATA[7:0], 56'b0};
            end
            next_RVALID = 1'b1;
            next_rid0_state = DATA_SENT;
        end
        RECIEVE_DATA_LAST_1: begin
            if(rid0_count[2:0] == 0) begin
                next_RDATA = {56'b0, RDATA[7:0]};
            end
            else if(rid0_count[2:0] == 1) begin
                next_RDATA = {48'b0, RDATA[7:0], 8'b0};
            end
            else if(rid0_count[2:0] == 2) begin
                next_RDATA = {40'b0, RDATA[7:0], 16'b0};
            end
            else if(rid0_count[2:0] == 3) begin
                next_RDATA = {32'b0, RDATA[7:0], 24'b0};
            end
            else if(rid0_count[2:0] == 4) begin
                next_RDATA = {24'b0, RDATA[7:0], 32'b0};
            end
            else if(rid0_count[2:0] == 5) begin
                next_RDATA = {16'b0, RDATA[7:0], 40'b0};
            end
            else if(rid0_count[2:0] == 6) begin
                next_RDATA = {8'b0, RDATA[7:0], 48'b0};
            end
            else if(rid0_count[2:0] == 7) begin
                next_RDATA = {RDATA[7:0], 56'b0};
            end
            next_RVALID = 1'b1;
            next_RLAST = 1'b1;
            next_rid0_state = DATA_SENT_LAST;
        end
        RECIEVE_DATA_2: begin
            if(rid0_count[1:0] == 0) begin
                next_RDATA = {48'b0, RDATA[15:0]};
            end
            else if(rid0_count[1:0] == 1) begin
                next_RDATA = {32'b0, RDATA[15:0], 16'b0};
            end
            else if(rid0_count[1:0] == 2) begin
                next_RDATA = {16'b0, RDATA[15:0], 32'b0};
            end
            else if(rid0_count[1:0] == 3) begin
                next_RDATA = {RDATA[15:0], 48'b0};
            end
            next_RVALID = 1'b1;
            next_rid0_state = DATA_SENT;
        end
        RECIEVE_DATA_LAST_2: begin
            if(rid0_count[1:0] == 0) begin
                next_RDATA = {48'b0, RDATA[15:0]};
            end
            else if(rid0_count[1:0] == 1) begin
                next_RDATA = {32'b0, RDATA[15:0], 16'b0};
            end
            else if(rid0_count[1:0] == 2) begin
                next_RDATA = {16'b0, RDATA[15:0], 32'b0};
            end
            else if(rid0_count[1:0] == 3) begin
                next_RDATA = {RDATA[15:0], 48'b0};
            end
            next_RVALID = 1'b1;
            next_RLAST = 1'b1;
            next_rid0_state = DATA_SENT_LAST;
        end
        RECIEVE_DATA_4: begin
            if(rid0_count[0] == 0) begin
                next_RDATA = {32'b0, RDATA[31:0]};
            end
            else if(rid0_count[0] == 1) begin
                next_RDATA = {RDATA[31:0], 32'b0};
            end
            next_RVALID = 1'b1;
            next_rid0_state = DATA_SENT;
        end
        RECIEVE_DATA_LAST_4: begin
            if(rid0_count[0] == 0) begin
                next_RDATA = {32'b0, RDATA[31:0]};
            end
            else if(rid0_count[0] == 1) begin
                next_RDATA = {RDATA[31:0], 32'b0};
            end
            next_RVALID = 1'b1;
            next_RLAST = 1'b1;
            next_rid0_state = DATA_SENT_LAST;
        end
        RECIEVE_DATA_8: begin
            next_RVALID = 1'b1;
            next_rid0_state = DATA_SENT;
        end
        RECIEVE_DATA_LAST_8: begin
            next_rid0_state = DATA_SENT_LAST;
            next_RLAST = 1'b1;
            next_RVALID = 1'b1;
        end
        DATA_SENT: begin
            if(RREADY) begin
                next_RVALID = 1'b0;
                next_rid0_count = rid0_count + 1;
                next_rid0_state = WAIT;
                next_ren = 1'b1;
            end
        end
        DATA_SENT_LAST: begin
            if(RREADY) begin
                next_RVALID = 1'b0;
                next_RLAST = 1'b0;
                next_rid0_state = IDLE;
                next_rid0_count = 0;
                next_rid0_done = 1'b1;
                next_popped_rid = 2'd0;
                next_ren = 1'b1;
            end
        end
        ERROR: begin
            next_rid0_state = IDLE;
            next_RRESP = 2'd2;
        end
        default:
            next_rid0_state = IDLE;
    endcase
    unique case(rid1_state)
        IDLE: begin
            if(transaction_sent && (chosen_rid == 2'd1)) begin
                next_rid1_state = LOAD_TRANS_VAL;
            end
        end
        LOAD_TRANS_VAL: begin
            next_rollover_val_1 = burst_lengths[15:8];
            next_burst_size_1 = burst_sizes[5:3];
            next_rid1_state = WAIT;
            next_ren = 1'b1;
        end
        WAIT: begin
            if(rvalid && (rid_out == 2'd1)) begin
                next_RDATA = data_in;
                next_RID = 2'd1;
                next_ren = 1'b0;
                next_RVALID = 1'b0;
                next_RRESP = rerr[1] ? 2'd2 : 0;
                if(rid1_count < rollover_val_1) next_rid1_state = burst_size_1 == 0 ? RECIEVE_DATA_1 : (burst_size_1 == 1) ? RECIEVE_DATA_2 : (burst_size_1 == 2) ? RECIEVE_DATA_4 : burst_size_1 == 3 ? RECIEVE_DATA_8 : ERROR;
                else next_rid1_state = burst_size_1 == 0 ? RECIEVE_DATA_LAST_1 : (burst_size_1 == 1) ? RECIEVE_DATA_LAST_2 : (burst_size_1 == 2) ? RECIEVE_DATA_LAST_4 : burst_size_1 == 3 ? RECIEVE_DATA_LAST_8 : ERROR;
            end
        end
        RECIEVE_DATA_1: begin
            if(rid1_count[2:0] == 0) begin
                next_RDATA = {56'b0, RDATA[7:0]};
            end
            else if(rid1_count[2:0] == 1) begin
                next_RDATA = {48'b0, RDATA[7:0], 8'b0};
            end
            else if(rid1_count[2:0] == 2) begin
                next_RDATA = {40'b0, RDATA[7:0], 16'b0};
            end
            else if(rid1_count[2:0] == 3) begin
                next_RDATA = {32'b0, RDATA[7:0], 24'b0};
            end
            else if(rid1_count[2:0] == 4) begin
                next_RDATA = {24'b0, RDATA[7:0], 32'b0};
            end
            else if(rid1_count[2:0] == 5) begin
                next_RDATA = {16'b0, RDATA[7:0], 40'b0};
            end
            else if(rid1_count[2:0] == 6) begin
                next_RDATA = {8'b0, RDATA[7:0], 48'b0};
            end
            else if(rid1_count[2:0] == 7) begin
                next_RDATA = {RDATA[7:0], 56'b0};
            end
            next_RVALID = 1'b1;
            next_rid1_state = DATA_SENT;
        end
        RECIEVE_DATA_LAST_1: begin
            if(rid1_count[2:0] == 0) begin
                next_RDATA = {56'b0, RDATA[7:0]};
            end
            else if(rid1_count[2:0] == 1) begin
                next_RDATA = {48'b0, RDATA[7:0], 8'b0};
            end
            else if(rid1_count[2:0] == 2) begin
                next_RDATA = {40'b0, RDATA[7:0], 16'b0};
            end
            else if(rid1_count[2:0] == 3) begin
                next_RDATA = {32'b0, RDATA[7:0], 24'b0};
            end
            else if(rid1_count[2:0] == 4) begin
                next_RDATA = {24'b0, RDATA[7:0], 32'b0};
            end
            else if(rid1_count[2:0] == 5) begin
                next_RDATA = {16'b0, RDATA[7:0], 40'b0};
            end
            else if(rid1_count[2:0] == 6) begin
                next_RDATA = {8'b0, RDATA[7:0], 48'b0};
            end
            else if(rid1_count[2:0] == 7) begin
                next_RDATA = {RDATA[7:0], 56'b0};
            end
            next_RVALID = 1'b1;
            next_RLAST = 1'b1;
            next_rid1_state = DATA_SENT_LAST;
        end
        RECIEVE_DATA_2: begin
            if(rid1_count[1:0] == 0) begin
                next_RDATA = {48'b0, RDATA[15:0]};
            end
            else if(rid1_count[1:0] == 1) begin
                next_RDATA = {32'b0, RDATA[15:0], 16'b0};
            end
            else if(rid1_count[1:0] == 2) begin
                next_RDATA = {16'b0, RDATA[15:0], 32'b0};
            end
            else if(rid1_count[1:0] == 3) begin
                next_RDATA = {RDATA[15:0], 48'b0};
            end
            next_RVALID = 1'b1;
            next_rid1_state = DATA_SENT;
        end
        RECIEVE_DATA_LAST_2: begin
            if(rid1_count[1:0] == 0) begin
                next_RDATA = {48'b0, RDATA[15:0]};
            end
            else if(rid1_count[1:0] == 1) begin
                next_RDATA = {32'b0, RDATA[15:0], 16'b0};
            end
            else if(rid1_count[1:0] == 2) begin
                next_RDATA = {16'b0, RDATA[15:0], 32'b0};
            end
            else if(rid1_count[1:0] == 3) begin
                next_RDATA = {RDATA[15:0], 48'b0};
            end
            next_RVALID = 1'b1;
            next_RLAST = 1'b1;
            next_rid1_state = DATA_SENT_LAST;
        end
        RECIEVE_DATA_4: begin
            if(rid1_count[0] == 0) begin
                next_RDATA = {32'b0, RDATA[31:0]};
            end
            else if(rid1_count[0] == 1) begin
                next_RDATA = {RDATA[31:0], 32'b0};
            end
            next_RVALID = 1'b1;
            next_rid1_state = DATA_SENT;
        end
        RECIEVE_DATA_LAST_4: begin
            if(rid1_count[0] == 0) begin
                next_RDATA = {32'b0, RDATA[31:0]};
            end
            else if(rid1_count[0] == 1) begin
                next_RDATA = {RDATA[31:0], 32'b0};
            end
            next_RVALID = 1'b1;
            next_RLAST = 1'b1;
            next_rid1_state = DATA_SENT_LAST;
        end
        RECIEVE_DATA_8: begin
            next_RVALID = 1'b1;
            next_rid1_state = DATA_SENT;
        end
        RECIEVE_DATA_LAST_8: begin
            next_rid1_state = DATA_SENT_LAST;
            next_RLAST = 1'b1;
            next_RVALID = 1'b1;
        end
        DATA_SENT: begin
            if(RREADY) begin
                next_RVALID = 1'b0;
                next_rid1_count = rid1_count + 1;
                next_rid1_state = WAIT;
                next_ren = 1'b1;
            end
        end
        DATA_SENT_LAST: begin
            if(RREADY) begin
                next_RVALID = 1'b0;
                next_RLAST = 1'b0;
                next_rid1_state = IDLE;
                next_rid1_count = 0;
                next_rid1_done = 1;
                next_popped_rid = 2'd1;
                next_ren = 1'b1;
            end
        end
        ERROR: begin
            next_rid1_state = IDLE;
            next_RRESP = 2'd2;
        end
        default:
            next_rid1_state = IDLE;
    endcase
    unique case(rid2_state)
        IDLE: begin
            if(transaction_sent && (chosen_rid == 2'd2)) begin
                next_rid2_state = LOAD_TRANS_VAL;
            end
        end
        LOAD_TRANS_VAL: begin
            next_rollover_val_2 = burst_lengths[23:16];
            next_burst_size_2 = burst_sizes[8:6];
            next_rid2_state = WAIT;
            next_ren = 1'b1;
        end
        WAIT: begin
            if(rvalid && (rid_out == 2'd2)) begin
                next_RDATA = data_in;
                next_RID = 2'd2;
                next_ren = 1'b0;
                next_RVALID = 1'b0;
                next_RRESP = rerr[2] ? 2'd2 : 0;
                if(rid2_count < rollover_val_2) next_rid2_state = burst_size_2 == 0 ? RECIEVE_DATA_1 : (burst_size_2 == 1) ? RECIEVE_DATA_2 : (burst_size_2 == 2) ? RECIEVE_DATA_4 : burst_size_2 == 3 ? RECIEVE_DATA_8 : ERROR;
                else next_rid2_state = burst_size_2 == 0 ? RECIEVE_DATA_LAST_1 : (burst_size_2 == 1) ? RECIEVE_DATA_LAST_2 : (burst_size_2 == 2) ? RECIEVE_DATA_LAST_4 : burst_size_2 == 3 ? RECIEVE_DATA_LAST_8 : ERROR;
            end
        end
        RECIEVE_DATA_1: begin
            if(rid2_count[2:0] == 0) begin
                next_RDATA = {56'b0, RDATA[7:0]};
            end
            else if(rid2_count[2:0] == 1) begin
                next_RDATA = {48'b0, RDATA[7:0], 8'b0};
            end
            else if(rid2_count[2:0] == 2) begin
                next_RDATA = {40'b0, RDATA[7:0], 16'b0};
            end
            else if(rid2_count[2:0] == 3) begin
                next_RDATA = {32'b0, RDATA[7:0], 24'b0};
            end
            else if(rid2_count[2:0] == 4) begin
                next_RDATA = {24'b0, RDATA[7:0], 32'b0};
            end
            else if(rid2_count[2:0] == 5) begin
                next_RDATA = {16'b0, RDATA[7:0], 40'b0};
            end
            else if(rid2_count[2:0] == 6) begin
                next_RDATA = {8'b0, RDATA[7:0], 48'b0};
            end
            else if(rid2_count[2:0] == 7) begin
                next_RDATA = {RDATA[7:0], 56'b0};
            end
            next_RVALID = 1'b1;
            next_rid2_state = DATA_SENT;
        end
        RECIEVE_DATA_LAST_1: begin
            if(rid2_count[2:0] == 0) begin
                next_RDATA = {56'b0, RDATA[7:0]};
            end
            else if(rid2_count[2:0] == 1) begin
                next_RDATA = {48'b0, RDATA[7:0], 8'b0};
            end
            else if(rid2_count[2:0] == 2) begin
                next_RDATA = {40'b0, RDATA[7:0], 16'b0};
            end
            else if(rid2_count[2:0] == 3) begin
                next_RDATA = {32'b0, RDATA[7:0], 24'b0};
            end
            else if(rid2_count[2:0] == 4) begin
                next_RDATA = {24'b0, RDATA[7:0], 32'b0};
            end
            else if(rid2_count[2:0] == 5) begin
                next_RDATA = {16'b0, RDATA[7:0], 40'b0};
            end
            else if(rid2_count[2:0] == 6) begin
                next_RDATA = {8'b0, RDATA[7:0], 48'b0};
            end
            else if(rid2_count[2:0] == 7) begin
                next_RDATA = {RDATA[7:0], 56'b0};
            end
            next_RVALID = 1'b1;
            next_RLAST = 1'b1;
            next_rid2_state = DATA_SENT_LAST;
        end
        RECIEVE_DATA_2: begin
            if(rid2_count[1:0] == 0) begin
                next_RDATA = {48'b0, RDATA[15:0]};
            end
            else if(rid2_count[1:0] == 1) begin
                next_RDATA = {32'b0, RDATA[15:0], 16'b0};
            end
            else if(rid2_count[1:0] == 2) begin
                next_RDATA = {16'b0, RDATA[15:0], 32'b0};
            end
            else if(rid2_count[1:0] == 3) begin
                next_RDATA = {RDATA[15:0], 48'b0};
            end
            next_RVALID = 1'b1;
            next_rid2_state = DATA_SENT;
        end
        RECIEVE_DATA_LAST_2: begin
            if(rid2_count[1:0] == 0) begin
                next_RDATA = {48'b0, RDATA[15:0]};
            end
            else if(rid2_count[1:0] == 1) begin
                next_RDATA = {32'b0, RDATA[15:0], 16'b0};
            end
            else if(rid2_count[1:0] == 2) begin
                next_RDATA = {16'b0, RDATA[15:0], 32'b0};
            end
            else if(rid2_count[1:0] == 3) begin
                next_RDATA = {RDATA[15:0], 48'b0};
            end
            next_RVALID = 1'b1;
            next_RLAST = 1'b1;
            next_rid2_state = DATA_SENT_LAST;
        end
        RECIEVE_DATA_4: begin
            if(rid2_count[0] == 0) begin
                next_RDATA = {32'b0, RDATA[31:0]};
            end
            else if(rid2_count[0] == 1) begin
                next_RDATA = {RDATA[31:0], 32'b0};
            end
            next_RVALID = 1'b1;
            next_rid2_state = DATA_SENT;
        end
        RECIEVE_DATA_LAST_4: begin
            if(rid2_count[0] == 0) begin
                next_RDATA = {32'b0, RDATA[31:0]};
            end
            else if(rid2_count[0] == 1) begin
                next_RDATA = {RDATA[31:0], 32'b0};
            end
            next_RVALID = 1'b1;
            next_RLAST = 1'b1;
            next_rid2_state = DATA_SENT_LAST;
        end
        RECIEVE_DATA_8: begin
            next_RVALID = 1'b1;
            next_rid2_state = DATA_SENT;
        end
        RECIEVE_DATA_LAST_8: begin
            next_rid2_state = DATA_SENT_LAST;
            next_RLAST = 1'b1;
            next_RVALID = 1'b1;
        end
        DATA_SENT: begin
            if(RREADY) begin
                next_RVALID = 1'b0;
                next_rid2_count = rid2_count + 1;
                next_rid2_state = WAIT;
                next_ren = 1'b1;
            end
        end
        DATA_SENT_LAST: begin
            if(RREADY) begin
                next_RVALID = 1'b0;
                next_RLAST = 1'b0;
                next_rid2_state = IDLE;
                next_rid2_count = 0;
                next_rid2_done = 1;
                next_popped_rid = 2'd2;
                next_ren = 1'b1;
            end
        end
        ERROR: begin
            next_rid2_state = IDLE;
            next_RRESP = 2'd2;
        end
        default:
            next_rid2_state = IDLE;
    endcase
    unique case(rid3_state)
        IDLE: begin
            if(transaction_sent && (chosen_rid == 2'd3)) begin
                next_rid3_state = LOAD_TRANS_VAL;
            end
        end
        LOAD_TRANS_VAL: begin
            next_rollover_val_3 = burst_lengths[31:24];
            next_burst_size_3 = burst_sizes[11:9];
            next_rid3_state = WAIT;
            next_ren = 1'b1;
        end
        WAIT: begin
            if(rvalid && (rid_out == 2'd3)) begin
                next_RDATA = data_in;
                next_RID = 2'd3;
                next_ren = 1'b0;
                next_RVALID = 1'b0;
                next_RRESP = rerr[3] ? 2'd2 : 0;
                if(rid3_count < rollover_val_3) next_rid3_state = burst_size_3 == 0 ? RECIEVE_DATA_1 : (burst_size_3 == 1) ? RECIEVE_DATA_2 : (burst_size_3 == 2) ? RECIEVE_DATA_4 : burst_size_3 == 3 ? RECIEVE_DATA_8 : ERROR;
                else next_rid3_state = burst_size_3 == 0 ? RECIEVE_DATA_LAST_1 : (burst_size_3 == 1) ? RECIEVE_DATA_LAST_2 : (burst_size_3 == 2) ? RECIEVE_DATA_LAST_4 : burst_size_3 == 3 ? RECIEVE_DATA_LAST_8 : ERROR;
            end
        end
        RECIEVE_DATA_1: begin
            if(rid3_count[2:0] == 0) begin
                next_RDATA = {56'b0, RDATA[7:0]};
            end
            else if(rid3_count[2:0] == 1) begin
                next_RDATA = {48'b0, RDATA[7:0], 8'b0};
            end
            else if(rid3_count[2:0] == 2) begin
                next_RDATA = {40'b0, RDATA[7:0], 16'b0};
            end
            else if(rid3_count[2:0] == 3) begin
                next_RDATA = {32'b0, RDATA[7:0], 24'b0};
            end
            else if(rid3_count[2:0] == 4) begin
                next_RDATA = {24'b0, RDATA[7:0], 32'b0};
            end
            else if(rid3_count[2:0] == 5) begin
                next_RDATA = {16'b0, RDATA[7:0], 40'b0};
            end
            else if(rid3_count[2:0] == 6) begin
                next_RDATA = {8'b0, RDATA[7:0], 48'b0};
            end
            else if(rid3_count[2:0] == 7) begin
                next_RDATA = {RDATA[7:0], 56'b0};
            end
            next_RVALID = 1'b1;
            next_rid3_state = DATA_SENT;
        end
        RECIEVE_DATA_LAST_1: begin
            if(rid3_count[2:0] == 0) begin
                next_RDATA = {56'b0, RDATA[7:0]};
            end
            else if(rid3_count[2:0] == 1) begin
                next_RDATA = {48'b0, RDATA[7:0], 8'b0};
            end
            else if(rid3_count[2:0] == 2) begin
                next_RDATA = {40'b0, RDATA[7:0], 16'b0};
            end
            else if(rid3_count[2:0] == 3) begin
                next_RDATA = {32'b0, RDATA[7:0], 24'b0};
            end
            else if(rid3_count[2:0] == 4) begin
                next_RDATA = {24'b0, RDATA[7:0], 32'b0};
            end
            else if(rid3_count[2:0] == 5) begin
                next_RDATA = {16'b0, RDATA[7:0], 40'b0};
            end
            else if(rid3_count[2:0] == 6) begin
                next_RDATA = {8'b0, RDATA[7:0], 48'b0};
            end
            else if(rid3_count[2:0] == 7) begin
                next_RDATA = {RDATA[7:0], 56'b0};
            end
            next_RVALID = 1'b1;
            next_RLAST = 1'b1;
            next_rid3_state = DATA_SENT_LAST;
        end
        RECIEVE_DATA_2: begin
            if(rid3_count[1:0] == 0) begin
                next_RDATA = {48'b0, RDATA[15:0]};
            end
            else if(rid3_count[1:0] == 1) begin
                next_RDATA = {32'b0, RDATA[15:0], 16'b0};
            end
            else if(rid3_count[1:0] == 2) begin
                next_RDATA = {16'b0, RDATA[15:0], 32'b0};
            end
            else if(rid3_count[1:0] == 3) begin
                next_RDATA = {RDATA[15:0], 48'b0};
            end
            next_RVALID = 1'b1;
            next_rid3_state = DATA_SENT;
        end
        RECIEVE_DATA_LAST_2: begin
            if(rid3_count[1:0] == 0) begin
                next_RDATA = {48'b0, RDATA[15:0]};
            end
            else if(rid3_count[1:0] == 1) begin
                next_RDATA = {32'b0, RDATA[15:0], 16'b0};
            end
            else if(rid3_count[1:0] == 2) begin
                next_RDATA = {16'b0, RDATA[15:0], 32'b0};
            end
            else if(rid3_count[1:0] == 3) begin
                next_RDATA = {RDATA[15:0], 48'b0};
            end
            next_RVALID = 1'b1;
            next_RLAST = 1'b1;
            next_rid3_state = DATA_SENT_LAST;
        end
        RECIEVE_DATA_4: begin
            if(rid3_count[0] == 0) begin
                next_RDATA = {32'b0, RDATA[31:0]};
            end
            else if(rid3_count[0] == 1) begin
                next_RDATA = {RDATA[31:0], 32'b0};
            end
            next_RVALID = 1'b1;
            next_rid3_state = DATA_SENT;
        end
        RECIEVE_DATA_LAST_4: begin
            if(rid3_count[0] == 0) begin
                next_RDATA = {32'b0, RDATA[31:0]};
            end
            else if(rid3_count[0] == 1) begin
                next_RDATA = {RDATA[31:0], 32'b0};
            end
            next_RVALID = 1'b1;
            next_RLAST = 1'b1;
            next_rid3_state = DATA_SENT_LAST;
        end
        RECIEVE_DATA_8: begin
            next_RVALID = 1'b1;
            next_rid3_state = DATA_SENT;
        end
        RECIEVE_DATA_LAST_8: begin
            next_rid3_state = DATA_SENT_LAST;
            next_RLAST = 1'b1;
            next_RVALID = 1'b1;
        end
        DATA_SENT: begin
            if(RREADY) begin
                next_RVALID = 1'b0;
                next_rid3_count = rid3_count + 1;
                next_rid3_state = WAIT;
                next_ren = 1'b1;
            end
        end
        DATA_SENT_LAST: begin
            if(RREADY) begin
                next_RVALID = 1'b0;
                next_RLAST = 1'b0;
                next_rid3_state = IDLE;
                next_rid3_count = 0;
                next_rid3_done = 1;
                next_popped_rid = 2'd3;
                next_ren = 1'b1;
            end
        end
        ERROR: begin
            next_rid3_state = IDLE;
            next_RRESP = 2'd2;
        end
        default:
            next_rid3_state = IDLE;
    endcase
end

endmodule

