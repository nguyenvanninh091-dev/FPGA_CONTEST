module uart_rx #(
    parameter CLK_FREQ = 27_000_000, 
    parameter BAUD_RATE = 115_200
) (
    input i_clk,    //dau vao clk
    input i_rst_n,  //dau vao rst_n
    input i_rx,     // dau vao data

    output reg [7:0] o_byte,    // dau ra data
    output reg o_done   //dau ra bao hieu done
);
    localparam WAIT = CLK_FREQ / BAUD_RATE;
    reg [15:0] r_clk_cnt;
    reg [3:0] r_bit_cnt;
    reg [1:0] r_state;
    reg r_sync_0, r_sync_1;
    //dong bo qua 2 ff
    always @(posedge i_clk) begin 
        r_sync_0 <= i_rx;
        r_sync_1 <= r_sync_0; 
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_state <= 0;
            r_clk_cnt <= 0; 
            r_bit_cnt <= 0; 
            o_byte <= 0; 
            o_done <= 0;
        end else begin
            o_done <= 1'b0;
            case (r_state)
                // cho tin hieu r_sync_1 xuong 1 
                0: begin
                    r_clk_cnt <= 0;
                    if (!r_sync_1) r_state <= 1;
                end
                // start bit
                1: begin
                    if (r_clk_cnt == WAIT/2) begin
                        if (!r_sync_1) begin 
                            r_clk_cnt <= 0; 
                            r_state <= 2; 
                            r_bit_cnt <= 0;
                        end else r_state <= 0;
                    end else r_clk_cnt <= r_clk_cnt + 1;
                end
                // data bits
                2: begin
                    if (r_clk_cnt == WAIT - 1) begin
                        r_clk_cnt <= 0;
                        o_byte[r_bit_cnt] <= r_sync_1;
                        if (r_bit_cnt == 7) r_state <= 3;
                        else r_bit_cnt <= r_bit_cnt + 1;
                    end else r_clk_cnt <= r_clk_cnt + 1;
                end
                // stop bit
                3: begin
                    if (r_clk_cnt == WAIT - 1) begin
                        o_done <= 1'b1;
                        r_state <= 0;
                    end else r_clk_cnt <= r_clk_cnt + 1;
                end
            endcase
        end
    end
endmodule