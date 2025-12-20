`timescale 1ns / 10ps

module write_data_register(
    input logic clk, n_rst,
    input logic [63:0] WDATA,
    input logic write_enable,
    input logic [7:0] WSTRB,
    input logic WLAST,
    input logic [2:0] burst_size,
    input logic pop,
    output logic wstrobe,
    output logic [63:0] wdata
);

logic [63:0] next_wdata;
logic next_wstrobe;
logic [9:0] count, next_count;
logic [7:0][7:0] data_packet;

assign data_packet[0] = WSTRB[0] ? WDATA[7:0] : 8'b0;
assign data_packet[1] = WSTRB[1] ? WDATA[15:8] : 8'b0;
assign data_packet[2] = WSTRB[2] ? WDATA[23:16] : 8'b0;
assign data_packet[3] = WSTRB[3] ? WDATA[31:24] : 8'b0;
assign data_packet[4] = WSTRB[4] ? WDATA[39:32] : 8'b0;
assign data_packet[5] = WSTRB[5] ? WDATA[47:40] : 8'b0;
assign data_packet[6] = WSTRB[6] ? WDATA[55:48] : 8'b0;
assign data_packet[7] = WSTRB[7] ? WDATA[63:56] : 8'b0;



always_ff @(posedge clk, negedge n_rst) begin
    if(~n_rst) begin
        wdata <= 0;
        wstrobe <= 0;
        count <= 0;
    end
    else begin
        wdata <= next_wdata;
        wstrobe <= next_wstrobe;
        count <= next_count;
    end
end

always_comb begin
    next_wdata = wdata;
    next_wstrobe = 1'b0;
    next_count = count;
    if(write_enable) begin
        case(burst_size)
            3'd0: begin
                next_wdata = {56'b0, data_packet[count[2:0]]};
                next_count = WLAST ? 0 : count + 1;
            end 
            3'd1: begin
                next_wdata = {48'b0, data_packet[count[2:0]+1], data_packet[count[2:0]]};
                next_count = WLAST ? 0 : count + 2;
            end
            3'd2: begin
                next_wdata = {32'b0, data_packet[count[2:0]+3], data_packet[count[2:0]+2], data_packet[count[2:0]+1], data_packet[count[2:0]]};
                next_count = WLAST ? 0 : count + 4;
            end
            3'd3: begin
                next_wdata = {data_packet[7], data_packet[6], data_packet[5], data_packet[4], data_packet[3], data_packet[2], data_packet[1], data_packet[0]};
                next_count = WLAST ? 0 : count;
            end
        endcase
        next_wstrobe = WSTRB[0]|WSTRB[1]|WSTRB[2]|WSTRB[3]|WSTRB[4]|WSTRB[5]|WSTRB[6]|WSTRB[7];
    end
end


endmodule

