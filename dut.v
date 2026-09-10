module skid_buffer (
    input  wire        clk,
    input  wire        rst,
    
    // Upstream Interface
    input  wire        s_valid,
    output wire        s_ready,
    input  wire [31:0] s_data,
    
    // Downstream Interface
    output wire        m_valid,
    input  wire        m_ready,
    output wire [31:0] m_data
);

    reg [31:0] main_reg;
    reg [31:0] skid_reg;
    reg        main_valid;
    reg        skid_valid;

    assign s_ready = !skid_valid;
    assign m_valid = main_valid || skid_valid;
    assign m_data  = skid_valid ? skid_reg : main_reg;

    always @(posedge clk) begin
        if (rst) begin
            main_valid <= 1'b0;
            skid_valid <= 1'b0;
        end else begin
            if (s_ready && s_valid) begin
                if (m_valid && !m_ready) begin
                    skid_reg   <= s_data;
                    skid_valid <= 1'b1;
                end else begin
                    main_reg   <= s_data;
                    main_valid <= 1'b1;
                end
            end else if (m_ready) begin
                if (skid_valid) begin
                    skid_valid <= 1'b0;
                end else begin
                    main_valid <= 1'b0;
                end
            end
        end
    end

endmodule
