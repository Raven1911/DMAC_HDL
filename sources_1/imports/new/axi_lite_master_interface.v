`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/10/2026 11:37:03 AM
// Design Name: 
// Module Name: axi_lite_master_interface
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

//////////////////////////////////////////////////////////////////////////////////
// Module Name: axi_lite_master_interface
// Description: AXI-Lite Master updated with NUM_MASTERS logic and dual-edge DFFs.
//              Designed to interface with the provided Slave module.
//////////////////////////////////////////////////////////////////////////////////
module axi_lite_master_interface#(
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 32,
    parameter TRANS_W_STRB_W  = 4,
    parameter TRANS_WR_RESP_W = 2,
    parameter TRANS_PROT      = 3,
    parameter NUM_MASTERS     = 1
)(
    // Global Signals
    input  wire                         aclk_i,
    input  wire                         aresetn_i,

    // Internal Master Logic (User Side)
    input  wire                         m_wr_start_i,
    input  wire [ADDR_WIDTH-1:0]        m_wr_addr_i,
    input  wire [DATA_WIDTH-1:0]        m_wr_data_i,
    input  wire [TRANS_W_STRB_W-1:0]    m_wr_strb_i,
    output wire                         m_wr_done_o,

    input  wire                         m_rd_start_i,
    input  wire [ADDR_WIDTH-1:0]        m_rd_addr_i,
    output wire [DATA_WIDTH-1:0]        m_rd_data_o,
    output reg                          m_rd_done_o,

    // AXI-Lite Channels
    output wire [ADDR_WIDTH-1:0]        axi_awaddr_o,
    output wire                         axi_awvalid_o,
    input  wire                         axi_awready_i,
    output wire [TRANS_PROT-1:0]        axi_awprot_o,
    output wire [DATA_WIDTH-1:0]        axi_wdata_o,
    output wire [TRANS_W_STRB_W-1:0]    axi_wstrb_o,
    output wire                         axi_wvalid_o,
    input  wire                         axi_wready_i,
    input  wire [TRANS_WR_RESP_W-1:0]   axi_bresp_i,
    input  wire                         axi_bvalid_i,
    output wire                         axi_bready_o,
    output wire [ADDR_WIDTH-1:0]        axi_araddr_o,
    output wire                         axi_arvalid_o,
    input  wire                         axi_arready_i,
    output wire [TRANS_PROT-1:0]        axi_arprot_o,
    input  wire [DATA_WIDTH-1:0]        axi_rdata_i,
    input  wire                         axi_rvalid_i,
    input  wire [TRANS_WR_RESP_W-1:0]   axi_rresp_i,
    output wire                         axi_rready_o
);
    // =========================================================================
    // WRITE TRANSACTION LOGIC
    // =========================================================================
    reg aw_valid_flag_reg, aw_valid_flag_next; 
    reg w_valid_flag_reg, w_valid_flag_next; 
    reg b_ready_flag_reg, b_ready_flag_next;
    reg w_transaction_done_flag_reg, w_transaction_done_flag_next;

    always @(posedge aclk_i or negedge aresetn_i) begin
        if (!aresetn_i) begin
            aw_valid_flag_reg <= 1'b0;
            w_valid_flag_reg  <= 1'b0;
            b_ready_flag_reg  <= 1'b0;
            w_transaction_done_flag_reg <= 1'b0;
        end else begin
            aw_valid_flag_reg <= aw_valid_flag_next;
            w_valid_flag_reg  <= w_valid_flag_next;
            b_ready_flag_reg  <= b_ready_flag_next;
            w_transaction_done_flag_reg <= w_transaction_done_flag_next;
            
        end
    end

    always @(*) begin
        aw_valid_flag_next = aw_valid_flag_reg;
        w_valid_flag_next  = w_valid_flag_reg;
        b_ready_flag_next  = b_ready_flag_reg;
        w_transaction_done_flag_next = w_transaction_done_flag_reg;
        if (m_wr_start_i && !w_transaction_done_flag_reg) begin
            aw_valid_flag_next = 1'b1;
            w_valid_flag_next  = 1'b1;
            b_ready_flag_next  = 1'b1;
            w_transaction_done_flag_next = 1'b1;
        end else begin
            if (axi_awvalid_o && axi_awready_i) aw_valid_flag_next = 1'b0;
            if (axi_wvalid_o && axi_wready_i)   w_valid_flag_next  = 1'b0;
            if (axi_bvalid_i && axi_bready_o)   b_ready_flag_next  = 1'b0;
            if (axi_bvalid_i && axi_bready_o)   w_transaction_done_flag_next = 1'b0;
        end
        
    end

    assign axi_awvalid_o = aw_valid_flag_reg;
    assign axi_wvalid_o  = w_valid_flag_reg;
    assign axi_bready_o  = b_ready_flag_reg;
    assign axi_awprot_o  = 3'b000;
    assign axi_wstrb_o   = m_wr_strb_i;
    assign m_wr_done_o   = axi_bvalid_i && axi_bready_o;


    generate
        if (NUM_MASTERS == 1) begin : gen_aw_single
            register_DFF #( .SIZE_BITS(ADDR_WIDTH) ) reg_awaddr (
                .clk_i    (aclk_i),
                .resetn_i (aresetn_i),
                .D_i      (m_wr_addr_i),
                .Q_o      (axi_awaddr_o)
            );
        end else begin : gen_aw_multi
            register_DFF_negedge #( .SIZE_BITS(ADDR_WIDTH) ) reg_awaddr (
                .clkn_i   (aclk_i),
                .resetn_i (aresetn_i),
                .D_i      (m_wr_addr_i),
                .Q_o      (axi_awaddr_o)
            );
        end
    endgenerate

    register_DFF #( .SIZE_BITS(DATA_WIDTH) ) reg_wdata (
        .clk_i    (aclk_i),
        .resetn_i (aresetn_i),
        .D_i      (m_wr_data_i),
        .Q_o      (axi_wdata_o)
    );

    register_DFF #( .SIZE_BITS(TRANS_W_STRB_W) ) reg_wstrb (
        .clk_i    (aclk_i),
        .resetn_i (aresetn_i),
        .D_i      (m_wr_strb_i),
        .Q_o      (axi_wstrb_o)
    );

    // =========================================================================
    // READ TRANSACTION LOGIC
    // =========================================================================
    reg ar_valid_flag_reg, ar_valid_flag_next; 
    reg r_ready_flag_reg, r_ready_flag_next;
    reg r_transaction_done_flag_reg, r_transaction_done_flag_next;
    wire wire_r_transaction_done_flag_delay;

    register_DFF #( .SIZE_BITS(1) ) ar_reg_delay (
                .clk_i    (aclk_i),
                .resetn_i (aresetn_i),
                .D_i      (r_transaction_done_flag_reg),
                .Q_o      (wire_r_transaction_done_flag_delay)
    );


    always @(posedge aclk_i or negedge aresetn_i) begin
        if (!aresetn_i) begin
            ar_valid_flag_reg <= 1'b0;
            r_ready_flag_reg  <= 1'b0;
            r_transaction_done_flag_reg <= 1'b0;
        end else begin
            ar_valid_flag_reg <= ar_valid_flag_next;
            r_ready_flag_reg  <= r_ready_flag_next;
            r_transaction_done_flag_reg <= r_transaction_done_flag_next;
        end
    end

    always @(*) begin
        ar_valid_flag_next = ar_valid_flag_reg;
        r_ready_flag_next  = r_ready_flag_reg;
        r_transaction_done_flag_next = r_transaction_done_flag_reg;
        if (m_rd_start_i && !r_transaction_done_flag_reg && !wire_r_transaction_done_flag_delay) begin
            ar_valid_flag_next = 1'b1;
            r_ready_flag_next  = 1'b1;
            r_transaction_done_flag_next = 1'b1;
        end else begin
            if (axi_arvalid_o && axi_arready_i) ar_valid_flag_next = 1'b0;
            if (axi_rvalid_i && axi_rready_o) begin
                r_ready_flag_next  = 1'b0;
                r_transaction_done_flag_next = 1'b0;
            end
        end
    end

    assign axi_arvalid_o = ar_valid_flag_reg;
    assign axi_rready_o  = r_ready_flag_reg;
    assign axi_arprot_o  = 3'b000;

    always @(posedge aclk_i or negedge aresetn_i) begin
        if (!aresetn_i) m_rd_done_o <= 1'b0;
        else            m_rd_done_o <= (axi_rvalid_i && axi_rready_o);
    end

    generate
        if (NUM_MASTERS == 1) begin : gen_ar_single
            register_DFF #( .SIZE_BITS(ADDR_WIDTH) ) reg_araddr (
                .clk_i    (aclk_i),
                .resetn_i (aresetn_i),
                .D_i      (m_rd_addr_i),
                .Q_o      (axi_araddr_o)
            );
        end else begin : gen_ar_multi
            register_DFF_negedge #( .SIZE_BITS(ADDR_WIDTH) ) reg_araddr (
                .clkn_i   (aclk_i),
                .resetn_i (aresetn_i),
                .D_i      (m_rd_addr_i),
                .Q_o      (axi_araddr_o)
            );
        end
    endgenerate

    register_DFF #( .SIZE_BITS(DATA_WIDTH) ) reg_rdata_in (
        .clk_i    (aclk_i), 
        .resetn_i (aresetn_i),
        .D_i      (axi_rdata_i),
        .Q_o      (m_rd_data_o)
    );

endmodule
