# Dự án Watchdog Monitor (TPS3431-like) — FPGA Extended Contest 2026

## Tổng quan
Triển khai RTL cho bộ giám sát Watchdog tương tự TPS3431 trên board Kiwi 1P5 (Gowin GW1N-UV1P5QN48XF, thạch anh 27 MHz). Hệ thống hỗ trợ cấu hình tham số thời gian thực qua UART (115200 bps, 8N1). Toàn bộ chức năng đã được xác thực trên phần cứng.

## 1. Kiến trúc RTL

Sơ đồ khối hệ thống:
```text
S1 (Kick) ────► [Debounce] ───┐      ┌───────────────┐      ┌──────────┐
                              ├────► │               │ ────►│ D3 (WDO) │
S2 (Enable) ──► [Debounce] ───┤      │ Watchdog Core │      └──────────┘
                              │      │               │      ┌──────────┐
UART_RX ──────► [Engine] ─────┼────► │ (Regfile)     │ ────►│ D4 (ENOUT)
                              │      └───────────────┘      └──────────┘
UART_TX ◄────── [Engine] ─────┘
```
S1 (Kick)   ──► [Debounce] ──┐      ┌───────────────┐      ┌──────────┐
                             ├────► │               │ ────►│ D3 (WDO) │
S2 (Enable) ──► [Debounce] ──┤      │ Watchdog Core │      └──────────┘
                             │      │               │      ┌──────────┐
UART_RX     ──► [Engine]   ──┼────► │   (Regfile)   │ ────►│ D4 (ENOUT)
                             │      └───────────────┘      └──────────┘
UART_TX     ◄── [Engine]   ──┘

### Module chức năng

| Tên Module | Vai trò chính |
| :--- | :--- |
| **watchdog_top** | Kết nối toàn bộ module. Quản lý reset hệ thống. |
| **sync_debounce** | Đồng bộ 2-FF chống trạng thái bất định + Khử rung (debounce) 20ms. |
| **watchdog_core** | Lõi xử lý chính với FSM (IDLE/ARMING/MONITOR/FAULT) và bộ tạo tick us/ms. |
| **regfile** | Hệ thống thanh ghi cấu hình (CTRL, tWD, tRST, arm_delay, STATUS). |
| **uart_rx/tx** | Bộ truyền/nhận UART chuẩn 115200 8N1. |
| **uart_engine** | Giải mã khung tin, kiểm tra XOR checksum và điều khiển thanh ghi. |

## 2. Máy trạng thái (FSM)

| Trạng thái | Mô tả |
| :--- | :--- |
| **IDLE** | EN=0. Watchdog tắt, bỏ qua WDI, ENOUT=0, WDO ở mức cao. |
| **ARMING** | EN chuyển từ 0 lên 1. Chờ hết thời gian arm_delay_us. Bỏ qua WDI. |
| **MONITORING** | Watchdog đang chạy. Mỗi cạnh xuống của WDI sẽ reset bộ đếm tWD. |
| **FAULT** | tWD hết hạn mà không có kick. WDO kéo xuống thấp trong tRST_ms. |

## 3. Sơ đồ chân Kiwi 1P5

| Chức năng | Nguồn trên Board | Chân FPGA | Ghi chú |
| :--- | :--- | :--- | :--- |
| **Clock** | Thạch anh (27MHz) | 4 | Xung nhịp hệ thống (27 MHz). |
| **WDI (Kick)** | Nút nhấn S1 | 35 | Reset timer tại cạnh xuống. |
| **EN** | Nút nhấn S2 | 36 | Active-high (Hệ thống bật khi mức logic là 1). |
| **WDO** | LED D3 | 27 | Active-low (LED tắt khi phát hiện lỗi/Timeout). |
| **ENOUT** | LED D4 | 28 | Active-high (LED sáng khi Watchdog đã sẵn sàng). |
| **UART RX** | GWU2U USB-UART | 33 | Nhận lệnh từ PC. |
| **UART TX** | GWU2U USB-UART | 34 | Phản hồi trạng thái về PC. |

