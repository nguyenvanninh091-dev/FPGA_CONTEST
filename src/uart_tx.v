module uart_tx #(
    parameter CLK_FREQ = 27_000_000, 
    parameter BAUD_RATE = 115_200
)(
    input i_clk,    //dau vao clk
    input i_rst_n,  // dau vao rst_n
    input [7:0] i_byte, //dau bao data
    input i_en, //dau vao en

    output o_tx,    //dau ra data
    output o_ready  
);
    localparam WAIT = CLK_FREQ / BAUD_RATE; // thoi gian 1 bit
    reg [15:0] r_clk_cnt;
    reg [3:0] r_bit_cnt;
    reg [7:0] r_data;
    reg [1:0] r_state;
    reg r_tx_reg;

    assign o_tx = r_tx_reg;
    assign o_ready = (r_state == 2'd0);

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_state <= 2'd0;
            r_tx_reg <= 1'b1;
            r_clk_cnt <= 16'd0;
            r_bit_cnt <= 4'd0;
            r_data <= 8'd0;
        end else begin
            case (r_state)
                // trang thai idle (rx = 1)
                2'd0: begin 
                    r_tx_reg <= 1'b1;
                    if (i_en) begin 
                        r_data <= i_byte;
                        r_state <= 2'd1; 
                        r_clk_cnt <= 0; 
                    end 
                end
                // start bit
                2'd1: begin
                    r_tx_reg <= 1'b0;
                    if (r_clk_cnt < WAIT) r_clk_cnt <= r_clk_cnt + 1;
                    else begin 
                        r_state <= 2'd2; 
                        r_clk_cnt <= 0; 
                        r_bit_cnt <= 0;
                    end 
                end
                // data bits
                2'd2: begin
                    r_tx_reg <= r_data[r_bit_cnt]; // gui lsb truoc
                    if (r_clk_cnt < WAIT) r_clk_cnt <= r_clk_cnt + 1;
                    else begin 
                        r_clk_cnt <= 0;
                        if (r_bit_cnt == 7) r_state <= 2'd3; // du 8 bit thi stop
                        else r_bit_cnt <= r_bit_cnt + 1;
                    end 
                end
                // stop bit
                2'd3: begin
                    r_tx_reg <= 1'b1;
                    if (r_clk_cnt < WAIT) r_clk_cnt <= r_clk_cnt + 1;
                    else r_state <= 2'd0;
                end
                default: r_state <= 2'd0;
            endcase
        end
    end
endmodule