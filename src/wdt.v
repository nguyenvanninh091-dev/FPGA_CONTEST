module watchdog_core #(
    parameter CLK_FREQ = 27_000_000
)(
    input i_clk,    // dau vao clk
    input i_rst_n,  // dau vao rst_n
    input i_en, // dau vao en
    input i_wdi,    //dau vao wdi
    input i_clr_fault,  // dau vao clr fault
    input [31:0] i_twd_ms,  //dau vao thoi gian watchdog
    input [31:0] i_trst_ms, // dau vao thoi gian rst
    input [15:0] i_arm_delay_us,    //dau vao arm delay

    output reg o_wdo,   // dau ra wdo
    output reg o_enout, // dau ra enout
    output reg o_fault  // dau ra check fault
);
    localparam ST_IDLE       = 2'b00; 
    localparam ST_ARMING     = 2'b01;
    localparam ST_MONITORING = 2'b10;
    localparam ST_FAULT      = 2'b11;

    reg [1:0] r_state, r_next_state;
    reg [31:0] r_timer;
    reg [15:0] r_us_cnt;
    reg [9:0] r_ms_cnt;
    reg r_wdi_d;

    wire w_tick_us = (r_us_cnt == (CLK_FREQ / 1_000_000) - 1);  // 1 tick us
    wire w_tick_ms = w_tick_us && (r_ms_cnt == 999);    // 1 tick ms
    wire w_kick = r_wdi_d && !i_wdi;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_us_cnt <= 0;
            r_ms_cnt <= 0;
        end else begin
            r_us_cnt <= w_tick_us ? 0 : r_us_cnt + 1;
            if (w_tick_us) r_ms_cnt <= (r_ms_cnt == 999) ? 0 : r_ms_cnt + 1;
        end
    end

    always @(posedge i_clk) r_wdi_d <= i_wdi;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n || !i_en) begin
            r_state <= ST_IDLE;
            r_timer <= 0;
        end else begin
            r_state <= r_next_state;
            if (r_state != r_next_state || (r_state == ST_MONITORING && w_kick))
                r_timer <= 0;
            else if (w_tick_us && r_state == ST_ARMING)
                r_timer <= r_timer + 1;
            else if (w_tick_ms && (r_state == ST_MONITORING || r_state == ST_FAULT))
                r_timer <= r_timer + 1;
        end
    end

    always @(*) begin
        r_next_state = r_state;
        case (r_state)
            // trang thai nghi
            ST_IDLE: if (i_en) r_next_state = ST_ARMING;
            // trang thai doi arming khi moi bat en
            ST_ARMING: if (r_timer >= i_arm_delay_us) r_next_state = ST_MONITORING;
            // trang thai dem watchdog
            ST_MONITORING: if (r_timer >= i_twd_ms) r_next_state = ST_FAULT;
            // trang thai xuat hieu fault
            ST_FAULT: begin
                if (i_clr_fault)              
                    r_next_state = ST_MONITORING;
                else if (r_timer >= i_trst_ms)
                    r_next_state = ST_MONITORING;
            end
            default: r_next_state = ST_IDLE;
        endcase
    end

    always @(*) begin
        // gan dau ra cho watchdog
        o_wdo   = (r_state == ST_FAULT) ? 1'b0 : 1'b1;
        o_enout = (r_state == ST_IDLE) ? 1'b0 : 1'b1;
        o_fault = (r_state == ST_FAULT);
    end
endmodule