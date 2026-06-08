# Báo cáo Dự án: UVM Testbench kiểm thử Synchronous FIFO

> **Tài liệu hồ sơ thực tập – Thiết kế & Kiểm chứng Vi mạch số (Design Verification)**

## Mục lục

1. Giới thiệu & Mục tiêu
2. Mô tả hệ thống cần kiểm thử (DUT)
3. Kiến trúc UVM Testbench
4. Mô tả chi tiết các thành phần UVM
5. Chiến lược & Danh sách Testcase
6. Hướng dẫn biên dịch và chạy
7. Kết quả kiểm thử dự kiến
8. Độ phủ (Coverage) & Hướng mở rộng
9. Cấu trúc thư mục dự án

---

## 1. Giới thiệu & Mục tiêu

Dự án xây dựng một môi trường kiểm chứng chức năng (functional verification) hoàn chỉnh dựa trên **UVM (Universal Verification Methodology)** cho một module **FIFO đồng bộ (Synchronous FIFO)**. FIFO là khối nhớ đệm phổ biến trong hầu hết các hệ thống số (giao tiếp giữa hai miền tốc độ khác nhau, đệm dữ liệu giữa producer-consumer), do đó nó là đối tượng lý tưởng để minh họa đầy đủ các thành phần và kỹ thuật của UVM.

**Mục tiêu cụ thể:**

- Xây dựng testbench UVM phân lớp, tái sử dụng được, gồm đầy đủ: `sequence_item`, `sequencer`, `driver`, `monitor`, `agent`, `scoreboard`, `environment`, và `test`.
- Kiểm thử **chức năng**: đảm bảo dữ liệu ghi vào được đọc ra đúng thứ tự FIFO (First-In-First-Out).
- Kiểm thử **hiệu năng**: ghi/đọc ngẫu nhiên liên tục với khối lượng lớn (200+ giao dịch).
- Kiểm thử **ngoại lệ**: phát hiện đúng tình huống `overflow` (ghi khi đầy) và `underflow` (đọc khi rỗng).
- Tự động so sánh kết quả bằng **scoreboard** với mô hình tham chiếu (reference model).

## 2. Mô tả hệ thống cần kiểm thử (DUT)

Module `sync_fifo` (file `fifo_dut.sv`) là FIFO đồng bộ tham số hóa.

| Tham số | Giá trị mặc định | Ý nghĩa |
|---|---|---|
| `WIDTH` | 8 | Độ rộng dữ liệu (bit) |
| `DEPTH` | 16 | Số ô nhớ |
| `AF_LVL` | DEPTH-2 | Ngưỡng cờ `almost_full` |
| `AE_LVL` | 2 | Ngưỡng cờ `almost_empty` |

**Cổng tín hiệu chính:**

| Tín hiệu | Hướng | Mô tả |
|---|---|---|
| `clk`, `rst_n` | input | Clock và reset tích cực thấp |
| `wr_en`, `rd_en` | input | Cho phép ghi / đọc |
| `din` / `dout` | in / out | Dữ liệu vào / ra |
| `full`, `empty` | output | Cờ đầy / rỗng |
| `almost_full`, `almost_empty` | output | Cờ gần đầy / gần rỗng |
| `overflow`, `underflow` | output | Báo lỗi ghi khi đầy / đọc khi rỗng |
| `count` | output | Số phần tử hiện có |

**Hành vi chính:** Ghi chỉ được thực hiện khi `wr_en=1 && !full`; đọc chỉ khi `rd_en=1 && !empty`. Con trỏ ghi/đọc và bộ đếm `cnt` được cập nhật đồng bộ theo clock. Cờ `overflow`/`underflow` được set một chu kỳ khi có yêu cầu ghi/đọc sai trạng thái.

## 3. Kiến trúc UVM Testbench

