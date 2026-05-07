module regfile (
    input i_clk,    // dau vao clk
    input i_rst_n,  // dau vao rst_n
    input [7:0] i_addr, // dau vao add
    input [31:0] i_wr_data, // dau vao write
    input i_wr_en,  // dau vao cho phep write
    input i_rd_en,  // dau vao cho phep read
    input i_cmd_kick,   // dau vao kick uart
    input [31:0] i_status,  // dau vao status

    output reg [31:0] o_rd_data,    // dau ra data
    output reg [31:0] o_ctrl,       // dau ra ctrl
    output reg [31:0] o_twd_ms,     // dau ra thoi gian watchog
    output reg [31:0] o_trst_ms,    // dau ra thoi gian rst
    output reg [15:0] o_arm_delay_us,   // dau ra arm_delay
    output reg o_uart_kick_p,     // dau ra kick uart
    output reg o_clr_fault       //  dau ra xoa loi
);
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_ctrl          <= 32'h0000_0001;  // EN_SW=1, WDI_SRC=0, CLR_FAULT=0
            o_twd_ms        <= 32'd1600;
            o_trst_ms       <= 32'd200;
            o_arm_delay_us  <= 16'd150;
            o_uart_kick_p   <= 1'b0;
            o_clr_fault     <= 1'b0;
        end else begin
            // UART kick 
            o_uart_kick_p <= i_cmd_kick;

            // xoa loi : write-1-to-clear  bit2 cua CTRL
            o_clr_fault <= (i_wr_en && i_addr == 8'h00 && i_wr_data[2]);

            if (i_wr_en) begin
                case (i_addr)
                    8'h00: o_ctrl <= {i_wr_data[31:3], 1'b0, i_wr_data[1:0]}; 
                    8'h04: o_twd_ms <= i_wr_data;
                    8'h08: o_trst_ms <= i_wr_data;
                    8'h0C: o_arm_delay_us <= i_wr_data[15:0];
                endcase
            end
        end
    end

    // Read data
    always @(*) begin
        case (i_addr)
            8'h00: o_rd_data = o_ctrl;
            8'h04: o_rd_data = o_twd_ms;
            8'h08: o_rd_data = o_trst_ms;
            8'h0C: o_rd_data = {16'h0, o_arm_delay_us};
            8'h10: o_rd_data = i_status;
            default: o_rd_data = 32'hFF;
        endcase
    end
endmodule