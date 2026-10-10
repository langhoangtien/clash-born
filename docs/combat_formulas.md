# Công thức đang triển khai — Phase 3

Mọi hệ số nằm trong BalanceSettings Resource. UnitStats lưu nguồn stats;
StatCalculator tạo dictionary final stats mới, không sửa hoặc cộng dồn nguồn.
Equipment chưa triển khai; giảm giáp tạm thời được tổng hợp từ active effects.

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
Pure chỉ bỏ qua giáp: cả đòn bị miss thì mọi component đều bằng 0.
Pure chỉ crit khi bật cả `attacks_can_crit` và `pure_attacks_can_crit`.
Không triển khai invulnerability/immunity hay ability damage ở Phase 3.

Hồi phục mỗi tick = regen/giây × 1/30, giới hạn ở max HP/Mana, chỉ khi còn sống.
HP sau damage = max(0, current HP - final damage).
Applied damage = min(current HP trước damage, final damage).

## Attack speed và hit

APS = BaseAPS × (1 + AGI × 0.005 + attack_speed_bonus), clamp 0.3–3.0.
Interval = 1/APS, không nhỏ hơn minimum_attack_interval (mặc định 0.1 s)
hoặc độ dài tick. Bonus là fraction: 0.3 = +30%. AGI 40, base APS 1.5,
bonus 0.3: final APS 2.25. Thời điểm kế tiếp giữ phần tick lẻ;
1.7 APS tạo 17 đòn trong 10 giây, không làm tròn riêng từng interval.
Sau stun hoặc ngoài range, chỉ đánh một đòn khi có thể, không dồn backlog.

Evasion = 1 - tích(1 - source); hai nguồn 0.3 tạo 0.51, cap mặc định 0.75.
Có thể đổi sang cộng bằng balance.multiplicative_evasion = false.
Effective evasion = clamp(target evasion - attacker accuracy, 0, evasion cap).
Accuracy 0.2 giảm evasion 0.3 xuống 0.1; accuracy ≥1 khắc chế evasion thường.

Một roll miss cho toàn đòn; nếu hit và có component eligible thì roll crit.
Critical chance clamp 0–1, multiplier mặc định 2.0 từ balance.
Physical/magic attack component eligible; pure opt-in riêng. Crit nhân raw damage
trước giáp. Miss không roll crit. RNG chỉ dùng engine.rng, khởi tạo từ seed;
Reset xóa commands/effects, tạo runtime mới và đặt lại RNG.

Effective physical armor = (target armor - active effect reductions
- attacker flat reduction) × (1 - clamp(physical penetration, 0, 1)).
Magic armor dùng flat magic reduction, chưa có percentage magic penetration.
Ví dụ armor 30, flat 20, penetration 0.5: effective armor 5.
Quy tắc này áp dụng cả khi âm: armor 10, flat 20, penetration 0.5 → -5.

## Hiệu ứng

Status resistance clamp 0–0.6. Stun duration = base duration × (1 - resistance).
4 giây với resistance 0.25 còn 3 giây. Thời gian effect được ceil lên số tick
(sai số tối đa dưới 1/30 giây); effect active ở tick áp dụng, expire trước xử lý
hành động ở tick apply + duration_ticks. Resistance hiện chỉ rút ngắn stun.

Stun chặn can_act/can_move/can_cast. Stun độc lập có thể overlap, không cộng duration:
A 3 giây ở t=0 và B 3 giây ở t=2 kết thúc ở t=5. ID khác nhau tạo instance
độc lập; cùng kind/source/instance ID refresh, không thêm instance thứ hai.

Slow dùng mức mạnh nhất; movement = max(minimum movement speed,
base movement × (1 - strongest slow)). Base 300, slow 0.4 → 180;
minimum movement mặc định 100. Nếu stun hoặc chết, movement bằng 0.
Đây là tốc độ runtime, chưa có di chuyển hay AI trong scene.

Giảm giáp vật lý từ các instance khác nhau cộng dồn; cùng nguồn/ID refresh.
Hết hạn khôi phục đúng giáp tính từ nguồn, không sửa base stats.
Event effect_applied/effect_expired chứa nguồn, đích, ID, kind, tick;
event áp dụng còn có duration_ticks và magnitude. Engine phát event theo thứ tự
ổn định. Kết quả tái hiện yêu cầu cùng engine version, seed, data, command ticks.
