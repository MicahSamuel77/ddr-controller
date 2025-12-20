`timescale 1ns / 10ps

`include "type_pkg.vh"

import type_pkg::burst_size_t;

module raw_data_buffer #(
    parameter ADDR_SIZE = 8,
    parameter DATA_SIZE = 64
) (
    input logic clk, n_rst,
    input logic raw,
    input burst_size_t rburst_size_raw,
    /* verilator lint_off UNUSEDSIGNAL */
    input logic [ADDR_SIZE-1:0] raddr_raw, pool_waddr,
    /* verilator lint_on UNUSEDSIGNAL */
    input logic [DATA_SIZE-1:0] pool_wdata,
    output logic raw_strobe,
    output logic [DATA_SIZE-1:0] raw_data
);
    import type_pkg::*;

    logic next_raw_strobe;
    logic [DATA_SIZE-1:0] next_raw_data;
    logic [2:0] rcol, wcol;
    
    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            raw_strobe <= 0;
            raw_data <= 0;
        end else begin
            raw_strobe <= next_raw_strobe;
            raw_data <= next_raw_data;
        end
    end

    always_comb begin
        next_raw_data = raw_data;
        rcol = raddr_raw[2:0];
        wcol = pool_waddr[2:0];
        if (raw) begin
            next_raw_data = pool_wdata;
            unique case (rburst_size_raw)
            EIGHT_BYTES: begin
                if (rcol > wcol) begin
                    case (rcol - wcol) // shift pool_wdata 8x rcol - wcol to the left, add leftover bytes to the LSBs
                        1: next_raw_data = {pool_wdata[7:0], pool_wdata[63:8]};
                        2: next_raw_data = {pool_wdata[15:0], pool_wdata[63:16]};
                        3: next_raw_data = {pool_wdata[23:0], pool_wdata[63:24]};
                        4: next_raw_data = {pool_wdata[31:0], pool_wdata[63:32]};
                        5: next_raw_data = {pool_wdata[39:0], pool_wdata[63:40]};
                        6: next_raw_data = {pool_wdata[47:0], pool_wdata[63:48]};
                        7: next_raw_data = {pool_wdata[55:0], pool_wdata[63:56]};
                        default:;
                    endcase
                end else begin
                    case (wcol - rcol) // shift pool_wdata 8x wcol - rcol to the right, add leftover bytes to the MSBs
                        1: next_raw_data = {pool_wdata[55:0], pool_wdata[63:56]};
                        2: next_raw_data = {pool_wdata[47:0], pool_wdata[63:48]};
                        3: next_raw_data = {pool_wdata[39:0], pool_wdata[63:40]};
                        4: next_raw_data = {pool_wdata[31:0], pool_wdata[63:32]};
                        5: next_raw_data = {pool_wdata[23:0], pool_wdata[63:24]};
                        6: next_raw_data = {pool_wdata[15:0], pool_wdata[63:16]};
                        7: next_raw_data = {pool_wdata[7:0], pool_wdata[63:8]};
                        default:;
                    endcase
                end
            end
            FOUR_BYTES: begin
                if (rcol > wcol) begin
                    case (rcol - wcol) // shift pool_wdata 8x rcol - wcol to the left, add leftover bytes to the LSBs
                        1: next_raw_data = {32'b0, pool_wdata[7:0], pool_wdata[31:8]};
                        2: next_raw_data = {32'b0, pool_wdata[15:0], pool_wdata[31:16]};
                        3: next_raw_data = {32'b0,  pool_wdata[23:0], pool_wdata[31:24]};
                        default:;
                    endcase
                end else begin
                    case (wcol - rcol) // shift pool_wdata 8x wcol - rcol to the right, add leftover bytes to the MSBs
                        1: next_raw_data = {32'b0, pool_wdata[23:0], pool_wdata[31:24]};
                        2: next_raw_data = {32'b0, pool_wdata[15:0], pool_wdata[31:16]};
                        3: next_raw_data = {32'b0, pool_wdata[7:0], pool_wdata[31:8]};
                        default:;
                    endcase
                end
            end
            TWO_BYTES: begin
                if (rcol > wcol) begin
                    case (rcol - wcol) // shift pool_wdata 8x rcol - wcol to the left, add leftover bytes to the LSBs
                        1: next_raw_data = {48'b0, pool_wdata[7:0], pool_wdata[15:8]};
                        default:;
                    endcase
                end else begin
                    case (wcol - rcol) // shift pool_wdata 8x wcol - rcol to the right, add leftover bytes to the MSBs
                        1: next_raw_data = {48'b0, pool_wdata[7:0], pool_wdata[15:8]};
                        default:;
                    endcase
                end
            end
            ONE_BYTE: begin
            end
            endcase
        end

        next_raw_strobe = raw;
    end

endmodule
