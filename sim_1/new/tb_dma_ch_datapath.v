`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/18/2026 04:11:21 PM
// Design Name: 
// Module Name: tb_dma_ch_datapath
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

module tb_dma_ch_datapath();

    // =========================================================================
    // PARAMETERS & SIGNALS
    // =========================================================================
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter TRANS_W_STRB_W = 4;
    parameter TRANS_WR_RESP_W = 2;
    parameter TRANS_PROT = 3;

    reg clk;
    reg resetn;

    // Manager Control Signals
    reg                   ch_src_start;
    reg                   ch_dst_start;
    reg  [ADDR_WIDTH-1:0] ch_src_addr;
    reg  [ADDR_WIDTH-1:0] ch_dst_addr;
    wire                  ch_src_done;
    wire                  ch_dst_done;
    wire                  fifo_full;
    wire                  fifo_empty;

    // Destination AXI Signals
    wire [ADDR_WIDTH-1:0]      dst_awaddr;
    wire                       dst_awvalid;
    reg                        dst_awready;
    wire [TRANS_PROT-1:0]      dst_awprot;
    wire [DATA_WIDTH-1:0]      dst_wdata;
    wire [TRANS_W_STRB_W-1:0]  dst_wstrb;
    wire                       dst_wvalid;
    reg                        dst_wready;
    reg  [TRANS_WR_RESP_W-1:0] dst_bresp;
    reg                        dst_bvalid;
    wire                       dst_bready;

    // Source AXI Signals
    wire [ADDR_WIDTH-1:0]      src_araddr;
    wire                       src_arvalid;
    reg                        src_arready;
    wire [TRANS_PROT-1:0]      src_arprot;
    reg  [DATA_WIDTH-1:0]      src_rdata;
    reg  [TRANS_WR_RESP_W-1:0] src_rresp;
    reg                        src_rvalid;
    wire                       src_rready;

    // Testbench Variables
    integer i;
    integer r, w; // Thêm biến đếm cho quá trình fork-join

    // =========================================================================
    // DEVICE UNDER TEST (DUT)
    // =========================================================================
    dma_ch_datapath #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .TRANS_W_STRB_W(TRANS_W_STRB_W),
        .TRANS_WR_RESP_W(TRANS_WR_RESP_W),
        .TRANS_PROT(TRANS_PROT)
    ) dut (
        .clk_i(clk),
        .resetn_i(resetn),

        // Manager Interface
        .ch_src_start_i(ch_src_start),
        .ch_dst_start_i(ch_dst_start),
        .ch_src_addr_i(ch_src_addr),
        .ch_dst_addr_i(ch_dst_addr),
        .ch_src_done_o(ch_src_done),
        .ch_dst_done_o(ch_dst_done),
        .fifo_full_o(fifo_full),
        .fifo_empty_o(fifo_empty),

        // Destination AXI
        .dst_m_axi_awaddr_o(dst_awaddr),
        .dst_m_axi_awvalid_o(dst_awvalid),
        .dst_m_axi_awready_i(dst_awready),
        .dst_m_axi_awprot_o(dst_awprot),
        .dst_m_axi_wdata_o(dst_wdata),
        .dst_m_axi_wstrb_o(dst_wstrb),
        .dst_m_axi_wvalid_o(dst_wvalid),
        .dst_m_axi_wready_i(dst_wready),
        .dst_m_axi_bresp_i(dst_bresp),
        .dst_m_axi_bvalid_i(dst_bvalid),
        .dst_m_axi_bready_o(dst_bready),

        // Source AXI
        .src_m_axi_araddr_o(src_araddr),
        .src_m_axi_arvalid_o(src_arvalid),
        .src_m_axi_arready_i(src_arready),
        .src_m_axi_arprot_o(src_arprot),
        .src_m_axi_rdata_i(src_rdata),
        .src_m_axi_rresp_i(src_rresp),
        .src_m_axi_rvalid_i(src_rvalid),
        .src_m_axi_rready_o(src_rready)
    );

    // =========================================================================
    // CLOCK & RESET GENERATION
    // =========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // =========================================================================
    // MOCK AXI SOURCE SLAVE (FAST READ)
    // Phản hồi ngay lập tức để mô phỏng Source tốc độ cao
    // =========================================================================
    always @(posedge clk) begin
        if (!resetn) begin
            src_arready <= 0;
            src_rvalid  <= 0;
            src_rdata   <= 0;
            src_rresp   <= 0;
        end else begin
            if (src_arvalid && !src_arready) src_arready <= 1;
            else src_arready <= 0;

            if (src_arvalid && src_arready) begin
                src_rvalid <= 1;
                src_rdata  <= src_araddr + 32'hAA000000;
            end else if (src_rvalid && src_rready) begin
                src_rvalid <= 0;
            end
        end
    end

    // =========================================================================
    // MOCK AXI DESTINATION SLAVE (SLOW WRITE)
    // Cố tình làm chậm quá trình ghi (đợi 5 cycles) để làm FIFO bị dồn ứ (FULL)
    // =========================================================================
    reg [3:0] delay_cnt;
    always @(posedge clk) begin
        if (!resetn) begin
            dst_awready <= 0;
            dst_wready  <= 0;
            dst_bvalid  <= 0;
            dst_bresp   <= 0;
            delay_cnt   <= 0;
        end else begin
            // Tạo trễ 5 xung nhịp trước khi Ready
            if ((dst_awvalid || dst_wvalid) && delay_cnt < 5) begin
                delay_cnt <= delay_cnt + 1;
                dst_awready <= 0;
                dst_wready  <= 0;
            end else if ((dst_awvalid || dst_wvalid) && delay_cnt == 5) begin
                dst_awready <= 1;
                dst_wready  <= 1;
                delay_cnt   <= 0; // Reset counter
            end else begin
                dst_awready <= 0;
                dst_wready  <= 0;
            end

            if (dst_wvalid && dst_wready) begin
                dst_bvalid <= 1;
                dst_bresp  <= 2'b00;
            end else if (dst_bvalid && dst_bready) begin
                dst_bvalid <= 0;
            end
        end
    end

    // =========================================================================
    // TASKS FOR CHANNEL MANAGER BEHAVIOR
    // =========================================================================
    task trigger_read(input [ADDR_WIDTH-1:0] addr);
        begin
            @(posedge clk);
            ch_src_addr  <= addr;
            ch_src_start <= 1;
            @(posedge clk);
            ch_src_start <= 0;
            wait (ch_src_done);
            @(posedge clk);
        end
    endtask

    task trigger_write(input [ADDR_WIDTH-1:0] addr);
        begin
            @(posedge clk);
            ch_dst_addr  <= addr;
            ch_dst_start <= 1;
            @(posedge clk);
            ch_dst_start <= 0;
            wait (ch_dst_done);
            @(posedge clk);
        end
    endtask

    // =========================================================================
    // MAIN TEST SCENARIOS
    // =========================================================================
    initial begin
        // Initialize signals
        resetn       = 0;
        ch_src_start = 0;
        ch_dst_start = 0;
        ch_src_addr  = 0;
        ch_dst_addr  = 0;

        // Apply Reset
        #20 resetn = 1;
        #20;

        $display("--- STARTING SIMULATION ---");

        // ---------------------------------------------------------------------
        // CASE 1: Single Word Transfer (Read 1 word, Write 1 word)
        // ---------------------------------------------------------------------
        $display("[CASE 1] Single Word Transfer");
        trigger_read(32'h1000_0000);
        
        if (!fifo_empty) $display("-> Data successfully stored in FIFO.");
        else $display("-> ERROR: FIFO is still empty!");

        trigger_write(32'h2000_0000);
        $display("[CASE 1] Completed.\n");

        #50;

        // ---------------------------------------------------------------------
        // CASE 2: Burst/Block Transfer Emulation (Read 4 words, Write 4 words)
        // ---------------------------------------------------------------------
        $display("[CASE 2] Block Transfer (4 words)");
        
        // Read 4 words into FIFO
        for (i = 0; i < 4; i = i + 1) begin
            trigger_read(32'h1000_0000 + (i * 4));
        end
        $display("-> 4 words read into FIFO.");

        // Write 4 words from FIFO
        for (i = 0; i < 4; i = i + 1) begin
            trigger_write(32'h2000_0000 + (i * 4));
        end
        $display("[CASE 2] Completed.\n");

        #50;

        // ---------------------------------------------------------------------
        // CASE 3: Interleaved Transfer (Read -> Write -> Read -> Write)
        // ---------------------------------------------------------------------
        $display("[CASE 3] Interleaved Read/Write");
        trigger_read(32'h3000_0000);
        trigger_write(32'h4000_0000);
        
        trigger_read(32'h3000_0004);
        trigger_write(32'h4000_0004);
        $display("[CASE 3] Completed.\n");


        // ---------------------------------------------------------------------
        // CASE 4: Continuous Read/Write relying on FIFO FULL / EMPTY
        // ---------------------------------------------------------------------
        $display("[CASE 4] Continuous Burst (300 words) with FIFO throttling");
        fork
            // --- THREAD 1: SOURCE MANAGER (Nhồi data vào FIFO) ---
            begin
                for (r = 0; r < 300; r = r + 1) begin
                    @(posedge clk);
                    // Dựa vào cờ FULL: Nếu FIFO đầy, Channel Manager phải giậm chân tại chỗ
                    while (fifo_full) begin
                        ch_src_start = 0;
                        @(posedge clk);
                    end
                    
                    // Phát lệnh cấp data
                    ch_src_addr  = 32'h5000_0000 + (r * 4);
                    ch_src_start = 1;
                    @(posedge clk);
                    ch_src_start = 0;
                    
                    // Chờ AXI đọc xong 1 transaction
                    wait(ch_src_done); 
                end
                $display("-> Thread 1 (Source): Finished pushing 300 words.");
            end

            // --- THREAD 2: DESTINATION MANAGER (Rút data khỏi FIFO) ---
            begin
                for (w = 0; w < 300; w = w + 1) begin
                    @(posedge clk);
                    // Dựa vào cờ EMPTY: Nếu FIFO rỗng, không được phát lệnh ghi
                    while (fifo_empty) begin
                        ch_dst_start = 0;
                        @(posedge clk);
                    end
                    
                    // Phát lệnh lấy data ra ghi lên AXI
                    ch_dst_addr  = 32'h6000_0000 + (w * 4);
                    ch_dst_start = 1;
                    @(posedge clk);
                    ch_dst_start = 0;
                    
                    // Chờ AXI ghi xong 1 transaction
                    wait(ch_dst_done); 
                end
                $display("-> Thread 2 (Destination): Finished pulling 300 words.");
            end
        join
        #100;
        $display("--- SIMULATION FINISHED ---");
        $finish;
    end

endmodule
