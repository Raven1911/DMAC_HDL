`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/18/2026 04:37:12 PM
// Design Name: 
// Module Name: axi4_stream
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module axi4_stream#(
    parameter DATA_WIDTH_BYTE = 2, // byte unit, 1: 8bit, 2: 16bit, 4: 32bit, 8: 64bit
    parameter SELECT_INTERFACE = 0, // 0: master interface, 1: slave interface
    parameter SIZE_FIFO = 8 // 2^SIZE_FIFO is the depth of FIFO
)(
    //generate port
    input                           aclk_i,
    input                           aresetn_i,
    /////////////////////////////////////////////////
    //master interface port
    /////////////////////////////////////////////////
    output                          m_tvalid_o,
    input                           m_tready_i,
    output  [DATA_WIDTH_BYTE*8-1:0] m_tdata_o,
    output  [DATA_WIDTH_BYTE-1:0]   m_tstrb_o,
    output  [DATA_WIDTH_BYTE-1:0]   m_tkeep_o,
    output                          m_tlast_o,

    //user master interface port
    output                          user_m_busy_o,
    input                           user_m_wr_data_i,
    input  [DATA_WIDTH_BYTE*8-1:0]  user_m_data_i,
    input  [DATA_WIDTH_BYTE-1:0]    user_m_tstrb_i,
    input  [DATA_WIDTH_BYTE-1:0]    user_m_tkeep_i,
    input                           user_m_tlast_i,
    /////////////////////////////////////////////////

    /////////////////////////////////////////////////
    //slave interface port
    /////////////////////////////////////////////////
    input                           s_tvalid_i,
    output                          s_tready_o,
    input  [DATA_WIDTH_BYTE*8-1:0]  s_tdata_i,
    input  [DATA_WIDTH_BYTE-1:0]    s_tstrb_i,
    input  [DATA_WIDTH_BYTE-1:0]    s_tkeep_i,
    input                           s_tlast_i,

    //user slave interface port
    output                          user_s_ready_o,
    input                           user_s_rd_data_i,
    output  [DATA_WIDTH_BYTE*8-1:0] user_s_data_o,
    output  [DATA_WIDTH_BYTE-1:0]   user_s_tstrb_o,
    output  [DATA_WIDTH_BYTE-1:0]   user_s_tkeep_o,
    output                          user_s_tlast_o
    /////////////////////////////////////////////////
    );

    generate
        //master interface
        if (SELECT_INTERFACE == 0) begin
            
            wire empty_i, full_i, rd_fifo_o;

            coordinator_master#(
                .DATA_WIDTH_BYTE(DATA_WIDTH_BYTE)
            )coordinator_master_uut(
                //port generate
                .m_tvalid_o(m_tvalid_o),
                .m_tready_i(m_tready_i),
                .user_m_busy_o(user_m_busy_o),
                .empty_i(empty_i),
                .full_i(full_i),
                .rd_fifo_o(rd_fifo_o)
            );

            wire  [DATA_WIDTH_BYTE*8-1:0] wire_tdata;
            wire  [DATA_WIDTH_BYTE-1:0]   wire_tstrb;
            wire  [DATA_WIDTH_BYTE-1:0]   wire_tkeep;
            wire                          wire_tlast;

            register_DFF #(
                .SIZE_BITS(1 + DATA_WIDTH_BYTE + DATA_WIDTH_BYTE + (DATA_WIDTH_BYTE*8))
            ) stage_delay_data (
                .clk_i(aclk_i),
                .resetn_i(aresetn_i),
                .D_i({user_m_tlast_i, user_m_tkeep_i, user_m_tstrb_i, user_m_data_i}),
                .Q_o({wire_tlast, wire_tkeep, wire_tstrb, wire_tdata})
            );

            fifo_unit #(.ADDR_WIDTH(SIZE_FIFO), .DATA_WIDTH(1 + DATA_WIDTH_BYTE + DATA_WIDTH_BYTE + (DATA_WIDTH_BYTE*8))) buffer_uut(
                .clk(aclk_i), 
                .reset_n(aresetn_i),
                .wr(user_m_wr_data_i && !user_m_busy_o), 
                .rd(rd_fifo_o),
                .wr_ptr(),
                .rd_ptr(),
                .w_data({wire_tlast, wire_tkeep, wire_tstrb, wire_tdata}),                //writing data
                .r_data({m_tlast_o, m_tkeep_o, m_tstrb_o, m_tdata_o}),                    //reading data
                .full(full_i),
                .empty(empty_i)
            );

            
        end

        //slave interface
        else if (SELECT_INTERFACE == 1) begin
            wire empty_i, full_i, wr_fifo_o;

            coordinator_slave#(
                .DATA_WIDTH_BYTE(DATA_WIDTH_BYTE)
            )coordinator_slave_uut(
                //port generate
                .s_tvalid_i(s_tvalid_i),
                .s_tready_o(s_tready_o),
                .user_s_ready_o(user_s_ready_o),
                .empty_i(empty_i),
                .full_i(full_i),
                .wr_fifo_o(wr_fifo_o)
            );

            

            fifo_unit #(.ADDR_WIDTH(SIZE_FIFO), .DATA_WIDTH(1 + DATA_WIDTH_BYTE + DATA_WIDTH_BYTE + (DATA_WIDTH_BYTE*8))) buffer_uut(
                .clk(aclk_i), 
                .reset_n(aresetn_i),
                .wr(wr_fifo_o), 
                .rd(user_s_rd_data_i && user_s_ready_o),
                .wr_ptr(),
                .rd_ptr(),
                .w_data({s_tlast_i, s_tkeep_i, s_tstrb_i, s_tdata_i}),                                       //writing data
                .r_data({user_s_tlast_o, user_s_tkeep_o, user_s_tstrb_o, user_s_data_o}),                    //reading data
                .full(full_i),
                .empty(empty_i)
            );
            
        end
    endgenerate



endmodule


module coordinator_master#(
    parameter DATA_WIDTH_BYTE = 2
)(
    /////////////////////////////////////////////////
    //port master interface
    /////////////////////////////////////////////////
    output                          m_tvalid_o,
    input                           m_tready_i,
    output                          user_m_busy_o,
    //port FIFO interface
    input                           empty_i,
    input                           full_i,
    output                          rd_fifo_o
);

    assign m_tvalid_o = !empty_i;
    assign rd_fifo_o = (m_tvalid_o == 1 && m_tready_i == 1) ? 1'b1 : 1'b0;
    assign user_m_busy_o = full_i;

endmodule


module coordinator_slave#(
    parameter DATA_WIDTH_BYTE = 2
)(
    /////////////////////////////////////////////////
    //port slave interface
    /////////////////////////////////////////////////
    input                           s_tvalid_i,
    output                          s_tready_o,
    
    output                          user_s_ready_o,


    //port FIFO interface
    input                           empty_i,
    input                           full_i,
    output                          wr_fifo_o

);
    assign s_tready_o = (!full_i && s_tvalid_i == 1) ? 1'b1 : 1'b0;
    assign wr_fifo_o = (s_tvalid_i == 1 && s_tready_o == 1) ? 1'b1 : 1'b0;
    assign user_s_ready_o = !empty_i;

endmodule
