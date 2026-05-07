module uart #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUD_RATE = 115_200
)(
    input i_clk,    // dau vao clk
    input i_rst_n,  // dau vao rst_n
    input i_rx,     // dau vao data
    input [31:0] i_rd_data, // dau vao doc data

    output o_tx,    // dau ra data
    output [7:0]  o_addr,   // dau ra dia chi
    output [31:0] o_wr_data,    // dau ra write
    output o_wr_en, // dau ra cho phep write
    output o_rd_en, // dau ra cho phep read
    output o_cmd_kick   // dau ra kick
    
);
    wire [7:0] w_rx_byte;
    wire w_rx_done;
    wire [7:0] w_tx_byte;
    wire w_tx_en;
    wire w_tx_ready;

    uart_rx #(
        .CLK_FREQ(CLK_FREQ), 
        .BAUD_RATE(BAUD_RATE)
    ) rx1 (
        .i_clk(i_clk), 
        .i_rst_n(i_rst_n), 
        .i_rx(i_rx),
        .o_byte(w_rx_byte), 
        .o_done(w_rx_done)
    );

    uart_engine engine1 (
        .i_clk(i_clk), 
        .i_rst_n(i_rst_n),
        .i_rx_byte(w_rx_byte), 
        .i_rx_done(w_rx_done),
        .o_tx_byte(w_tx_byte), 
        .o_tx_en(w_tx_en), 
        .i_tx_ready(w_tx_ready),
        .o_addr(o_addr), 
        .o_wr_data(o_wr_data), 
        .o_wr_en(o_wr_en),
        .o_rd_en(o_rd_en), 
        .o_cmd_kick(o_cmd_kick), 
        .i_rd_data(i_rd_data)
    );

    uart_tx #(
        .CLK_FREQ(CLK_FREQ), 
        .BAUD_RATE(BAUD_RATE)
    ) tx1 (
        .i_clk(i_clk), 
        .i_rst_n(i_rst_n), 
        .o_tx(o_tx),
        .i_byte(w_tx_byte), 
        .i_en(w_tx_en), 
        .o_ready(w_tx_ready)
    );
endmodule