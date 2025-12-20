`timescale 1ns / 10ps

module rid_scheduler (
    input logic clk, n_rst,
    input logic scheduler_en,
    input logic [127:0] rid_addresses,
    input logic [3:0] rid_present,
    input logic [3:0] active_transactions,
    input logic [1:0] oldest_rid,
    output logic rid0_en, rid1_en, rid2_en, rid3_en,
    output logic [1:0] chosen_rid,
    output logic [31:0] selected_addr,
    output logic rstrobe
);

logic [1:0] next_chosen_rid;
logic [31:0] next_selected_addr;
logic next_rstrobe;
logic [31:0] rid0_addr, rid1_addr, rid2_addr, rid3_addr;
logic next_rid0_en, next_rid1_en, next_rid2_en, next_rid3_en;

logic [3:0] rid_active;

assign rid_active = rid_present & (~active_transactions);

always_ff @(posedge clk, negedge n_rst) begin
    if(~n_rst) begin
        chosen_rid <= 2'b0;
        selected_addr <= 32'b0;
        rstrobe <= 1'b0;
        rid0_en <= 0;
        rid1_en <= 0;
        rid2_en <= 0;
        rid3_en <= 0;
    end
    else begin
        chosen_rid <= next_chosen_rid;
        selected_addr <= next_selected_addr;
        rstrobe <= next_rstrobe;
        rid0_en <= next_rid0_en;
        rid1_en <= next_rid1_en;
        rid2_en <= next_rid2_en;
        rid3_en <= next_rid3_en;
    end
end

always_comb begin
    next_chosen_rid = chosen_rid;
    next_selected_addr = selected_addr;
    next_rstrobe = 1'b0;
    rid0_addr = rid_addresses[31:0];
    rid1_addr = rid_addresses[63:32];
    rid2_addr = rid_addresses[95:64];
    rid3_addr = rid_addresses[127:96];
    next_rid0_en = 1'b0;
    next_rid1_en = 1'b0;
    next_rid2_en = 1'b0;
    next_rid3_en = 1'b0;

        //we need to check if either its same bank/row or same row. [7:0] -> [7:3] row[7:5] bank [4:3] column [7:5]
    if(scheduler_en) begin
        case(rid_active)
            4'b0001: begin
                next_selected_addr = rid0_addr;
                next_chosen_rid = 2'b0;
                next_rstrobe = 1'b1;
            end
            4'b0010: begin
                next_selected_addr = rid1_addr;
                next_chosen_rid = 2'b1;
                next_rstrobe = 1'b1;
            end
            4'b0011: begin
                if(rid0_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'b0;
                end
                else if(rid1_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'b1;
                end
                else if(rid0_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'b0;
                end
                else if(rid1_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'b1;
                end
                else if(oldest_rid == 2'b0) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'b0;
                end
                else begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'b1;
                end
                next_rstrobe = 1'b1;
            end
            4'b0100: begin
                next_selected_addr = rid2_addr;
                next_chosen_rid = 2'd2;
                next_rstrobe = 1'b1;
            end
            4'b0101: begin
                if(rid0_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else if(rid2_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else if(rid0_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else if(rid2_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else if(oldest_rid == 2'd0) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                next_rstrobe = 1'b1;
            end
            4'b0110: begin
                if(rid1_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else if(rid2_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else if(rid1_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else if(rid2_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else if(oldest_rid == 2'd1) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                next_rstrobe = 1'b1;
            end
            4'b0111: begin
                if(rid0_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else if(rid1_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else if(rid2_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else if(rid0_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else if(rid1_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else if(rid2_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else if(oldest_rid == 2'd0) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else if(oldest_rid == 2'd1) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                next_rstrobe = 1'b1;
            end
            4'b1000: begin
                next_selected_addr = rid3_addr;
                next_chosen_rid = 2'd3;
                next_rstrobe = 1'b1;
            end
            4'b1001: begin
                if(rid0_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else if(rid3_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                else if(rid0_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else if(rid3_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                else if(oldest_rid == 2'd0) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                next_rstrobe = 1'b1;
            end
            4'b1010: begin
                if(rid1_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else if(rid3_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                else if(rid1_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else if(rid3_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                else if(oldest_rid == 2'd1) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                next_rstrobe = 1'b1;
            end
            4'b1011: begin
                if(rid0_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else if(rid1_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else if(rid3_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                else if(rid0_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else if(rid1_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else if(rid3_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                else if(oldest_rid == 2'd0) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else if(oldest_rid == 2'd1) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                next_rstrobe = 1'b1;
            end
            4'b1100: begin
                if(rid2_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else if(rid3_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                else if(rid2_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else if(rid3_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                else if(oldest_rid == 2'd2) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                next_rstrobe = 1'b1;
            end
            4'b1101: begin
                if(rid0_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else if(rid2_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else if(rid3_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                else if(rid0_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else if(rid2_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else if(rid3_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                else if(oldest_rid == 2'd0) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else if(oldest_rid == 2'd2) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                next_rstrobe = 1'b1;
            end
            4'b1110: begin
                if(rid1_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else if(rid2_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else if(rid3_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                else if(rid1_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else if(rid2_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else if(rid3_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                else if(oldest_rid == 2'd1) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else if(oldest_rid == 2'd2) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                next_rstrobe = 1'b1;
            end
            4'b1111: begin
                if(rid0_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else if(rid1_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else if(rid2_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else if(rid3_addr[7:3] == selected_addr[7:3]) begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                else if(rid0_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else if(rid1_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else if(rid2_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else if(rid3_addr[7:5] == selected_addr[7:5]) begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                else if(oldest_rid == 2'd0) begin
                    next_selected_addr = rid0_addr;
                    next_chosen_rid = 2'd0;
                end
                else if(oldest_rid == 2'd1) begin
                    next_selected_addr = rid1_addr;
                    next_chosen_rid = 2'd1;
                end
                else if(oldest_rid == 2'd2) begin
                    next_selected_addr = rid2_addr;
                    next_chosen_rid = 2'd2;
                end
                else begin
                    next_selected_addr = rid3_addr;
                    next_chosen_rid = 2'd3;
                end
                next_rstrobe = 1'b1;
            end
            4'b0000: begin
                next_selected_addr = selected_addr;
                next_chosen_rid = chosen_rid;
                next_rstrobe = 1'b0;
            end
        endcase
        case(next_chosen_rid)
            2'd0: 
                next_rid0_en = next_rstrobe;
            2'd1: 
                next_rid1_en = next_rstrobe;
            2'd2:
                next_rid2_en = next_rstrobe;
            2'd3:
                next_rid3_en = next_rstrobe;
        endcase
    end
end



endmodule

