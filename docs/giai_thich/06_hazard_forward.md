# Hazard và forwarding (`rtl/core/hazard_unit.sv`, `forward_unit.sv`)

## Ba loại hazard

| Loại | Ví dụ | Xử lý |
|---|---|---|
| Dữ liệu (RAW) | `add x5,..` rồi `sub x6,x5,..` | forward, hoặc stall khi dữ liệu chưa có |
| Điều khiển | nhánh, JAL/JALR, trap | dự đoán + flush khi sai |
| Cấu trúc | MulDiv đang chia, MEM chờ bus | stall các tầng phía trước |

## Forwarding

| Nguồn | Khi nào dùng | Ghi chú |
|---|---|---|
| `ex_mem` | lệnh ở MEM ghi `rd = rs` và **không phải load/CSR** | kết quả ALU/MulDiv/link đã có từ EX |
| `mem_wb` | lệnh ở WB ghi `rd = rs` | mọi loại kết quả |
| regfile | còn lại | write-through lo trường hợp WB ghi cùng chu kỳ ID đọc |

**Vì sao `ex_mem` ưu tiên hơn `mem_wb`?** Nếu cả hai lệnh ở MEM và WB cùng ghi một thanh ghi, lệnh ở MEM là lệnh
**trẻ hơn** – theo thứ tự chương trình, giá trị của nó ghi đè giá trị của lệnh ở WB. Ví dụ:

```
addi x5, x0, 1     # ở WB
addi x5, x0, 2     # ở MEM
add  x6, x5, x5    # ở EX: phải dùng 2, không phải 1
```

**Vì sao không forward load/CSR từ `ex_mem`?** Dữ liệu load chỉ có ở cuối MEM (sau khi đọc bus) – nếu nối thẳng
vào ALU ở EX sẽ tạo đường tổ hợp dài bus → ALU → so sánh nhánh. Thay vào đó stall 1 chu kỳ.

## Stall và bubble

```
load_use  = lệnh ở EX là load/CSR, rd ≠ 0, rd trùng rs mà lệnh ở ID thực sự dùng
stall_mem = bus_wait
stall_ex  = bus_wait || md_stall
stall_id  = stall_ex || load_use
stall_if  = stall_id
```

Bubble được chèn ngay sau tầng cuối cùng bị stall: load-use → bubble vào EX (`flush_id_ex`); MulDiv → bubble vào MEM;
chờ bus → bubble vào WB. Flush (do redirect) luôn thắng stall.

## Ví dụ load-use

| Chu kỳ | IF | ID | EX | MEM | WB |
|---|---|---|---|---|---|
| t | I3 | `add x6,x5,x1` | `lw x5,0(a0)` | | |
| t+1 | I3 | `add` (giữ) | bubble | `lw` | |
| t+2 | I4 | I3 | `add` (forward từ `mem_wb`) | bubble | `lw` |

Mất đúng 1 chu kỳ; counter `mhpmcounter7` đếm chu kỳ này.

## Quy tắc ưu tiên

`trap/mret/fence.i (MEM) > sai dự đoán (EX) > redirect (ID)`; redirect chỉ phát khi tầng của nó không bị stall
(đảm bảo "đúng một lần"). Flush trong lúc bộ chia đang chạy sẽ hủy bộ chia (`kill`).
