`timescale 1ns / 10ps

module address_increment (
    input logic [31:0] address,
    input logic [2:0] ARSIZE,
    output logic [31:0] new_address,
    output logic err
);

always_comb begin
    err = 0;
    new_address = address;
    case(ARSIZE) 
        3'd0: begin
            new_address = address + 32'd1;
        end
        3'd1: begin
            new_address = address + 32'd2;
        end
        3'd2: begin
            new_address = address + 32'd4;
        end
        3'd3: begin
            new_address = address + 32'd8;
        end
        default: begin
            new_address = address;
            err = 1;
        end
    endcase 
    if(address > 32'hFF) begin
        err = 1;
    end
end 



endmodule

