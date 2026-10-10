# Công thức đang triển khai — Phase 5

Mọi hệ số nằm trong BalanceSettings Resource. UnitStats lưu nguồn stats;
StatCalculator tạo dictionary final stats mới, không sửa hoặc cộng dồn nguồn.
EquipmentManager.aggregate tổng hợp modifier từ các item, rồi StatCalculator
tính lại từ source + attributes + equipment. Giảm giáp tạm thời được đọc từ
active effects khi resolve damage; mọi nguồn đều không sửa base stats.

| Chỉ số cuối | Công thức mặc định |
| --- | --- |
| Max HP | Base HP + STR × 20 + flat HP từ đồ, tối thiểu 1 |
| HP regen/giây | Base regen + STR × 0.05 + regen từ đồ, tối thiểu 0 |
| Max Mana | Base Mana + INT × 12 + flat Mana từ đồ, tối thiểu 0 |
| Mana regen/giây | Base regen + INT × 0.04 + regen từ đồ, tối thiểu 0 |
| Physical armor | Base armor + AGI × 0.15 + armor từ đồ |
| Magic armor | Base magic armor + INT × 0.15 + magic armor từ đồ |
| Physical damage | Base physical damage + primary attribute × 0.7 + damage từ đồ |

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
Không triển khai invulnerability/immunity hay ability damage ở Phase 5;
kỹ năng hiện chỉ áp status effects.

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
AI Phase 5 dùng tốc độ runtime này cho steering mỗi tick.

Giảm giáp vật lý từ các instance khác nhau cộng dồn; cùng nguồn/ID refresh.
Hết hạn khôi phục đúng giáp tính từ nguồn, không sửa base stats.
Event effect_applied/effect_expired chứa nguồn, đích, ID, kind, tick;
event áp dụng còn có duration_ticks và magnitude. Engine phát event theo thứ tự
ổn định. Kết quả tái hiện yêu cầu cùng engine version, seed, data, command ticks.

## Trang bị

Mỗi unit có sáu slot. Reassign cùng món vào cùng slot không thêm bonus;
thay món loại bỏ modifier cũ. Các món mặc định cho phép nhiều bản sao.
Món allow_multiple = false chỉ được xuất hiện một lần trong loadout.

Modifier flat cộng trước caps. STR/AGI/INT từ đồ được cộng vào thuộc tính
trước khi chuyển đổi. Flat HP/Mana cộng sau attribute conversion. APS bonus
từ đồ cộng với bonus nguồn/AGI trước khi nhân BaseAPS. Accuracy, critical chance
và status resistance cộng theo điểm phần trăm, sau đó áp cap như Phase 3.
Evasion mỗi món là một nguồn độc lập: hai Evasion Blade 25% tạo 43.75%;
với base evasion 30% tạo 60.625%, không cộng thành 80%.

| Món | Giá | Modifier |
| --- | ---: | --- |
| Iron Armor | 1000 | +15 physical armor |
| Mystic Cloak | 1000 | +15 magic armor |
| Vitality Stone | 1000 | +500 max HP |
| Precision Blade | 1000 | +30 điểm phần trăm accuracy |
| Critical Blade | 1000 | +25 điểm phần trăm critical chance |
| Evasion Blade | 1000 | nguồn evasion độc lập 25% |
| Armor Breaker | 1200 | +15 flat armor reduction trên đòn physical của người mặc |
| Heavy Sword | 1000 | +60 physical attack damage |
| Arcane Staff | 1000 | +60 magic attack damage |
| Pure Blade | 1500 | +40 pure component trên basic attack |
| Swift Gloves | 1000 | +30% attack speed bonus |
| Resolve Amulet | 1000 | +25 điểm phần trăm status resistance |

