module sync_debounce #(
    parameter CLK_FREQ = 27_000_000,
    parameter DEBOUNCE_MS = 20       
)(
    input i_clk, // dau vao clk
    input i_rst_n,  // dau vao rst_n
    input i_async,  // dau vao bat dong bo (nut nhan)
  
    output reg o_debounced // dau ra 
);
    reg r_sync_0, r_sync_1;
    localparam CNT_MAX = (CLK_FREQ / 1000) * DEBOUNCE_MS; 
    reg [23:0] r_timer; // reg luu bien dem den 20ms
    reg r_last_state;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_sync_0 <= 1'b1;
            r_sync_1 <= 1'b1;
        end else begin
            r_sync_0 <= i_async;
            r_sync_1 <= r_sync_0;
        end
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_timer <= 0;
            r_last_state <= 1'b1;
            o_debounced <= 1'b1;
        end else begin
            if (r_sync_1 != r_last_state) begin
                r_timer <= 0;
                r_last_state <= r_sync_1;
            end else begin
                // dem khi nao lon hon 20ms thi moi gan output cho trang thai nhan
                if (r_timer < CNT_MAX) begin
                    r_timer <= r_timer + 1;
                end else begin
                    o_debounced <= r_last_state;
                end
            end
        end
    end
endmodule