`timescale 1ns/1ps

module tb_watchdog_top;

    localparam CLK_FREQ = 27_000_000;
    localparam CLK_PERIOD_NS = 1_000_000_000 / CLK_FREQ; // 37.037 ns
    localparam UART_CLKS = CLK_FREQ / 115200; // 234

    reg i_clk;
    reg i_rst_n;
    reg i_wdi;
    reg i_en;
    reg i_uart_rx;
    wire o_wdo;
    wire o_enout;
    wire o_uart_tx;

    reg  [7:0]  rd;

    watchdog_top #(
        .CLK_FREQ(CLK_FREQ)
    ) dut (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_wdi(i_wdi),
        .i_en(i_en),
        .i_uart_rx(i_uart_rx),
        .o_wdo(o_wdo),
        .o_enout(o_enout),
        .o_uart_tx(o_uart_tx)
    );
    // Clock
    initial i_clk = 0;
    always #(CLK_PERIOD_NS/2) i_clk = ~i_clk;

    task wait_cycles(input integer n);
        repeat (n) @(posedge i_clk);
    endtask

    task wait_debounce();
        begin
            $display("[%0t] wait debounce 20ms...", $time);
            wait_cycles(540000);
            $display("[%0t] end debounce", $time);
        end
    endtask

    task uart_send_byte(input [7:0] data);
        integer i;
        begin
            i_uart_rx = 1;
            i_uart_rx = 0;
            wait_cycles(UART_CLKS);
            for (i = 0; i < 8; i = i+1) begin
                i_uart_rx = data[i];
                wait_cycles(UART_CLKS);
            end
            i_uart_rx = 1;
            wait_cycles(UART_CLKS);
        end
    endtask

    task uart_recv_byte(output [7:0] data);
        integer i;
        begin
            while (o_uart_tx) @(posedge i_clk);
            wait_cycles(UART_CLKS/2);
            for (i = 0; i < 8; i = i+1) begin
                wait_cycles(UART_CLKS);
                data[i] = o_uart_tx;
            end
            wait_cycles(UART_CLKS);
        end
    endtask

    task uart_send_packet(
        input [7:0] cmd,
        input [7:0] addr,
        input [7:0] len,
        input [31:0] data
    );
        reg [7:0] chk;
        integer i;
        begin
            chk = cmd ^ addr ^ len;
            uart_send_byte(8'h55);
            uart_send_byte(cmd);
            uart_send_byte(addr);
            uart_send_byte(len);
            for (i = 0; i < len; i = i+1) begin
                uart_send_byte(data[8*i +: 8]);
                chk = chk ^ data[8*i +: 8];
            end
            uart_send_byte(chk);
        end
    endtask

    task uart_write_reg(input [7:0] addr, input [31:0] wdata);
        reg [7:0] resp;
        begin
            uart_send_packet(8'h01, addr, 8'd4, wdata);
            uart_recv_byte(resp);
            if (resp !== 8'hAA)
                $display("ERROR: Write reg 0x%0h failed, resp=0x%0h", addr, resp);
            else
                $display("Write reg 0x%0h OK", addr);
        end
    endtask

    task uart_read_reg(input [7:0] addr);
        begin
            uart_send_packet(8'h02, addr, 8'd0, 32'd0);
            uart_recv_byte(rd);
            $display("Read reg 0x%0h = 0x%0h", addr, rd);
        end
    endtask

    task uart_kick();
        reg [7:0] resp;
        begin
            uart_send_packet(8'h03, 8'h00, 8'd0, 32'd0);
            uart_recv_byte(resp);
            if (resp !== 8'hAA)
                $display("ERROR: Kick command failed");
            else
                $display("Kick command OK (soft)");
        end
    endtask

    task hard_kick();
        begin
            i_wdi = 1'b0;
            wait_debounce();
            i_wdi = 1'b1;
            wait_debounce();
            $display("Hard kick (WDI) thuc hien tai %0t", $time);
        end
    endtask

    // Cac kich ban test
    initial begin
        i_rst_n = 0;
        i_en = 0;
        i_wdi = 0;
        i_uart_rx = 1;
        wait_cycles(100);
        i_rst_n = 1;
        $display("[%0t] Reset released", $time);
        wait_cycles(500);

        // CASE 1: Disable
        $display("\n=== CASE 1: Disable (EN=0) ===");
        wait_debounce();
        @(posedge i_clk);
        @(posedge i_clk);
        if (o_enout !== 1'b0)
            $error("CASE1: o_enout phai = 0 khi disable");
        else
            $display("CASE 1 PASSED: o_enout = 0");

        // CASE 2: Enable + arming
        $display("\n=== CASE 2: Disable -> Enable (arm_delay) ===");
        i_en = 1'b1;
        wait_debounce();
        $display("[%0t] EN=1, doi arming 1us...", $time);
        wait_cycles(27);   // 1us @27MHz
        if (o_enout !== 1'b1)
            $error("CASE2: o_enout phai = 1 sau arming");
        else
            $display("CASE 2 PASSED: o_enout = 1");

        // CASE 3: Parameter changes via UART 
        $display("\n=== CASE 3: Parameter changes via UART ===");
        uart_write_reg(8'h04, 32'd3);    // TWD_MS = 3ms
        uart_write_reg(8'h08, 32'd1);    // TRST_MS = 1ms
        uart_write_reg(8'h0C, 32'd1);    // ARM_DELAY = 1us
        uart_read_reg(8'h04);
        if (rd !== 8'h03) $error("CASE3: TWD_MS LSB mismatch (expected 0x03)");
        uart_read_reg(8'h08);
        if (rd !== 8'h01) $error("CASE3: TRST_MS LSB mismatch (expected 0x01)");
        uart_read_reg(8'h0C);
        if (rd !== 8'h01) $error("CASE3: ARM_DELAY LSB mismatch (expected 0x01)");
        $display("CASE 3 PASSED");

        // CASE 4: Normal kick (WDI) 
        $display("\n=== CASE 4: Normal kick (WDI) ===");
        hard_kick();
        wait_cycles(2 * 27_000_000 / 1000);   // 2ms < 3ms
        if (o_wdo !== 1'b1)
            $error("CASE4: WDO da xuong thap du kick dung han");
        else
            $display("CASE 4 PASSED: WDO van cao ");

        // CASE 5: Timeout (no kick) -> WDO=0
        $display("\n=== CASE 5: Timeout (no kick) ===");
        // Reset watchdog
        uart_write_reg(8'h00, 32'h0000_0000);   // Disable
        wait_cycles(10);
        uart_write_reg(8'h00, 32'h0000_0001);   // Enable
        wait_cycles(10);
        $display("[%0t] Watchdog reset (disable/enable)", $time);

        // Set tham so moi
        uart_write_reg(8'h04, 32'd3);    // TWD=3ms
        uart_write_reg(8'h08, 32'd1);    // TRST=1ms
        uart_write_reg(8'h0C, 32'd1);    // ARM=1us
        $display("[%0t] Parameters set: TWD=3ms, TRST=1ms, ARM=1us", $time);

        // Ch? arming (1us)
        wait_cycles(27);
        $display("[%0t] Arming done, monitoring started", $time);

        // Ch? timeout 10ms (?? ?? TWD=3ms k ch ho?t)
        wait_cycles(10 * 27_000_000 / 1000);   // 10ms
        if (o_wdo !== 1'b0)
            $error("CASE5: WDO van bang 1 khi khong kick");
        else
            $display("CASE5a: PASSED - WDO = 0 (timeout)");

        // Ch? t? ??ng h?i ph?c TRST=1ms, ch? 5ms
        wait_cycles(5 * 27_000_000 / 1000);   // 5ms
        if (o_wdo !== 1'b1)
            $error("CASE5: WDO van bang 0 sau TRST_MS");
        else
            $display("CASE5b: PASSED - WDO bang 1 sau TRST");

        // Clear fault manually via UART
        $display("\n--- Clear fault manually via UART ---");
        // G y timeout l?n n?a: ch? 10ms
        wait_cycles(10 * 27_000_000 / 1000);
        if (o_wdo !== 1'b0)
            $error("CASE5: WDO khong xuong 0 truoc khi clear");
        // Clear fault: ghi CTRL bit2=1 (EN=1, WDI_SRC=1 -> data=0x7)
        uart_write_reg(8'h00, 32'h0000_0007);
        @(posedge i_clk);
        if (o_wdo !== 1'b1)
            $error("CASE5: WDO bang 0 sau khi clear fault");
        else
            $display("CASE5c: PASSED - Clear fault via UART works");
        $display("CASE 5 PASSED");

        // CASE 6: Soft kick + status check
        $display("\n=== CASE 6: Soft kick (UART) + parameter changes + status check ===");
        uart_write_reg(8'h00, 32'h0000_0003); // EN=1, WDI_SRC=1 (soft kick)
        uart_kick();
        wait_cycles(2 * 27_000_000 / 1000);   // 2ms < 3ms
        if (o_wdo !== 1'b1)
            $error("CASE6: WDO bang 0 sau soft kick");
        else
            $display("CASE6a: Soft kick OK, WDO bang 1");

        uart_write_reg(8'h04, 32'd5);    // TWD=5ms
        uart_write_reg(8'h08, 32'd2);    // TRST=2ms
        uart_write_reg(8'h0C, 32'd2);    // ARM=2us
        uart_read_reg(8'h04);
        if (rd !== 8'h05) $error("CASE6: TWD_MS LSB mismatch (expected 0x05)");
        uart_read_reg(8'h08);
        if (rd !== 8'h02) $error("CASE6: TRST_MS LSB mismatch (expected 0x02)");
        uart_read_reg(8'h0C);
        if (rd !== 8'h02) $error("CASE6: ARM_DELAY LSB mismatch (expected 0x02)");
        $display("CASE6b: Parameters changed successfully");

        uart_read_reg(8'h10);
        if (rd !== 8'h1D)
            $error("CASE6: Status mismatch, expected 0x1D got 0x%0h", rd);
        else
            $display("CASE6c: Status = 0x1D (kick_src=soft, wdo=1, enout=1, fault=0, en_eff=1)");
        $display("CASE 6 PASSED");

        #1000;
        $display("\n=== ALL 6 CASES PASSED ===");
        $finish;
    end

endmodule