```
                ┌─────────────────────────────────────────┐
                │              tb_top (module)             │
                │   clk gen · reset · DUT · interface      │
                │   ┌───────────────────────────────────┐  │
                │   │        uvm_test (testcase)         │  │
                │   │   ┌─────────────────────────────┐  │  │
                │   │   │        fifo_env             │  │  │
                │   │   │  ┌──────────┐  ┌──────────┐ │  │  │
                │   │   │  │  agent   │  │scoreboard│ │  │  │
                │   │   │  │ ┌──────┐ │  │  (ref    │ │  │  │
   sequences ───┼───┼───┼──┼▶sqr   │ │  │  model)  │ │  │  │
                │   │   │  │ │ │    │ │  └────▲─────┘ │  │  │
                │   │   │  │ ▼ ▼    │ │       │ analysis│  │
                │   │   │  │ driver │ │       │  port   │  │
                │   │   │  │   │    │ │       │         │  │
                │   │   │  │   ▼    │ │  monitor───────┘  │  │
                │   │   │  └───┼────┴─┴───▲───┘         │  │  │
                │   │   └──────┼──────────┼─────────────┘  │  │
                │   └──────────┼──────────┼────────────────┘  │
                │         (virtual interface fifo_if)         │
                │              ▼          │                   │
                │            ┌──────────────┐                 │
                │            │  sync_fifo   │ (DUT)           │
                │            └──────────────┘                 │
                └─────────────────────────────────────────────┘
```

Driver lấy `fifo_item` từ sequencer và lái tín hiệu lên `virtual interface`. Monitor quan sát các tín hiệu trên cùng interface, đóng gói thành transaction và gửi qua `analysis port` tới scoreboard. Scoreboard duy trì một hàng đợi (queue) làm mô hình tham chiếu và so sánh dữ liệu đọc ra.


## 4. Mô tả chi tiết các thành phần UVM

**`fifo_item` (sequence item):** Đại diện một thao tác trên FIFO. Chứa trường `op` (WRITE/READ/BOTH/IDLE) và `din` được random hóa với ràng buộc phân bố. Các trường còn lại (`dout`, `full`, `empty`, `count`, `overflow`, `underflow`) do monitor điền khi quan sát.

**`fifo_sequencer`:** Định nghĩa bằng `typedef uvm_sequencer #(fifo_item)`, điều phối luồng transaction từ sequence tới driver.

**`fifo_driver`:** Lấy item qua `seq_item_port.get_next_item()`, dịch sang tín hiệu vật lý trên `drv_cb` (clocking block) theo loại `op`, sau đó hạ `wr_en`/`rd_en` và gọi `item_done()`.

**`fifo_monitor`:** Quan sát thụ động interface qua `mon_cb`. Mỗi khi có `wr_en` hoặc `rd_en`, nó đóng gói dữ liệu vào `fifo_item` mới và phát qua `uvm_analysis_port`.

**`fifo_scoreboard`:** Trái tim kiểm chứng. Dùng `uvm_analysis_imp` để nhận transaction. Duy trì một queue `ref_q` mô phỏng hành vi FIFO lý tưởng: khi ghi thì `push_back`, khi đọc thì `pop_front` và so sánh giá trị kỳ vọng với `dout` thực tế. Đếm các sự kiện PASS/FAIL/overflow/underflow và in tổng kết trong `report_phase`.

**`fifo_agent`:** Đóng gói sequencer + driver + monitor. Khi `UVM_ACTIVE` thì tạo cả ba; khi `UVM_PASSIVE` chỉ tạo monitor.

**`fifo_env`:** Chứa agent và scoreboard, đấu nối `agt.mon.ap` tới `scb.imp` trong `connect_phase`.

**Cơ chế truyền interface:** `tb_top` đăng ký virtual interface vào `uvm_config_db`; driver và monitor lấy ra bằng `get()`. Đây là cách chuẩn để tách biệt phần module tĩnh và phần class động của UVM.

## 5. Chiến lược & Danh sách Testcase

| # | Test | Loại | Mục đích | Tiêu chí PASS |
|---|---|---|---|---|
| TC1 | `fifo_smoke_test` | Chức năng | Ghi 8 phần tử rồi đọc 8 phần tử | Dữ liệu đọc đúng thứ tự FIFO, 0 lỗi |
| TC2 | `fifo_random_test` | Chức năng + Hiệu năng | 200 giao dịch ghi/đọc ngẫu nhiên | Mọi giá trị đọc khớp ref model |
| TC3 | `fifo_overflow_test` | Ngoại lệ | Ghi 40 lần (gấp 2.5× DEPTH) | Cờ `overflow` xuất hiện đúng lúc đầy, không mất/hỏng dữ liệu |
| TC4 | `fifo_underflow_test` | Ngoại lệ | Đọc 10 lần khi FIFO rỗng | Cờ `underflow` xuất hiện, không đọc rác |

**Cách chọn test khi chạy:** truyền tên test qua tham số dòng lệnh `+UVM_TESTNAME=<tên_test>`.

