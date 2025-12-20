`timescale 1ns / 10ps

module rid_fifo #(
    DEPTH = 8
) (
    input logic clk, n_rst,
    input logic pop,
    input logic load,
    input logic [1:0] arid,
    input logic [1:0] current_rid,
    input logic [1:0] popped_rid,
    output logic [3:0] rid_present,
    output logic [11:0] rid_indexes,
    output logic [1:0] oldest_rid,
    output logic [3:0] num_transactions
);

logic [DEPTH-1:0][1:0] data, next_data;
logic [3:0] next_num_transactions;
logic [2:0] popped_rid_index;
logic [2:0] rid0_i, rid1_i, rid2_i, rid3_i; // individual rid indexes



always_ff @(posedge clk, negedge n_rst) begin
    if(~n_rst) begin
        data <= 0;
        num_transactions <= 0;
    end
    else begin
        data <= next_data;
        num_transactions <= next_num_transactions;
    end
end

always_comb begin
    //logic to determine outputs + 
    rid_present = 4'b0;
    popped_rid_index = 0;
    {rid0_i, rid1_i, rid2_i, rid3_i} = 12'b0;
    next_num_transactions = num_transactions;

    if(num_transactions != 0) begin
        oldest_rid = data[num_transactions - 4'b1];
    end
    else oldest_rid = 2'd0;

    for(logic [3:0] i = 4'b0; i < DEPTH; i = i + 4'b1) begin
        if(i < num_transactions) begin
            if(data[i] == popped_rid) begin
                popped_rid_index = i[2:0];
            end
            case(data[i]) 
                2'd0: begin
                    rid0_i = i[2:0];
                    rid_present[0] = 1'b1;
                end
                2'd1: begin
                    rid1_i = i[2:0];
                    rid_present[1] = 1'b1;
                end
                2'd2: begin
                    rid2_i = i[2:0];
                    rid_present[2] = 1'b1;
                end
                2'd3: begin
                    rid3_i = i[2:0];
                    rid_present[3] = 1'b1;
                end
            endcase    
        end
    end
    rid_indexes = {rid3_i, rid2_i, rid1_i, rid0_i};

    //now, time to do load and pop
    next_data = data;
    //if load, put in the stored data into the back
    if(load) begin
        next_data[DEPTH-1:1] = data[DEPTH-2:0];
        next_data[0] = arid;
        next_num_transactions = num_transactions + 4'b1;
    end
    // if pop, remove the data at the selected index. 
    if(pop) begin
        for(logic[3:0] i = 4'b0; i < DEPTH; i = i + 4'b1) begin : pop_loop
            //check if index is less than current rid
            if(i < DEPTH-4'b1) begin
                next_data[i] = i >= {1'b0, popped_rid_index} ? data[i + 4'b1] : data[i];
            end
            else begin
                next_data[i] = 0;
            end
            //next_stored_data[i] = stored_data[i];
        end
        next_num_transactions = num_transactions - 4'b1;
    end
end





endmodule

