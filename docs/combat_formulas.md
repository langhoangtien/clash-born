# Công thức đang triển khai — Phase 2

Mọi hệ số nằm trong BalanceSettings Resource. UnitStats lưu nguồn stats;
StatCalculator tạo dictionary final stats mới, không sửa hoặc cộng dồn nguồn.
Equipment và temporary modifiers chưa được triển khai.

| Chỉ số cuối | Công thức mặc định |
| --- | --- |
| Max HP | Base HP + STR × 20, tối thiểu 1 |
| HP regen/giây | Base regen + STR × 0.05, tối thiểu 0 |
| Max Mana | Base Mana + INT × 12, tối thiểu 0 |
| Mana regen/giây | Base regen + INT × 0.04, tối thiểu 0 |
| Physical armor | Base armor + AGI × 0.15 |
| Magic armor | Base magic armor + INT × 0.15 |
| Physical damage | Base physical damage + primary attribute × 0.7 |

Primary damage bật/tắt toàn cục hoặc từng unit; NONE không thêm damage.
Ví dụ AGI 40, primary AGILITY: thêm 28 physical damage.
Magic/pure damage dùng trực tiếp từ dữ liệu, không chuyển đổi từ physical damage.
Damage component âm được giới hạn về 0; giáp âm và giáp phân số được giữ nguyên.

Giáp A ≥ 0: `multiplier = 1 / (1 + 0.06 × A)`.
Giáp A < 0: `multiplier = 2 - 1 / (1 + 0.06 × abs(A))`.
Final damage = raw damage × multiplier.

100 physical damage vào armor 20: 45.454545; vào armor -10: 137.5.
200 magic damage vào magic armor 20: 90.909091.
Magic damage chỉ dùng magic armor; physical damage chỉ dùng physical armor.
Pure damage giữ nguyên: 200 pure vào cả hai giáp 50 vẫn gây 200.
Pure chỉ bỏ qua giáp; phase hiện tại chưa có hit mechanics, không thiết lập
quy tắc tự động bỏ qua evasion, immunity hay crit cho các phase sau.

Hồi phục mỗi tick = regen/giây × 1/30, giới hạn ở max HP/Mana, chỉ khi còn sống.
HP sau damage = max(0, current HP - final damage).
Applied damage = min(current HP trước damage, final damage).

Cadence Phase 2 cố định 30 tick/đòn; đây là lịch tấn công nền tảng,
chưa phải hệ thống attack speed. Armor reduction và penetration chưa triển khai.