Armor Breaker chỉ thay effective armor cho đòn của người mặc, không sửa giáp
nguồn của mục tiêu. Pure Blade là damage bổ sung, không chuyển từ physical;
có thể miss, không tự crit. Thay loadout trong UI reset battle, HP/Mana đầy theo
max mới, xóa effect/cooldown attack/commands và reset RNG. Gỡ đồ khôi phục đúng
stats nguồn; Reset trận giữ loadout, Reset equipment xóa loadout unit được chọn.

## Range và projectile

Khoảng cách attack/targeted cast = max(0, khoảng cách tâm - bán kính nguồn -
bán kính đích). Cast vào điểm ground/directional chỉ trừ bán kính nguồn.
Bán kính collision mặc định 32, chỉnh riêng từng unit. Biên range inclusive.

AttackRange = max(0, base attack range + equipment attack bonus + active attack bonus).
CastRange = max(0, base cast range + equipment cast bonus + active cast bonus).
Ability cast_range > 0 thay base cast range, vẫn nhận bonus equipment/effect;
cast_range = 0 kế thừa unit. Hai loại range hoàn toàn độc lập.
Melee mặc định 150, ranged 550, cast 700; radius effect 250; projectile 900 units/s.

Melee resolve ngay. Ranged chỉ phóng khi trong attack range và resolve hit/crit/
damage tại impact, không trừ HP lúc phóng. Offense snapshot lúc launch; armor,
evasion, armor-reduction của đích được đọc tại impact. Công thức mitigation,
crit và overkill không đổi. Attack cooldown bắt đầu tại launch.

Homing stationary: travel_ticks = max(1, ceil(edge_distance / speed × 30)).
Projectile mới bắt đầu di chuyển ở tick sau launch. Fixed-position bay đến tâm
đích lúc launch và chỉ hit nếu đích còn chạm điểm đó; có thể né bằng di chuyển.
Target chết: CANCEL hoặc CONTINUE_TO_POSITION theo cấu hình; không gây damage
lên unit chết. Người bắn chết không hủy shot đã launch. Lifetime mặc định 30 s.

Ground effect dùng disk tại điểm đích; directional dùng capsule đoạn nguồn–đích;
effect-radius cộng bán kính collision đích khi kiểm tra intersection. Projectile
ability chỉ áp effect khi tới endpoint. Chi tiết timing và quy ước: `DESIGN.md`.


## Trận playable trên map

Hero, creep, trụ và nhà chính dùng cùng CombatEngine và các công thức phía trên.
`external_control` chỉ nhận vị trí/target từ map và giao điều kiện thắng cho scene;
không thay mitigation, crit, hit, cooldown, regen hay timing projectile.
Trụ/nhà chính là unit đứng yên với UnitStats riêng. Attack Range vẫn dùng khoảng
cách mép collision. Trụ ưu tiên creep rồi hero trong tầm và có line-of-sight.
Hero hồi sinh được phục hồi HP/Mana, xóa effect/cast/target và đặt cooldown mới.
Thông số thử nghiệm nằm trong `data/match/default_match.tres`.


## Level và đồ trong trận

HeroSource(level) = bản sao source gốc với base overrides của hero +
(level - 1) × growth theo từng trường UnitStats. FinalStats = StatCalculator
của HeroSource và sáu ô trang bị, giữ toàn bộ công thức hiện có. Xạ thủ tăng
HP/công vật lý/tốc đánh/tốc chạy; Đỡ đòn tăng HP/giáp/công vật lý/tốc chạy;
Pháp sư tăng HP/công phép/mana/tốc chạy. Công phép vẫn là thành phần damage
của attack hiện có; chưa có nút skill mới.

XP cần lên cấp = 100 + 50 × (level - 1), tối đa level 15. XP dư giữ lại, cap
xóa XP dư. Mua/bán/level giữ tỷ lệ HP/Mana hiện tại, không hồi đầy, không reset
cooldown/effects/combat tick. Respawn giữ level/gear rồi hồi đầy max mới.
Gold bán = floor(price × sell_refund), mặc định refund 0.5. XP gần địch chết
và vàng last hit/passive được scene cấp theo settings, không sửa combat damage.
