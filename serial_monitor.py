import sys
import time
import threading
import serial
import serial.tools.list_ports

BAUD_RATES = [9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600]
DEFAULT_BAUD = 115200

def list_com_ports():
    ports = serial.tools.list_ports.comports()
    if not ports:
        print("Không tìm thấy cổng COM nào.")
        return []
    print("Danh sách cổng COM khả dụng:")
    for i, p in enumerate(ports):
        print(f"  [{i}] {p.device} - {p.description}")
    return ports

def auto_choose_port(ports):
    if len(ports) == 1:
        return ports[0].device
    return None

def select_baud():
    print("Chọn baud rate (Enter để dùng mặc định 115200):")
    for i, b in enumerate(BAUD_RATES):
        print(f"  [{i}] {b}")
    choice = input("Chọn số: ").strip()
    if choice == "":
        return DEFAULT_BAUD
    try:
        idx = int(choice)
        if 0 <= idx < len(BAUD_RATES):
            return BAUD_RATES[idx]
    except:
        pass
    print("Lựa chọn không hợp lệ, dùng mặc định 115200.")
    return DEFAULT_BAUD

def serial_reader(ser, stop_event):
    """Luồng đọc dữ liệu từ cổng serial và in ra màn hình (chỉ hex)."""
    while not stop_event.is_set():
        try:
            if ser.in_waiting:
                data = ser.read(ser.in_waiting)
                hex_str = ' '.join(f'{b:02X}' for b in data)
                # In xuống dòng, không có phần ASCII
                print(f"\n<<< {hex_str}")
                # In lại prompt để người dùng biết có thể nhập tiếp
                print(">>> ", end='', flush=True)
            else:
                time.sleep(0.01)
        except serial.SerialException:
            print("\nMất kết nối serial!")
            stop_event.set()
            break
        except:
            break

def main():
    ports = list_com_ports()
    if not ports:
        input("Nhấn Enter để thoát...")
        return

    # Chọn cổng
    auto_port = auto_choose_port(ports)
    if auto_port:
        print(f"Tự động chọn cổng duy nhất: {auto_port}")
        port = auto_port
    else:
        port = input("Nhập tên cổng (vd: COM3, /dev/ttyUSB0): ").strip()
        if not port:
            print("Không chọn cổng, thoát.")
            return

    baud = select_baud()

    try:
        ser = serial.Serial(port, baud, timeout=0.1)
    except Exception as e:
        print(f"Không thể mở cổng {port}: {e}")
        input("Nhấn Enter để thoát...")
        return

    print(f"Đã kết nối {port} @ {baud} baud.")
    print("Nhập dữ liệu để gửi (hỗ trợ hex hoặc text).")
    print("  Hex:  55 01 04 00 00 00 00 B8? (dấu cách hoặc liền)")
    print("  Text: hello world (gửi dạng ASCII)")
    print("  Gõ 'exit' hoặc Ctrl+C để thoát.\n")

    stop_event = threading.Event()
    reader_thread = threading.Thread(target=serial_reader, args=(ser, stop_event), daemon=True)
    reader_thread.start()

    try:
        while True:
            cmd = input(">>> ").strip()
            if cmd.lower() == 'exit':
                break
            if not cmd:
                continue
            # Xác định hex hay text
            is_hex = False
            test_str = cmd.replace(' ', '')
            if all(c in '0123456789abcdefABCDEF' for c in test_str) and len(test_str) > 0:
                is_hex = True
            try:
                if is_hex:
                    hex_str = cmd.replace(' ', '')
                    if len(hex_str) % 2 != 0:
                        print("Chuỗi hex lẻ, bỏ qua.")
                        continue
                    data = bytes.fromhex(hex_str)
                else:
                    data = cmd.encode('ascii')
                ser.write(data)
                sent_hex = data.hex(' ').upper()
                print(f"Đã gửi {len(data)} byte(s): {sent_hex}")
            except Exception as e:
                print(f"Lỗi khi gửi: {e}")
    except KeyboardInterrupt:
        print("\nThoát...")
    finally:
        stop_event.set()
        reader_thread.join(timeout=1)
        ser.close()
        print("Đã ngắt kết nối.")

if __name__ == "__main__":
    main()