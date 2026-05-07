module watchdog_top #(
    parameter CLK_FREQ = 27_000_000
)(
    input i_clk,
    input i_rst_n,
    input i_wdi,    // dau vao wdi(S1)
    input i_en,     // dau vao en(S2)
    input i_uart_rx,    // dau vao uart (nhan lenh tu pc)

    output o_wdo,   // dau ra wdo (D3)
    output o_enout, // dau ra enout (D4)
    output o_uart_tx    // dau ra uart(gui ve pc)
);
    wire [7:0] w_addr;
    wire [31:0] w_wr_data;
    wire w_wr_en, w_rd_en, w_cmd_kick;
    wire [31:0] w_rd_data;
    wire [31:0] w_ctrl;
    wire [31:0] w_twd_ms, w_trst_ms;
    wire [15:0] w_arm_delay_us;
    wire w_uart_kick_p;
    wire w_wdi_clean, w_en_clean;
    wire w_wdo, w_enout;
    wire w_clr_fault;   //regfile den core
    wire w_fault_active;    //tu core
    wire w_kick_signal; // Chon nguon wdi 
    wire w_en_effective;    // enable status
    reg  r_last_kick_src;   // nguon kick cuoi cung
    reg  r_kick_d;  // edge detection

    assign o_wdo = w_wdo;
    assign o_enout = w_enout;
    assign w_en_effective = w_en_clean & w_ctrl[0]; 

    // mux de chon wdi (bit1 cua CTRL)
    assign w_kick_signal = w_ctrl[1] ? ~w_uart_kick_p : w_wdi_clean;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            r_kick_d <= 1'b1;
        else
            r_kick_d <= w_kick_signal;
    end
    // phat hien falling edge
    wire w_kick_negedge = r_kick_d && !w_kick_signal;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            r_last_kick_src <= 1'b0;
        else if (w_kick_negedge)
            r_last_kick_src <= w_ctrl[1];   // 1 = UART, 0 = WDI pin
    end

    // Debounce modules
    sync_debounce #(
        .CLK_FREQ(CLK_FREQ)
    ) sync1 (
        .i_clk(i_clk), 
        .i_rst_n(i_rst_n),
        .i_async(i_wdi), 
        .o_debounced(w_wdi_clean)
    );
    sync_debounce #(
        .CLK_FREQ(CLK_FREQ)
    ) sync2 (
        .i_clk(i_clk), 
        .i_rst_n(i_rst_n),
        .i_async(i_en), 
        .o_debounced(w_en_clean)
    );

    // UART 
    uart uart1 (
        .i_clk(i_clk), 
        .i_rst_n(i_rst_n),
        .i_rx(i_uart_rx),  
        .o_tx(o_uart_tx),
        .o_addr(w_addr),   
        .o_wr_data(w_wr_data),
        .o_wr_en(w_wr_en), 
        .o_rd_en(w_rd_en),
        .o_cmd_kick(w_cmd_kick), 
        .i_rd_data(w_rd_data)
    );

    // Register file
    regfile reg1 (
        .i_clk(i_clk), 
        .i_rst_n(i_rst_n),
        .i_addr(w_addr), 
        .i_wr_data(w_wr_data),
        .i_wr_en(w_wr_en), 
        .i_rd_en(w_rd_en),
        .i_cmd_kick(w_cmd_kick),
        .o_rd_data(w_rd_data),
        .o_ctrl(w_ctrl),
        .o_twd_ms(w_twd_ms), 
        .o_trst_ms(w_trst_ms),
        .o_arm_delay_us(w_arm_delay_us),
        .o_uart_kick_p(w_uart_kick_p),
        .o_clr_fault(w_clr_fault),
        .i_status({27'h0, r_last_kick_src, w_wdo, w_enout, w_fault_active, w_en_effective})
    );

    // Watchdog core
    watchdog_core #(
        .CLK_FREQ(CLK_FREQ)
    ) wdt1 (
        .i_clk(i_clk), 
        .i_rst_n(i_rst_n),
        .i_en(w_en_effective),
        .i_wdi(w_kick_signal),
        .i_clr_fault(w_clr_fault),
        .i_twd_ms(w_twd_ms), 
        .i_trst_ms(w_trst_ms),
        .i_arm_delay_us(w_arm_delay_us),
        .o_wdo(w_wdo), .o_enout(w_enout),
        .o_fault(w_fault_active)
    );
endmodule