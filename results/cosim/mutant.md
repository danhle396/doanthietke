# Co-simulation với RTL có lỗi cài sẵn (mutant)

Lỗi cài sẵn (`alu.sv`, chỉ khi `-DCOSIM_MUTANT`): SLTU/SLTIU lấy bit 31 của hiệu thay cho bit mượn – sai khi hai toán hạng khác nhau ở bit 31 (ví dụ `0 < 0xffff8000`).

Chương trình phát hiện lỗi: **2 / 73** (cấu hình `m1c1_bp2`). Mỗi lần phát hiện, harness dừng ngay ở lệnh sai đầu tiên và in 6 lệnh khớp trước đó.

| Chương trình | Phát hiện ở lệnh # | RTL | Spike |
|---|---|---|---|
| rv32ui-p-sltiu | #63 | pc 0x800000e4 (0x8006b713) x14=0x00000000 | pc 0x800000e4 (0x8006b713) x14=0x00000001 |
| rv32ui-p-sltu | #68 | pc 0x800000ee (0x00c5b733) x14=0x00000000 | pc 0x800000ee (0x00c5b733) x14=0x00000001 |

Không phát hiện (71 chương trình, không thực thi SLTU/SLTIU với toán hạng gây sai): `rv32ui-p-simple`, `rv32ui-p-add`, `rv32ui-p-addi`, `rv32ui-p-and`, `rv32ui-p-andi`, `rv32ui-p-auipc`, `rv32ui-p-beq`, `rv32ui-p-bge`, `rv32ui-p-bgeu`, `rv32ui-p-blt`, `rv32ui-p-bltu`, `rv32ui-p-bne`, `rv32ui-p-fence_i`, `rv32ui-p-jal`, `rv32ui-p-jalr`, `rv32ui-p-lb`, `rv32ui-p-lbu`, `rv32ui-p-lh`, `rv32ui-p-lhu`, `rv32ui-p-lw`, `rv32ui-p-ld_st`, `rv32ui-p-lui`, `rv32ui-p-or`, `rv32ui-p-ori`, `rv32ui-p-sb`, `rv32ui-p-sh`, `rv32ui-p-sw`, `rv32ui-p-st_ld`, `rv32ui-p-sll`, `rv32ui-p-slli`, `rv32ui-p-slt`, `rv32ui-p-slti`, `rv32ui-p-sra`, `rv32ui-p-srai`, `rv32ui-p-srl`, `rv32ui-p-srli`, `rv32ui-p-sub`, `rv32ui-p-xor`, `rv32ui-p-xori`, `rv32um-p-div`, `rv32um-p-divu`, `rv32um-p-mul`, `rv32um-p-mulh`, `rv32um-p-mulhsu`, `rv32um-p-mulhu`, `rv32um-p-rem`, `rv32um-p-remu`, `rv32uc-p-rvc`, `rv32mi-p-csr`, `rv32mi-p-mcsr`, `rv32mi-p-illegal`, `rv32mi-p-ma_fetch`, `rv32mi-p-ma_addr`, `rv32mi-p-scall`, `rv32mi-p-sbreak`, `rv32mi-p-shamt`, `rv32mi-p-lw-misaligned`, `rv32mi-p-lh-misaligned`, `rv32mi-p-sh-misaligned`, `rv32mi-p-sw-misaligned`, `rv32mi-p-zicntr`, `rv32mi-p-instret_overflow`, `bench-coremark`, `bench-dhrystone`, `bench-median`, `bench-memcpy`, `bench-multiply`, `bench-qsort`, `bench-rsort`, `bench-towers`, `bench-vvadd`.