## 4. Trạng thái LED

Sơ đồ tại board: `pin -> R330 -> LED -> GND`

| Linh kiện | Trạng thái LED | Ý nghĩa kỹ thuật |
| :--- | :--- | :--- |
| **LED D3 (WDO)** | TẮT | Đang xảy ra lỗi (Fault) - Tín hiệu WDO về mức 0. |
| **LED D4 (ENOUT)** | SÁNG | Watchdog đã bật và sẵn sàng. |

## 5. Mô phỏng Open-Drain

| Chi tiết triển khai kỹ thuật |
| :--- |
| - WDO và ENOUT sử dụng chuẩn đầu ra push-pull tiêu chuẩn của FPGA. |
| - Bên trong lõi xử lý, WDO tuân theo quy ước active-low (mức 0 khi có lỗi). |
| - Tín hiệu được nối trực tiếp ra chân FPGA (Pin 27 và 28) mà không qua bộ đảo. |
| - Kết quả: LED D3 sẽ SÁNG khi hệ thống bình thường và TẮT khi phát hiện lỗi. |

## 6. Cấu hình UART

**Thông số thiết lập:**

| Thông số | Giá trị thiết lập |
| :--- | :--- |
| **Baudrate** | 115200 bps |
| **Data bits** | 8-bit |
| **Stop bits** | 1-bit |

**Khung truyền:**

| Byte | Tên | Giá trị | Mô tả chi tiết |
| :--- | :--- | :--- | :--- |
| 1 | **Header** | 0x55 | Byte bắt đầu để đồng bộ khung tin. |
| 2 | **CMD** | 1 byte | Mã lệnh điều khiển. |
| 3 | **ADDR** | 1 byte | Địa chỉ thanh ghi đích. |
| 4 | **LEN** | 1 byte | Số lượng byte dữ liệu (0, 1, 2, 3 hoặc 4). |
| 5..N | **DATA** | 0-4 bytes | Dữ liệu thực tế (Chỉ có khi LEN > 0). |
| N+1 | **CHK** | 1 byte | Checksum: XOR từ byte CMD đến hết byte DATA cuối. |

## 7. Thanh ghi

| Địa chỉ | Tên | R/W | Mô tả |
| :--- | :--- | :--- | :--- |
| 0x00 | **CTRL** | R/W | bit0: EN_SW, bit1: WDI_SRC, bit2: CLR_FAULT (W1C). |
| 0x04 | **tWD_ms** | R/W | Cấu hình thời gian timeout (ms). |
| 0x08 | **tRST_ms** | R/W | Cấu hình thời gian reset (ms). |
| 0x0C | **arm_delay_us** | R/W | Cấu hình độ trễ khởi động (us). |
| 0x10 | **STATUS** | R | Trạng thái: EN_EFF, FAULT, ENOUT, WDO, LAST_KICK_SRC. |

## 8. Lệnh UART

| Mã | Tên lệnh | Chức năng chi tiết |
| :--- | :--- | :--- |
| 0x01 | **WRITE_REG** | Ghi dữ liệu 32-bit vào thanh ghi (CTRL, tWD, tRST...). |
| 0x02 | **READ_REG** | Trả về giá trị 32-bit của thanh ghi tại địa chỉ yêu cầu. |
| 0x03 | **KICK** | Giả lập sự kiện S1 bằng phần mềm (Software Kick). |
| 0x04 | **GET_STATUS** | Đọc nhanh thanh ghi STATUS (0x10) để kiểm tra trạng thái. |

**Ví dụ các câu lệnh:**

