# Bảng pipeline theo chu kỳ – walkthrough

Sinh tự động bởi `scripts/make_waves.py` từ VCD của `sw/examples/walkthrough/walk.S` trên `m1c1_bp2`. Giá trị lấy ngay sau cạnh lên của mỗi chu kỳ. "rs ← ex_mem/mem_wb" là lựa chọn của bộ forward cho lệnh ở EX (hiển thị cả khi lệnh không dùng toán hạng đó, ví dụ `lui`).

| Chu kỳ | IF | ID | EX | MEM | WB | Sự kiện |
|---|---|---|---|---|---|---|
| 0 | `8000013e` lui a1,0x10002 | `8000013a` addi a0,a0,1810 | `80000136` auipc a0,0x0 | `80000132` csrrw zero,mie,t0 | `80000130` c.li t0,8 |  |
| 1 | `80000142` c.addi a1,20 | `8000013e` lui a1,0x10002 | `8000013a` addi a0,a0,1810 | `80000136` auipc a0,0x0 | `80000132` csrrw zero,mie,t0 | rs1 ← ex_mem |
| 2 | `80000144` lw t0,0(a0) | `80000142` c.addi a1,20 | `8000013e` lui a1,0x10002 | `8000013a` addi a0,a0,1810 | `80000136` auipc a0,0x0 |  |
| 3 | `80000148` add t1,t0,t0 | `80000144` lw t0,0(a0) | `80000142` c.addi a1,20 | `8000013e` lui a1,0x10002 | `8000013a` addi a0,a0,1810 | rs1 ← ex_mem |
| 4 | `8000014c` addi t2,t1,1 | `80000148` add t1,t0,t0 | `80000144` lw t0,0(a0) | `80000142` c.addi a1,20 | `8000013e` lui a1,0x10002 | load/CSR-use: stall IF, ID; bubble → EX |
| 5 | `8000014c` addi t2,t1,1 | `80000148` add t1,t0,t0 | – | `80000144` lw t0,0(a0) | `80000142` c.addi a1,20 |  |
| 6 | `80000150` add t3,t2,t1 | `8000014c` addi t2,t1,1 | `80000148` add t1,t0,t0 | – | `80000144` lw t0,0(a0) | rs1 ← mem_wb; rs2 ← mem_wb |
| 7 | `80000154` c.addi t3,4 | `80000150` add t3,t2,t1 | `8000014c` addi t2,t1,1 | `80000148` add t1,t0,t0 | – | rs1 ← ex_mem |
| 8 | `80000156` c.mv a2,t3 | `80000154` c.addi t3,4 | `80000150` add t3,t2,t1 | `8000014c` addi t2,t1,1 | `80000148` add t1,t0,t0 | rs1 ← ex_mem; rs2 ← mem_wb |
| 9 | `80000158` c.add a2,t2 | `80000156` c.mv a2,t3 | `80000154` c.addi t3,4 | `80000150` add t3,t2,t1 | `8000014c` addi t2,t1,1 | rs1 ← ex_mem |
| 10 | `8000015a` beq t3,t3,80000166 <walk_start+0x22> | `80000158` c.add a2,t2 | `80000156` c.mv a2,t3 | `80000154` c.addi t3,4 | `80000150` add t3,t2,t1 | rs2 ← ex_mem |
| 11 | `8000015e` addi a3,zero,1 | `8000015a` beq t3,t3,80000166 <walk_start+0x22> | `80000158` c.add a2,t2 | `80000156` c.mv a2,t3 | `80000154` c.addi t3,4 | rs1 ← ex_mem |
| 12 | `80000162` addi a3,zero,2 | `8000015e` addi a3,zero,1 | `8000015a` beq t3,t3,80000166 <walk_start+0x22> | `80000158` c.add a2,t2 | `80000156` c.mv a2,t3 | **sai dự đoán: flush IF, ID** |
| 13 | `80000166` csrrsi zero,mstatus,8 | – | – | `8000015a` beq t3,t3,80000166 <walk_start+0x22> | `80000158` c.add a2,t2 |  |
| 14 | `8000016a` sw zero,0(a1) | `80000166` csrrsi zero,mstatus,8 | – | – | `8000015a` beq t3,t3,80000166 <walk_start+0x22> |  |
| 15 | `8000016e` addi t4,zero,1 | `8000016a` sw zero,0(a1) | `80000166` csrrsi zero,mstatus,8 | – | – |  |
| 16 | `80000172` sw t4,0(a1) | `8000016e` addi t4,zero,1 | `8000016a` sw zero,0(a1) | `80000166` csrrsi zero,mstatus,8 | – |  |
| 17 | `80000176` addi a4,zero,3 | `80000172` sw t4,0(a1) | `8000016e` addi t4,zero,1 | `8000016a` sw zero,0(a1) | `80000166` csrrsi zero,mstatus,8 | chờ bus APB: stall IF–MEM, bubble → WB |
| 18 | `80000176` addi a4,zero,3 | `80000172` sw t4,0(a1) | `8000016e` addi t4,zero,1 | `8000016a` sw zero,0(a1) | – | chờ bus APB: stall IF–MEM, bubble → WB |
| 19 | `80000176` addi a4,zero,3 | `80000172` sw t4,0(a1) | `8000016e` addi t4,zero,1 | `8000016a` sw zero,0(a1) | – |  |
| 20 | `8000017a` addi a4,a4,4 | `80000176` addi a4,zero,3 | `80000172` sw t4,0(a1) | `8000016e` addi t4,zero,1 | `8000016a` sw zero,0(a1) | rs2 ← ex_mem |
| 21 | `8000017e` addi a4,a4,5 | `8000017a` addi a4,a4,4 | `80000176` addi a4,zero,3 | `80000172` sw t4,0(a1) | `8000016e` addi t4,zero,1 | chờ bus APB: stall IF–MEM, bubble → WB |
| 22 | `8000017e` addi a4,a4,5 | `8000017a` addi a4,a4,4 | `80000176` addi a4,zero,3 | `80000172` sw t4,0(a1) | – | chờ bus APB: stall IF–MEM, bubble → WB |
| 23 | `8000017e` addi a4,a4,5 | `8000017a` addi a4,a4,4 | `80000176` addi a4,zero,3 | `80000172` sw t4,0(a1) | – |  |
| 24 | `80000182` ecall | `8000017e` addi a4,a4,5 | `8000017a` addi a4,a4,4 | `80000176` addi a4,zero,3 | `80000172` sw t4,0(a1) | **trap (ngắt, cause 3)**: flush, PC ← mtvec; rs1 ← ex_mem; irq pending |
| 25 | `80000194` csrrs t5,mcause,zero | – | – | – | – |  |
| 26 | `80000198` blt t5,zero,800001ac <walk_handler+0x18> | `80000194` csrrs t5,mcause,zero | – | – | – |  |
| 27 | `8000019c` csrrs t6,mepc,zero | `80000198` blt t5,zero,800001ac <walk_handler+0x18> | `80000194` csrrs t5,mcause,zero | – | – | load/CSR-use: stall IF, ID; bubble → EX |
| 28 | `8000019c` csrrs t6,mepc,zero | `80000198` blt t5,zero,800001ac <walk_handler+0x18> | – | `80000194` csrrs t5,mcause,zero | – |  |
| 29 | `800001a0` addi t6,t6,4 | `8000019c` csrrs t6,mepc,zero | `80000198` blt t5,zero,800001ac <walk_handler+0x18> | – | `80000194` csrrs t5,mcause,zero | **sai dự đoán: flush IF, ID**; rs1 ← mem_wb |
| 30 | `800001ac` sw zero,0(a1) | – | – | `80000198` blt t5,zero,800001ac <walk_handler+0x18> | – |  |
| 31 | `800001b0` mret | `800001ac` sw zero,0(a1) | – | – | `80000198` blt t5,zero,800001ac <walk_handler+0x18> |  |
| 32 | `800001b4`  | `800001b0` mret | `800001ac` sw zero,0(a1) | – | – |  |
| 33 | `800001b6` lui a4,0x1000f | `800001b4`  | `800001b0` mret | `800001ac` sw zero,0(a1) | – | chờ bus APB: stall IF–MEM, bubble → WB |
| 34 | `800001b6` lui a4,0x1000f | `800001b4`  | `800001b0` mret | `800001ac` sw zero,0(a1) | – | chờ bus APB: stall IF–MEM, bubble → WB |
| 35 | `800001b6` lui a4,0x1000f | `800001b4`  | `800001b0` mret | `800001ac` sw zero,0(a1) | – |  |
| 36 | `800001ba` slli a5,a0,0x1 | `800001b6` lui a4,0x1000f | `800001b4`  | `800001b0` mret | `800001ac` sw zero,0(a1) | MRET/FENCE.I: flush |
| 37 | `80000176` addi a4,zero,3 | – | – | – | `800001b0` mret |  |
| 38 | `8000017a` addi a4,a4,4 | `80000176` addi a4,zero,3 | – | – | – |  |
| 39 | `8000017e` addi a4,a4,5 | `8000017a` addi a4,a4,4 | `80000176` addi a4,zero,3 | – | – |  |
| 40 | `80000182` ecall | `8000017e` addi a4,a4,5 | `8000017a` addi a4,a4,4 | `80000176` addi a4,zero,3 | – | rs1 ← ex_mem |
| 41 | `80000186` csrrci zero,mstatus,8 | `80000182` ecall | `8000017e` addi a4,a4,5 | `8000017a` addi a4,a4,4 | `80000176` addi a4,zero,3 | rs1 ← ex_mem |
| 42 | `8000018a` addi a0,zero,0 | `80000186` csrrci zero,mstatus,8 | `80000182` ecall | `8000017e` addi a4,a4,5 | `8000017a` addi a4,a4,4 |  |
| 43 | `8000018e` jalr zero,0(ra) | `8000018a` addi a0,zero,0 | `80000186` csrrci zero,mstatus,8 | `80000182` ecall | `8000017e` addi a4,a4,5 | **trap (ngoại lệ, cause 11)**: flush, PC ← mtvec |
| 44 | `80000194` csrrs t5,mcause,zero | – | – | – | – |  |
| 45 | `80000198` blt t5,zero,800001ac <walk_handler+0x18> | `80000194` csrrs t5,mcause,zero | – | – | – |  |
| 46 | `800001ac` sw zero,0(a1) | `80000198` blt t5,zero,800001ac <walk_handler+0x18> | `80000194` csrrs t5,mcause,zero | – | – | load/CSR-use: stall IF, ID; bubble → EX |
| 47 | `800001ac` sw zero,0(a1) | `80000198` blt t5,zero,800001ac <walk_handler+0x18> | – | `80000194` csrrs t5,mcause,zero | – |  |
| 48 | `800001b0` mret | `800001ac` sw zero,0(a1) | `80000198` blt t5,zero,800001ac <walk_handler+0x18> | – | `80000194` csrrs t5,mcause,zero | **sai dự đoán: flush IF, ID**; rs1 ← mem_wb |
