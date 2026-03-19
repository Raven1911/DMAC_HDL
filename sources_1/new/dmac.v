`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/09/2026 09:42:34 PM
// Design Name: 
// Module Name: dmac
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
module dmac#(
    // Transaction configuration
    parameter ADDR_WIDTH = 32,          // Address width
    parameter DATA_WIDTH = 32,          // Data width
    parameter TRANS_W_STRB_W = 4,       // width strobe
    parameter TRANS_WR_RESP_W = 2,      // width response
    parameter TRANS_PROT      = 3,

    // Interface configuration
    parameter SRC_IF_TYPE       = "AXI",    // TYPE: "AXI4_LITE", "AXIS", "HYPERRAM"
    parameter DST_IF_TYPE       = "AXI"     // TYPE: "AXI4_LITE", "AXIS"    

)(  
    // =========================================================================
    // AXI SLAVE CONFIG INTERFACE (For DMA Register Configuration)
    // =========================================================================
    // --- Write Address Channel (AW) ---
    // input   [ADDR_WIDTH-1:0]             s_axi_cfg_awaddr_i,  // Write address from CPU
    // input                                s_axi_cfg_awvalid_i, // Write address valid signal
    // output                               s_axi_cfg_awready_o, // Slave is ready to accept write address
    // input   [TRANS_PROT-1:0]             s_axi_cfg_awprot_i,  // Protection type (Privileged/Secure access)

    // // --- Write Data Channel (W) ---
    // input   [DATA_WIDTH-1:0]             s_axi_cfg_wdata_i,   // Write data from CPU
    // input   [TRANS_W_STRB_W-1:0]         s_axi_cfg_wstrb_i,   // Write strobes (indicates which byte lanes are valid)
    // input                                s_axi_cfg_wvalid_i,  // Write data valid signal
    // output                               s_axi_cfg_wready_o,  // Slave is ready to accept write data

    // // --- Write Response Channel (B) ---
    // output  [TRANS_WR_RESP_W-1:0]        s_axi_cfg_bresp_o,   // Write response (OKAY, EXOKAY, SLVERR, DECERR)
    // output                               s_axi_cfg_bvalid_o,  // Write response valid signal
    // input                                s_axi_cfg_bready_i,  // Master (CPU) is ready to accept response

    // // --- Read Address Channel (AR) ---
    // input   [ADDR_WIDTH-1:0]             s_axi_cfg_araddr_i,  // Read address from CPU
    // input                                s_axi_cfg_arvalid_i, // Read address valid signal
    // output                               s_axi_cfg_arready_o, // Slave is ready to accept read address
    // input   [TRANS_PROT-1:0]             s_axi_cfg_arprot_i,  // Protection type

    // // --- Read Data Channel (R) ---
    // output  [DATA_WIDTH-1:0]             s_axi_cfg_rdata_o,   // Read data sent to CPU
    // output  [TRANS_WR_RESP_W-1:0]        s_axi_cfg_rresp_o,   // Read response (status of the read transfer)
    // output                               s_axi_cfg_rvalid_o,  // Read data valid signal
    // input                                s_axi_cfg_rready_i,  // Master (CPU) is ready to accept read data

    

    // --- DESTINATION MASTER INTERFACE ---
    // AW Channel: Master drives Address
    output  [ADDR_WIDTH-1:0]             dst_m_axi_awaddr_o,
    output                               dst_m_axi_awvalid_o,
    input                                dst_m_axi_awready_i,
    output  [TRANS_PROT-1:0]             dst_m_axi_awprot_o,

    // W Channel: Master drives Data
    output  [DATA_WIDTH-1:0]             dst_m_axi_wdata_o,
    output  [TRANS_W_STRB_W-1:0]         dst_m_axi_wstrb_o,
    output                               dst_m_axi_wvalid_o,
    input                                dst_m_axi_wready_i,

    // B Channel: Master receives Response
    input   [TRANS_WR_RESP_W-1:0]        dst_m_axi_bresp_i,
    input                                dst_m_axi_bvalid_i,
    output                               dst_m_axi_bready_o,

    // --- SOURCE MASTER INTERFACE ---
    // AR Channel: Master drives Address
    output  [ADDR_WIDTH-1:0]             src_m_axi_araddr_o,
    output                               src_m_axi_arvalid_o,
    input                                src_m_axi_arready_i,
    output  [TRANS_PROT-1:0]             src_m_axi_arprot_o,

    // R Channel: Master receives Data
    input   [DATA_WIDTH-1:0]             src_m_axi_rdata_i,
    input   [TRANS_WR_RESP_W-1:0]        src_m_axi_rresp_i,
    input                                src_m_axi_rvalid_i,
    output                               src_m_axi_rready_o
    );

endmodule



module dma_ch_datapath#(
       // Transaction configuration
    parameter ADDR_WIDTH = 32,          // Address width
    parameter DATA_WIDTH = 32,          // Data width
    parameter TRANS_W_STRB_W = 4,       // width strobe
    parameter TRANS_WR_RESP_W = 2,      // width response
    parameter TRANS_PROT      = 3,

    // Interface configuration
    parameter SRC_IF_TYPE       = "AXIS",    // TYPE: "AXI4_LITE", "AXIS", "HYPERRAM"
    parameter DST_IF_TYPE       = "AXIS"     // TYPE: "AXI4_LITE", "AXIS"
)(  
    input                                clk_i,
    input                                resetn_i,

    // --- Control signals from/to Channel Manager ---
    input                                ch_src_start_i,    // Start signal for source interface from Manager
    input                                ch_dst_start_i,    // Start signal for destination interface from Manager
    input   [ADDR_WIDTH-1:0]             ch_src_addr_i,     // Source start address for reading
    input   [ADDR_WIDTH-1:0]             ch_dst_addr_i,     // Destination start address for writing
    input   [31:0]                       transfer_len_i,    // Length of the transfer in number of data words
    input                                ch_auto_tlast_en_i,// Enable auto TLAST generation based on transfer length
    output                               ch_src_done_o,     // Source transfer done flag
    output                               ch_dst_done_o,     // Destination transfer done flag
    
    // FIFO status flags for the Channel Manager
    output                               fifo_full_o,
    output                               fifo_empty_o,


    // =========================================================================
    // AXI4-LITE INTERFACES
    // =========================================================================
    // --- DESTINATION MASTER INTERFACE ---
    // AW Channel: Master drives Address
    output  [ADDR_WIDTH-1:0]             dst_m_axi_awaddr_o,
    output                               dst_m_axi_awvalid_o,
    input                                dst_m_axi_awready_i,
    output  [TRANS_PROT-1:0]             dst_m_axi_awprot_o,

    // W Channel: Master drives Data
    output  [DATA_WIDTH-1:0]             dst_m_axi_wdata_o,
    output  [TRANS_W_STRB_W-1:0]         dst_m_axi_wstrb_o,
    output                               dst_m_axi_wvalid_o,
    input                                dst_m_axi_wready_i,

    // B Channel: Master receives Response
    input   [TRANS_WR_RESP_W-1:0]        dst_m_axi_bresp_i,
    input                                dst_m_axi_bvalid_i,
    output                               dst_m_axi_bready_o,

    // --- SOURCE MASTER INTERFACE ---
    // AR Channel: Master drives Address
    output  [ADDR_WIDTH-1:0]             src_m_axi_araddr_o,
    output                               src_m_axi_arvalid_o,
    input                                src_m_axi_arready_i,
    output  [TRANS_PROT-1:0]             src_m_axi_arprot_o,

    // R Channel: Master receives Data
    input   [DATA_WIDTH-1:0]             src_m_axi_rdata_i,
    input   [TRANS_WR_RESP_W-1:0]        src_m_axi_rresp_i,
    input                                src_m_axi_rvalid_i,
    output                               src_m_axi_rready_o,

    // =========================================================================
    // AXI4-STREAM INTERFACES
    // =========================================================================
    // --- SOURCE SLAVE INTERFACE (AXI4-Stream) ---
    input                                s_axis_src_tvalid_i,
    output                               s_axis_src_tready_o,
    input   [DATA_WIDTH-1:0]             s_axis_src_tdata_i,
    input   [(DATA_WIDTH/8)-1:0]         s_axis_src_tstrb_i,
    input   [(DATA_WIDTH/8)-1:0]         s_axis_src_tkeep_i,
    input                                s_axis_src_tlast_i,

    // --- DESTINATION MASTER INTERFACE (AXI4-Stream) ---
    output                               m_axis_dst_tvalid_o,
    input                                m_axis_dst_tready_i,
    output  [DATA_WIDTH-1:0]             m_axis_dst_tdata_o,
    output  [(DATA_WIDTH/8)-1:0]         m_axis_dst_tstrb_o,
    output  [(DATA_WIDTH/8)-1:0]         m_axis_dst_tkeep_o,
    output                               m_axis_dst_tlast_o
);  

    generate
        // =========================================================================
        // OPTION 1: AXI4-LITE (Memory Map)
        // =========================================================================
        if (SRC_IF_TYPE == "AXI4_LITE" || SRC_IF_TYPE == "AXI4_LITE") begin
            // =========================================================================
            // INTERNAL WIRES
            // =========================================================================
            wire [DATA_WIDTH-1:0]   m_src_data;
            wire                    m_rd_done;
            wire                    m_wr_done;
            wire [DATA_WIDTH-1:0]   m_dst_rdata;
            wire                    fifo_rd;
            wire                    fifo_wr;

            // =========================================================================
            // GLUE LOGIC (Connecting Manager -> AXI -> FIFO)
            // =========================================================================
            // 1. Source Branch (Read from AXI, push to FIFO)
            // When AXI read is complete (m_rd_done = 1), use this pulse to push data into the FIFO
            assign  fifo_wr = m_rd_done && !fifo_full_o; // Only write to FIFO if it's not full
            assign  ch_src_done_o = m_rd_done; 
            // 2. Destination Branch (Pop from FIFO, write to AXI)
            // When Manager issues a write command (ch_dst_start_i = 1), simultaneously signal AXI Master to write and pop data from the FIFO
            assign  fifo_rd = m_wr_done && !fifo_empty_o; // Only read from FIFO if it's not empty
            assign  ch_dst_done_o = m_wr_done;

            fifo_unit #(
                .ADDR_WIDTH(8), 
                .DATA_WIDTH(DATA_WIDTH)
            ) fifo_channel_uut (
                .clk(clk_i), 
                .reset_n(resetn_i),
                .wr(fifo_wr), 
                .rd(fifo_rd),
                .wr_ptr(),
                .rd_ptr(),
                .w_data(m_src_data), // Data from AXI read goes into FIFO
                .r_data(m_dst_rdata), // Data from FIFO goes to AXI write
                .full(fifo_full_o),
                .empty(fifo_empty_o)
            );


            axi_lite_master_interface #(
                .ADDR_WIDTH         (ADDR_WIDTH),
                .DATA_WIDTH         (DATA_WIDTH),
                .TRANS_W_STRB_W     (TRANS_W_STRB_W),
                .TRANS_WR_RESP_W    (TRANS_WR_RESP_W),
                .TRANS_PROT         (TRANS_PROT),
                .NUM_MASTERS        (1)
            ) src_dst_axi4_lite_interface (
                .aclk_i         (clk_i),
                .aresetn_i      (resetn_i),
                // Userside wr interface signals
                .m_wr_start_i   (ch_dst_start_i),
                .m_wr_addr_i    (ch_dst_addr_i),
                .m_wr_data_i    (m_dst_rdata),
                .m_wr_strb_i    ({(TRANS_W_STRB_W){1'b1}}), // Assuming all byte lanes are valid for simplicity
                .m_wr_done_o    (m_wr_done),
                // Userside rd interface signals
                .m_rd_start_i   (ch_src_start_i),
                .m_rd_addr_i    (ch_src_addr_i),
                .m_rd_data_o    (m_src_data),
                .m_rd_done_o    (m_rd_done),
                // Bus connections
                .axi_awaddr_o   (dst_m_axi_awaddr_o),
                .axi_awvalid_o  (dst_m_axi_awvalid_o),
                .axi_awready_i  (dst_m_axi_awready_i),
                .axi_awprot_o   (dst_m_axi_awprot_o),
                .axi_wdata_o    (dst_m_axi_wdata_o),
                .axi_wstrb_o    (dst_m_axi_wstrb_o),
                .axi_wvalid_o   (dst_m_axi_wvalid_o),
                .axi_wready_i   (dst_m_axi_wready_i),
                .axi_bresp_i    (dst_m_axi_bresp_i),
                .axi_bvalid_i   (dst_m_axi_bvalid_i),
                .axi_bready_o   (dst_m_axi_bready_o),

                .axi_araddr_o   (src_m_axi_araddr_o),
                .axi_arvalid_o  (src_m_axi_arvalid_o),
                .axi_arready_i  (src_m_axi_arready_i),
                .axi_arprot_o   (src_m_axi_arprot_o),
                .axi_rdata_i    (src_m_axi_rdata_i),
                .axi_rresp_i    (src_m_axi_rresp_i),
                .axi_rvalid_i   (src_m_axi_rvalid_i),
                .axi_rready_o   (src_m_axi_rready_o)
            );
        end

        // =========================================================================
        // OPTION 2: AXI4-STREAM (Continuous Stream)
        // =========================================================================
        else if (SRC_IF_TYPE == "AXIS" && DST_IF_TYPE == "AXIS") begin
            // --- AUTO TLAST GENERATION LOGIC ---
            reg [31:0]  stream_rx_cnt;
            wire        src_rx_fire;
            wire        auto_tlast;
            wire        actual_tlast;

            always @(posedge clk_i or negedge resetn_i) begin
                if (!resetn_i) begin
                    stream_rx_cnt <= 0;
                end else begin
                    // Only count when the source channel is enabled by Manager
                    if (ch_src_start_i) begin
                        if (src_rx_fire) begin
                            if (stream_rx_cnt == transfer_len_i - 1)
                                stream_rx_cnt <= 0; // Reset counter for the next transfer block
                            else
                                stream_rx_cnt <= stream_rx_cnt + 1;
                        end
                    end else begin
                        stream_rx_cnt <= 0; // Reset if channel is disabled
                    end
                end
            end

            assign src_rx_fire = s_axis_src_tvalid_i && s_axis_src_tready_o;
            // Assert TLAST automatically when the counter reaches the final word of the transfer length
            assign auto_tlast = (stream_rx_cnt == transfer_len_i - 1);
            // Multiplexer: Select between generated auto_tlast and incoming source tlast
            assign actual_tlast = ch_auto_tlast_en_i ? auto_tlast : s_axis_src_tlast_i;
            

            wire                          user_s_ready;
            wire                          user_m_busy;
            wire  [DATA_WIDTH-1:0]        user_data;
            wire  [(DATA_WIDTH/8)-1:0]    user_tstrb;
            wire  [(DATA_WIDTH/8)-1:0]    user_tkeep;
            wire                          user_tlast;
            // Transfer logic: Move data from Source Slave to Destination Master
            // Only active when Manager gives start signals, Slave has data, and Master is not busy
            wire    axis_transfer;
            wire    axis_transfer_delay;
            assign  axis_transfer = (user_s_ready) && (!user_m_busy) && (ch_src_start_i) && (ch_dst_start_i);


            register_DFF #(
                .SIZE_BITS(1)
            ) delay_axis_transfer_rd (
                .clk_i(clk_i),
                .resetn_i(resetn_i),
                .D_i(axis_transfer & align_dst_wr_en),
                .Q_o(axis_transfer_delay)
            );

            // -------------------------------------------------------------------------
            // USER'S ALIGN FLUSH CONTROL MODULE
            // -------------------------------------------------------------------------
            wire align_src_rd;
            wire align_dst_wr_en;

            axis_align_flush_ctrl align_flush_uut(
                .clk_i            (clk_i),
                .resetn_i         (resetn_i),
                .transfer_len_i   (transfer_len_i),
                .user_s_ready_i   (user_s_ready),
                .axis_transfer_i  (axis_transfer),
                .axis_src_rd_o    (align_src_rd),
                .axis_dst_wr_en_o (align_dst_wr_en)
            );

            // 1. Source Interface (Configured as Slave to receive data)
            axi4_stream #(
                .DATA_WIDTH_BYTE  (DATA_WIDTH / 8),
                .SELECT_INTERFACE (1),               // 1: Slave Interface
                .SIZE_FIFO        (8)
            ) axis_src_inst (
                .aclk_i           (clk_i),
                .aresetn_i        (resetn_i),
                // Connected to external AXI-Stream Source
                .s_tvalid_i       (s_axis_src_tvalid_i),
                .s_tready_o       (s_axis_src_tready_o),
                .s_tdata_i        (s_axis_src_tdata_i),
                .s_tstrb_i        (s_axis_src_tstrb_i),
                .s_tkeep_i        (s_axis_src_tkeep_i),
                .s_tlast_i        (actual_tlast), 
                
                // User-side signals (to be forwarded to Master)
                .user_s_ready_o   (user_s_ready),
                .user_s_rd_data_i (axis_transfer | align_src_rd), // Assert read data valid when transfer is active or when align control signals a read
                .user_s_data_o    (user_data),
                .user_s_tstrb_o   (user_tstrb),
                .user_s_tkeep_o   (user_tkeep),
                .user_s_tlast_o   (user_tlast),
                
                // Unused Master Ports (Tied off)
                .m_tvalid_o       (), 
                .m_tready_i       (1'b0), 
                .m_tdata_o        (), 
                .m_tstrb_o        (), 
                .m_tkeep_o        (), 
                .m_tlast_o        (),
                .user_m_busy_o    (), 
                .user_m_wr_data_i (1'b0), 
                .user_m_data_i    (0), 
                .user_m_tstrb_i   (0), 
                .user_m_tkeep_i   (0), 
                .user_m_tlast_i   (1'b0)
            );

            // 2. Destination Interface (Configured as Master to send data)
            axi4_stream #(
                .DATA_WIDTH_BYTE  (DATA_WIDTH / 8),
                .SELECT_INTERFACE (0),               // 0: Master Interface
                .SIZE_FIFO        (8)
            ) axis_dst_inst (
                .aclk_i           (clk_i),
                .aresetn_i        (resetn_i),
                // Connected to external AXI-Stream Destination
                .m_tvalid_o       (m_axis_dst_tvalid_o),
                .m_tready_i       (m_axis_dst_tready_i),
                .m_tdata_o        (m_axis_dst_tdata_o),
                .m_tstrb_o        (m_axis_dst_tstrb_o),
                .m_tkeep_o        (m_axis_dst_tkeep_o),
                .m_tlast_o        (m_axis_dst_tlast_o),
                
                // User-side signals (receiving from Slave)
                .user_m_busy_o    (user_m_busy),
                .user_m_wr_data_i (axis_transfer_delay), // Assert write data valid when transfer is active
                .user_m_data_i    (user_data),
                .user_m_tstrb_i   (user_tstrb),
                .user_m_tkeep_i   (user_tkeep),
                .user_m_tlast_i   (user_tlast),
                
                // Unused Slave Ports (Tied off)
                .s_tvalid_i       (1'b0), 
                .s_tready_o       (), 
                .s_tdata_i        (0), 
                .s_tstrb_i        (0), 
                .s_tkeep_i        (0), 
                .s_tlast_i        (1'b0),
                .user_s_ready_o   (), 
                .user_s_rd_data_i (1'b0), 
                .user_s_data_o    (), 
                .user_s_tstrb_o   (), 
                .user_s_tkeep_o   (), 
                .user_s_tlast_o   ()
            );

            // 3. Status Flags mapping for the Manager
            assign fifo_full_o  = user_m_busy;
            assign fifo_empty_o = !user_s_ready;
            
            // 4. Done Flags (Triggers when TLAST passes through Handshake)
            assign ch_src_done_o = s_axis_src_tvalid_i && s_axis_src_tready_o && s_axis_src_tlast_i;
            assign ch_dst_done_o = m_axis_dst_tvalid_o && m_axis_dst_tready_i && m_axis_dst_tlast_o;

        end
        

    endgenerate
endmodule


module axis_align_flush_ctrl(  
    input               clk_i,
    input               resetn_i,
    input    [31:0]     transfer_len_i,
    input               user_s_ready_i,
    // Control signals output to FIFO
    input               axis_transfer_i, // Indicates an active transfer is in progress
    output              axis_src_rd_o,    // Command to pull data from Source
    output              axis_dst_wr_en_o // Command to push data to Destination
);

    reg [31:0]  internal_length_count_next, internal_length_count_reg;
    reg [1:0]   byte_count_next, byte_count_reg;
    reg         src_rd_next, src_rd_reg;
    reg         dst_wr_next, dst_wr_reg;
    reg         start_transfer_flag_reg, start_transfer_flag_next;


    always @(posedge clk_i or negedge resetn_i) begin
        if (~resetn_i) begin
            byte_count_reg <= 2'b0;
            src_rd_reg <= 1'b0;
            dst_wr_reg <= 1'b1; // Default to write disabled
            internal_length_count_reg <= 0;
            start_transfer_flag_reg <= 0;
        end else begin
            byte_count_reg <= byte_count_next;
            src_rd_reg <= src_rd_next;
            dst_wr_reg <= dst_wr_next;
            internal_length_count_reg <= internal_length_count_next;
            start_transfer_flag_next <= 0;
        end
    end
    
    always @(*) begin
        byte_count_next = byte_count_reg;
        src_rd_next = src_rd_reg;
        dst_wr_next = dst_wr_reg;
        internal_length_count_next = internal_length_count_reg;
        start_transfer_flag_next = start_transfer_flag_reg;
        if (axis_transfer_i) begin

            internal_length_count_next = internal_length_count_reg + 1;
            byte_count_next = byte_count_reg + 1;
            if (byte_count_reg == 2'b01) begin
                byte_count_next = 0;
            end
            if (byte_count_reg == transfer_len_i) begin
                internal_length_count_reg = 0;
            end
        end
        if (axis_transfer_i == 0) begin
            src_rd_next = 0;
            dst_wr_next = 1;
            byte_count_next = 0;
            internal_length_count_next = 0;
        end
        if ((axis_transfer_i == 1) && (byte_count_reg == 2'b00) && (internal_length_count_reg >= transfer_len_i - 1)) begin
            src_rd_next = 1;
            dst_wr_next = 0;
        end
    end


    assign axis_src_rd_o = src_rd_reg;
    assign axis_dst_wr_en_o = dst_wr_reg;

endmodule
 