| Lệnh | Mô tả ví dụ | Chuỗi HEX gửi từ PC | Kết quả phản hồi từ FPGA |
| :--- | :--- | :--- | :--- |
| **BẬT** | Kích hoạt EN qua SW | `55 01 00 04 01 00 00 00 04` | 0xAA (Xác nhận Ghi) |
| **TẮT** | Vô hiệu hóa EN qua SW | `55 01 00 04 00 00 00 00 05` | 0xAA (Xác nhận Ghi) |
| **KICK MỀM** | Chuyển sang Kick bằng PC | `55 01 00 04 03 00 00 00 06` | 0xAA (Xác nhận Ghi) |
| **KICK** | Thực hiện lệnh Kick | `55 03 00 00 03` | 0xAA (Xác nhận Kick) |
| **STATUS** | Đọc trạng thái hiện tại | `55 04 10 00 14` | 4 byte (Dữ liệu Status) |
| **WRITE tWD** | Ghi tWD = 1600ms | `55 01 04 04 40 06 00 00 23` | 0xAA (Xác nhận Ghi) |
| **READ tWD** | Đọc giá trị tWD | `55 02 04 00 06` | 4 byte (Giá trị tWD) |

## 9. Hướng dẫn sử dụng

1. **Mở phần mềm:** Khởi động **Gowin FPGA Designer** (GOWIN EDA).
2. **Thiết lập Project:** Tạo project mới cho đúng dòng chip **GW1N-UV1P5QN48XFC7/I6**.
3. **Thêm mã nguồn:** Thêm toàn bộ 8 file .v: `top.v`, `watchdog_core.v`, `regfile.v`, `uart.v`, `uart_rx.v`, `uart_tx.v`, `uart_engine.v` và `debounce.v`.
4. **Thêm file ràng buộc:**
   - Thêm `wdt.cst` (Physical Constraints) để định nghĩa chân nút nhấn, LED, UART.
   - Thêm `wdt.sdc` (Timing Constraints) để định nghĩa xung nhịp 27MHz.
5. **Lưu ý về mô phỏng:** Không thêm file testbench vào project khi thực hiện tổng hợp phần cứng.
6. **Cấu hình chân nạp:** Vào `Project -> Configuration -> Dual-Purpose Pin`: bật tùy chọn **"Use JTAG as regular IO"** (quan trọng trên chip 1P5).
7. **Biên dịch:** Thực hiện trình tự `Synthesize` -> `Place & Route`.
8. **Nạp code:** Sử dụng **Gowin Programmer** để nạp file `.fs` vào board (chế độ SRAM hoặc embFlash tùy nhu cầu).

## 10. Hướng dẫn chạy Demo
1. Kết nối phần cứng: Cắm cáp USB vào cổng UART (sử dụng chip GWU2U, không phải cổng nạp JTAG) trên board Kiwi 1P5.
2. Cài đặt Driver: Đảm bảo máy tính đã nhận diện cổng COM (Cài đặt driver cho chip GWU2U nếu cần thiết).
3. Cài đặt thư viện: Sử dụng Python và cài đặt thư viện pyserial để hỗ trợ giao tiếp Serial: `pip install pyserial`
4. Chạy Script kiểm thử: Sử dụng tệp serial_monitor.py để bắt đầu giao tiếp với FPGA (Lưu ý thay đổi cổng COM tương ứng với máy của bạn):
```bash
python serial_monitor.py
```
5. Script tự động liệt kê các cổng COM. Bạn chỉ cần chọn số thứ tự tương ứng với board sau đó chọn baudrate
6. Nhấn giữ nút S2 (Enable) trên board sẽ thấy led tắt
7. Quan sát trạng thái Timeout tự động. (Nếu ko kick thì sau 1.6s thì thấy led tắt rồi lại sáng)
8. Thử nghiệm tính năng KICK từ script. (Led D3 sẽ duy trì sáng)
9. Thay đổi tham số hệ thống. (Phản hồi AA về PC )

## 11. Mô phỏng
# Dùng ModelSim
vsim work.tb_watchdog_top
run -all

## 12. Github

link : https://github.com/nguyenvanninh091-dev/FPGA_CONTEST.git
