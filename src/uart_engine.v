module uart_engine (
    input i_clk,    // dau vao clk
    input i_rst_n,  // dau vao rst_n    
    input [7:0] i_rx_byte,  // dau vao data
    input i_rx_done,    // dau vao done nhan tu dau ra uart_rx
    input i_tx_ready,   // dau vao san sang nhan tu uart_tx
    input [31:0] i_rd_data, // dau vao doc data
    
    output reg [7:0] o_tx_byte, // dau ra data
    output reg o_tx_en, // dau ra cho phep gui data
    output reg [7:0]  o_addr,   // dau ra dia chi
    output reg [31:0] o_wr_data,    // dau ra write
    output reg o_wr_en, // dau ra cho pheo write
    output reg o_rd_en, // dau ra cho phep doc
    output reg o_cmd_kick   // dau ra kick
    
);
    reg [2:0] r_state;
    reg [7:0] r_cmd, r_len, r_chk_sum;
    reg [2:0] r_byte_cnt;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_state <= 0;
            o_wr_en <= 0; 
            o_rd_en <= 0; 
            o_cmd_kick <= 0;
            o_addr <= 0; 
            o_wr_data <= 0; 
            o_tx_en <= 0;
            o_tx_byte <= 0;
            r_cmd <= 0; 
            r_len <= 0; 
            r_chk_sum <= 0; 
            r_byte_cnt <= 0;
        end else begin
            o_wr_en <= 0; 
            o_rd_en <= 0;
            o_cmd_kick <= 0; 
            o_tx_en <= 0;
            
            case (r_state)
                // trang thai idle de check xem co tin hieu rx va header ko
                0: if (i_rx_done && i_rx_byte == 8'h55) r_state <= 1;
                // giu lai data cua cmd 
                1: if (i_rx_done) begin  
                        r_cmd <= i_rx_byte;
                        r_chk_sum <= i_rx_byte; // check sum lan luot
                        r_state <= 2; 
                   end 
                // giu lai data address
                2: if (i_rx_done) begin  
                        o_addr <= i_rx_byte;
                        r_chk_sum <= r_chk_sum ^ i_rx_byte; 
                        r_state <= 3; 
                   end 
                // giu lai data len
                3: if (i_rx_done) begin 
                        r_len <= i_rx_byte;
                        r_chk_sum <= r_chk_sum ^ i_rx_byte; 
                        r_byte_cnt <= 0; 
                        r_state <= (i_rx_byte == 0) ? 5 : 4;
                   end 
                // giu lai data(du lieu thuc cua rx)
                4: if (i_rx_done) begin 
                    case(r_byte_cnt)
                        // luu theo little endian
                        0: o_wr_data[7:0] <= i_rx_byte;
                        1: o_wr_data[15:8] <= i_rx_byte;
                        2: o_wr_data[23:16] <= i_rx_byte;
                        3: o_wr_data[31:24] <= i_rx_byte;
                    endcase
                    r_chk_sum <= r_chk_sum ^ i_rx_byte;
                    // dem du chieu dai chuoi thi chuyen trang thai
                    if (r_byte_cnt == r_len - 1) r_state <= 5;
                    else r_byte_cnt <= r_byte_cnt + 1;
                end
                // khi nhan xong data tu pc thi check cmd
                5: if (i_rx_done) begin 
                    if (i_rx_byte == r_chk_sum) begin
                        if (r_cmd == 8'h01) o_wr_en <= 1;
                        if (r_cmd == 8'h02 || r_cmd == 8'h04) o_rd_en <= 1;
                        if (r_cmd == 8'h03) o_cmd_kick <= 1;
                        r_state <= 6;
                    end else r_state <= 0;
                end
                // san sang gui data len regfile
                6: if (i_tx_ready) begin 
                    // neu lenh doc hoac lech check status thi tra ve 7 bit data con khong thi gui ve AA de bao hieu thanh cong
                    o_tx_byte <= (r_cmd == 8'h02 || r_cmd == 8'h04) ? i_rd_data[7:0] : 8'hAA;
                    o_tx_en <= 1;
                    r_state <= 0;
                end
            endcase
        end
    end
endmodule