## 6. Hướng dẫn biên dịch và chạy

Cần cài đặt thư viện UVM 1.2 và một simulator hỗ trợ SystemVerilog (VCS / Questa / Xcelium). Thứ tự biên dịch theo file `run.f`.

**Synopsys VCS:**

```bash
vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps -f run.f -l comp.log
./simv +UVM_TESTNAME=fifo_random_test +UVM_VERBOSITY=UVM_LOW -l sim.log
```

**Mentor Questa:**

```bash
vlib work
vlog -sv +incdir+$UVM_HOME/src $UVM_HOME/src/uvm_pkg.sv -f run.f
vsim -c tb_top +UVM_TESTNAME=fifo_smoke_test -do "run -all; quit"
```

**Cadence Xcelium:**

```bash
xrun -uvm -sv -f run.f +UVM_TESTNAME=fifo_overflow_test
```

Thay đổi giá trị `+UVM_TESTNAME` để chạy lần lượt 4 testcase. File sóng `tb_top.vcd` được sinh ra để xem dạng sóng.

## 7. Kết quả kiểm thử dự kiến

Mỗi test kết thúc bằng tổng kết của scoreboard trong `report_phase`. Ví dụ log kỳ vọng cho `fifo_random_test`:

```
UVM_INFO ... [SCB] ================ KẾT QUẢ SCOREBOARD ================
UVM_INFO ... [SCB] Tổng ghi=104  đọc=96
UVM_INFO ... [SCB] PASS=96  FAIL=0
UVM_INFO ... [SCB] Overflow=5  Underflow=3
UVM_INFO ... [SCB] *** TEST PASSED ***
--- UVM Report Summary ---
UVM_ERROR :    0
UVM_FATAL :    0
```

**Tổng hợp kết quả kỳ vọng:**

| Test | UVM_ERROR | Kết luận | Hiện tượng quan sát |
|---|---|---|---|
| `fifo_smoke_test` | 0 | PASS | 8 giá trị đọc khớp đúng thứ tự ghi |
| `fifo_random_test` | 0 | PASS | Mọi `dout` khớp ref model, cờ trạng thái nhất quán với `count` |
| `fifo_overflow_test` | 0 | PASS | `overflow=1` khi `full=1` và còn `wr_en`; dữ liệu trong FIFO không bị ghi đè |
| `fifo_underflow_test` | 0 | PASS | `underflow=1` khi `empty=1` và còn `rd_en`; con trỏ đọc không tăng |

Tiêu chí PASS toàn dự án: `UVM_ERROR = 0` và `UVM_FATAL = 0` trên cả 4 test.

## 8. Độ phủ (Coverage) & Hướng mở rộng

Để hoàn thiện hồ sơ, có thể bổ sung:

- **Functional coverage**: covergroup theo dõi các bin của `count` (rỗng, gần rỗng, giữa, gần đầy, đầy), giao của `wr_en × rd_en`, và các sự kiện overflow/underflow.
- **Assertions (SVA)**: kiểm tra bất biến như "khi `full=1` thì `count==DEPTH`", "`dout` ổn định cho tới chu kỳ đọc kế tiếp".
- **Mở rộng DUT**: asynchronous FIFO (hai miền clock), FIFO có cơ chế first-word-fall-through.
- **Reset ngẫu nhiên giữa chừng** để kiểm thử khả năng phục hồi.

## 9. Cấu trúc thư mục dự án

```
fifo_uvm_project/
├── fifo_dut.sv         # DUT: module sync_fifo
├── fifo_if.sv          # Interface + clocking blocks
├── fifo_seq_pkg.sv     # sequence_item, sequencer, 6 sequences
├── fifo_env_pkg.sv     # driver, monitor, scoreboard, agent, env
├── fifo_test_pkg.sv    # base_test + 4 testcase
├── tb_top.sv           # top module: clk/reset/DUT/run_test
├── run.f               # file list + lệnh chạy
└── BAO_CAO_UVM.md      # tài liệu báo cáo này
```

---

*Báo cáo hoàn tất. Dự án thể hiện đầy đủ vòng đời kiểm chứng UVM: từ mô tả DUT, xây dựng các thành phần phân lớp, phát triển testcase đa dạng (chức năng/hiệu năng/ngoại lệ), đến tự động so sánh kết quả và tổng kết.*
