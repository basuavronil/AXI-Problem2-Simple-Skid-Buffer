`timescale 1ns / 1ps

module tb_skid_buffer;

    // Clock & Reset
    reg        clk;
    reg        rst;

    // Upstream Interface (Producer)
    reg        s_valid;
    wire       s_ready;
    reg [31:0] s_data;

    // Downstream Interface (Consumer)
    wire        m_valid;
    reg         m_ready;
    wire [31:0] m_data;

    // Instantiate the DUT (Device Under Test)
    skid_buffer dut (
        .clk     (clk),
        .rst     (rst),
        .s_valid (s_valid),
        .s_ready (s_ready),
        .s_data  (s_data),
        .m_valid (m_valid),
        .m_ready (m_ready),
        .m_data  (m_data)
    );

    // 100MHz Clock Generation (10ns period)
    always #5 clk = ~clk;

    // Verification monitor
    always @(posedge clk) begin
        if (m_valid && m_ready) begin
            $display("[TIME %0t ns] SUCCESS: Consumer read data = 0x%8h", $time, m_data);
        end
    end

    initial begin
        // Initialize Signals
        clk     = 0;
        rst     = 1;
        s_valid = 0;
        s_data  = 32'h0;
        m_ready = 0;

        // Reset sequence
        #15;
        rst = 0;
        #10;

        // -------------------------------------------------------------
        // TEST 1: Direct Passthrough / Normal Flow (m_ready = 1)
        // -------------------------------------------------------------
        $display("\n--- Starting Test 1: Normal Flow ---");
        m_ready = 1;

        send_data(32'hA1A1_A1A1);
        send_data(32'hB2B2_B2B2);
        send_data(32'hC3C3_C3C3);

        @(posedge clk);
        s_valid = 0;
        #20;

        // -------------------------------------------------------------
        // TEST 2: Downstream Stall & Skid Capture
        // -------------------------------------------------------------
        $display("\n--- Starting Test 2: Downstream Stall ---");
        
        // Step A: Send 1st word while consumer is ready
        s_valid = 1;
        s_data  = 32'h1111_1111;
        @(posedge clk);

        // Step B: Consumer suddenly goes BUSY (m_ready = 0)
        m_ready = 0;
        
        // Producer sends 2nd word -> gets stored in main_reg
        s_data  = 32'h2222_2222;
        @(posedge clk);

        // Producer sends 3rd word -> triggers the "SKID" into skid_reg
        s_data  = 32'h3333_3333;
        @(posedge clk);

        // Stop producing
        s_valid = 0;
        
        // Verify s_ready dropped to 0 because skid buffer is completely full
        #1;
        if (s_ready == 0) begin
            $display("[TIME %0t ns] PASS: s_ready deasserted (Skid Buffer full).", $time);
        end else begin
            $display("[TIME %0t ns] FAIL: s_ready should be 0!", $time);
        end

        #20;

        // -------------------------------------------------------------
        // TEST 3: Drain Buffer
        // -------------------------------------------------------------
        $display("\n--- Starting Test 3: Consumer Resumes (Drain) ---");
        m_ready = 1; // Consumer ready again

        #40; // Allow time to drain main_reg and skid_reg

        $display("\n--- All Tests Completed ---");
        $finish;
    end

    // Helper task to send data
    task send_data(input [31:0] data);
        begin
            s_valid = 1;
            s_data  = data;
            do begin
                @(posedge clk);
            end while (!s_ready);
        end
    endtask

endmodule
