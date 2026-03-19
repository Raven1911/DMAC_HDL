`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/18/2026 05:46:45 PM
// Design Name: 
// Module Name: tb_dma_ch_datapath_axis
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


`timescale 1ns / 1ps

module tb_dma_ch_datapath_axis();

    // =========================================================================
    // PARAMETERS & SIGNALS
    // =========================================================================
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter TRANS_W_STRB_W = 4;

    reg clk;
    reg resetn;

    // --- Manager Control Signals ---
    reg                   ch_src_start;
    reg                   ch_dst_start;
    reg  [31:0]           transfer_len;
    reg                   ch_auto_tlast_en;
    wire                  ch_src_done;
    wire                  ch_dst_done;
    wire                  fifo_full;
    wire                  fifo_empty;

    // --- AXI4-Stream SOURCE (Mock Transmitter) ---
    reg                           s_axis_tvalid;
    wire                          s_axis_tready;
    reg  [DATA_WIDTH-1:0]         s_axis_tdata;
    reg  [(DATA_WIDTH/8)-1:0]     s_axis_tstrb;
    reg  [(DATA_WIDTH/8)-1:0]     s_axis_tkeep;
    reg                           s_axis_tlast;

    // --- AXI4-Stream DESTINATION (Mock Receiver) ---
    wire                          m_axis_tvalid;
    reg                           m_axis_tready;
    wire [DATA_WIDTH-1:0]         m_axis_tdata;
    wire [(DATA_WIDTH/8)-1:0]     m_axis_tstrb;
    wire [(DATA_WIDTH/8)-1:0]     m_axis_tkeep;
    wire                          m_axis_tlast;

    // =========================================================================
    // DEVICE UNDER TEST (DUT) - AXIS to AXIS Mode
    // =========================================================================
    dma_ch_datapath #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .TRANS_W_STRB_W(TRANS_W_STRB_W),
        .SRC_IF_TYPE("AXIS"),
        .DST_IF_TYPE("AXIS")
    ) dut (
        .clk_i(clk),
        .resetn_i(resetn),

        // Manager Interface
        .ch_src_start_i(ch_src_start),
        .ch_dst_start_i(ch_dst_start),
        .ch_src_addr_i(32'h00000000), // Unused in AXIS mode
        .ch_dst_addr_i(32'h00000000), // Unused in AXIS mode
        .transfer_len_i(transfer_len),
        .ch_auto_tlast_en_i(ch_auto_tlast_en),
        .ch_src_done_o(ch_src_done),
        .ch_dst_done_o(ch_dst_done),
        .fifo_full_o(fifo_full),
        .fifo_empty_o(fifo_empty),

        // Dummy ties for AXI-Lite inputs
        .dst_m_axi_awready_i(1'b0),
        .dst_m_axi_wready_i(1'b0),
        .dst_m_axi_bresp_i(2'b00),
        .dst_m_axi_bvalid_i(1'b0),
        .src_m_axi_arready_i(1'b0),
        .src_m_axi_rdata_i(32'h0),
        .src_m_axi_rresp_i(2'b00),
        .src_m_axi_rvalid_i(1'b0),

        // AXI4-Stream Source Interface
        .s_axis_src_tvalid_i(s_axis_tvalid),
        .s_axis_src_tready_o(s_axis_tready),
        .s_axis_src_tdata_i(s_axis_tdata),
        .s_axis_src_tstrb_i(s_axis_tstrb),
        .s_axis_src_tkeep_i(s_axis_tkeep),
        .s_axis_src_tlast_i(s_axis_tlast),

        // AXI4-Stream Destination Interface
        .m_axis_dst_tvalid_o(m_axis_tvalid),
        .m_axis_dst_tready_i(m_axis_tready),
        .m_axis_dst_tdata_o(m_axis_tdata),
        .m_axis_dst_tstrb_o(m_axis_tstrb),
        .m_axis_dst_tkeep_o(m_axis_tkeep),
        .m_axis_dst_tlast_o(m_axis_tlast)
    );

    // =========================================================================
    // CLOCK & RESET GENERATION
    // =========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // =========================================================================
    // MOCK DESTINATION RECEIVER (With random back-pressure)
    // =========================================================================
    always @(posedge clk) begin
        if (!resetn) begin
            m_axis_tready <= 0;
        end else begin
            // Toggle tready randomly to test FIFO buffering and back-pressure
            // Using a simple LFSR or counter logic. Here we just toggle it 75% of the time.
            m_axis_tready <= ($random % 4 != 0); // 75% duty cycle for tready
        end
    end

    // Print out received data to console for verification
    always @(posedge clk) begin
        if (m_axis_tvalid && m_axis_tready) begin
            $display("    [DEST RECEIVE] Data: %h | TLAST: %b", m_axis_tdata, m_axis_tlast);
        end
    end

    // =========================================================================
    // TASKS FOR SOURCE TRANSMITTER
    // =========================================================================
    // Task to send a stream of N words
    task send_stream(input [31:0] length, input inject_tlast);
        integer i;
        begin
            for (i = 0; i < length; i = i + 1) begin
                s_axis_tvalid <= 1;
                s_axis_tdata  <= 32'hA000_0000 + i;
                s_axis_tstrb  <= 4'hF;
                s_axis_tkeep  <= 4'hF;
                
                // If inject_tlast is true, assert it on the last word
                if (inject_tlast && (i == length - 1))
                    s_axis_tlast <= 1;
                else
                    s_axis_tlast <= 0;

                // Wait for Handshake
                @(posedge clk);
                while (!s_axis_tready) begin
                    @(posedge clk); // Wait until Slave accepts data
                end
            end
            
            // Clear signals after transfer
            s_axis_tvalid <= 0;
            s_axis_tlast  <= 0;
        end
    endtask

    // =========================================================================
    // MAIN TEST SCENARIOS
    // =========================================================================
    initial begin
        // Initialize
        resetn           = 0;
        ch_src_start     = 0;
        ch_dst_start     = 0;
        transfer_len     = 0;
        ch_auto_tlast_en = 0;
        s_axis_tvalid    = 0;
        s_axis_tdata     = 0;
        s_axis_tstrb     = 0;
        s_axis_tkeep     = 0;
        s_axis_tlast     = 0;

        // Apply Reset
        #20 resetn = 1;
        #20;

        $display("--- STARTING AXI-STREAM SIMULATION ---");

        // ---------------------------------------------------------------------
        // CASE 1: Transfer using Original Source TLAST
        // ---------------------------------------------------------------------
        $display("\n[CASE 1] Transfer 8 words using Original Source TLAST (Auto TLAST = OFF)");
        
        // Setup Manager
        transfer_len     = 256; 
        ch_auto_tlast_en = 0; // Disable Auto TLAST
        
        @(posedge clk);
        ch_src_start = 1;
        ch_dst_start = 1;

        // Send 256 bytes, forcefully inject TLAST on the last word
        send_stream(256, 1);

        // Wait for Destination to finish pulling data from FIFO
        wait(ch_dst_done);
        @(posedge clk);
        
        // Turn off channels
        ch_src_start = 0;
        ch_dst_start = 0;
        $display("[CASE 1] Completed.");
        #100;

        // ---------------------------------------------------------------------
        // CASE 2: Transfer using Auto-Generated TLAST
        // ---------------------------------------------------------------------
        $display("\n[CASE 2] Transfer 12 words using Auto TLAST (Auto TLAST = ON)");
        
        // Setup Manager
        transfer_len     = 33; 
        ch_auto_tlast_en = 1; // ENABLE Auto TLAST
        
        @(posedge clk);
        ch_src_start = 1;
        ch_dst_start = 1;

        // Send 12 words, DO NOT inject TLAST (Simulating a dumb source like ADC/Sensor)
        send_stream(64, 0);

        // Wait for Destination to finish pulling data from FIFO
        wait(ch_dst_done);
        @(posedge clk);
        
        // Turn off channels
        ch_src_start = 0;
        ch_dst_start = 0;
        $display("[CASE 2] Completed. Check waveform: m_axis_tlast should be HIGH on the 12th word.");
        
        #100;
        $display("\n--- SIMULATION FINISHED ---");
        $finish;
    end

endmodule