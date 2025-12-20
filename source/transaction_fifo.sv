`timescale 1ns / 10ps

module transaction_fifo #(
    parameter DEPTH = 8,
    parameter DATA_SIZE = 32
) (
    input logic clk, n_rst,
    input logic pop,
    input logic load,
    input logic [DATA_SIZE-1:0] data,
    input logic [DATA_SIZE-1:0] update_data,
    input logic update_strobe,
    input logic [3:0] rid_present,
    input logic [11:0] rid_indexes,
    input logic [1:0] current_rid,
    input logic [1:0] popped_rid,
    output logic [(DATA_SIZE*4)-1:0] all_data,
    output logic [DATA_SIZE-1:0] selected_data
);

logic [DEPTH-1:0][DATA_SIZE-1:0] stored_data, next_stored_data; //data that is in fifo
logic [2:0] rid0_i, rid1_i, rid2_i, rid3_i; // individual rid indexes
logic [DATA_SIZE-1:0] rid0_d, rid1_d, rid2_d, rid3_d; //individual rid data
logic [2:0] current_rid_index, popped_rid_index;

assign {rid3_i, rid2_i, rid1_i, rid0_i} = rid_indexes; // extract individual rid_indexes from overall rid.
assign rid0_d = rid_present[0] ? stored_data[rid0_i] : 0;
assign rid1_d = rid_present[1] ? stored_data[rid1_i] : 0;
assign rid2_d = rid_present[2] ? stored_data[rid2_i] : 0;
assign rid3_d = rid_present[3] ? stored_data[rid3_i] : 0;

// flip flops for fifo, structure similar to shift register
always_ff @(posedge clk, negedge n_rst) begin
    //if reset, set everything to zero
    if(~n_rst) begin
        stored_data <= 0;
    end
    else begin
        stored_data <= next_stored_data;
    end
end

always_comb begin
    all_data = {rid3_d, rid2_d, rid1_d, rid0_d};
    //get the index of the current rid for popping purposes. 
    case(current_rid)
        2'd0:
            current_rid_index = rid0_i;
        2'd1: 
            current_rid_index = rid1_i;
        2'd2:
            current_rid_index = rid2_i;
        2'd3:
            current_rid_index = rid3_i;
    endcase
    case(popped_rid)
        2'd0:
            popped_rid_index = rid0_i;
        2'd1:
            popped_rid_index = rid1_i;
        2'd2:
            popped_rid_index = rid2_i;
        2'd3:
            popped_rid_index = rid3_i;
    endcase
    next_stored_data = stored_data;
    selected_data = stored_data[current_rid_index];
    //if load, put in the stored data into the back
    if(load) begin 
        next_stored_data[DEPTH-1:1] = stored_data[DEPTH-2:0];
        next_stored_data[0] = data;
    end
    // if pop, remove the data at the selected index. 
    if(pop) begin 
        for(logic[3:0] i = 4'b0; i < DEPTH; i = i + 4'b1) begin
            //check if index is less than current rid
            if(i < DEPTH-4'b1) begin
                next_stored_data[i] = i >= {1'b0, popped_rid_index} ? stored_data[i + 4'b1] : stored_data[i];
            end
            else begin
                next_stored_data[i] = 0;
            end
            //next_stored_data[i] = stored_data[i];
        end
    end

    if(update_strobe) begin
        if(load)
            next_stored_data[current_rid_index + 1] = update_data;
        else 
            next_stored_data[current_rid_index] = update_data;
        case(current_rid)
            2'd0: begin
                all_data[DATA_SIZE-1:0] = rid_present[0] ? update_data : all_data[DATA_SIZE-1:0]; 
            end
            2'd1: begin
                all_data[(2*DATA_SIZE)-1:DATA_SIZE] = rid_present[1] ? update_data : all_data[(2*DATA_SIZE)-1:DATA_SIZE]; 
            end
            2'd2: begin
                all_data[(3*DATA_SIZE)-1:2*DATA_SIZE] = rid_present[2] ? update_data : all_data[(3*DATA_SIZE)-1:2*DATA_SIZE]; 
            end
            2'd3: begin
                all_data[(4*DATA_SIZE)-1:3*DATA_SIZE] = rid_present[3] ? update_data : all_data[(4*DATA_SIZE)-1:3*DATA_SIZE]; 
            end
        endcase
    end


end





endmodule

