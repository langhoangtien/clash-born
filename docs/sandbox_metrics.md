# Simulation và metrics — Phase 5

Engine xử lý theo thứ tự unit trong cấu hình; target cùng score được phân xử
bằng ID để ổn định. Mọi RNG lấy từ engine.rng, reset bằng seed.

Thứ tự mỗi tick 1/30 giây:

1. Hết hạn effect, rồi áp debug commands đã xếp từ UI.
2. Hồi HP/Mana cho unit sống, chọn target từ trạng thái hiện tại.
3. Tính steering từ snapshot vị trí; áp hai lượt separation và giới hạn arena.
4. Xử lý cast bị interrupt, bắt đầu cast hợp lệ theo thứ tự ability data;
   collect các cast hoàn thành rồi áp effects của chúng.
5. Thu thập basic attacks: hit → crit → tính các component sau giáp.
6. Ghi survival/time-stunned tick; áp damage và xử lý deaths.
7. Kiểm tra team elimination hoặc timeout; consume events vào metrics, trả events.

Attack cùng tick được thu thập trước damage nên có thể giết lẫn nhau.
Cast cùng tick được thu thập trước effects nên không ưu tiên caster đầu danh sách.
Ability stun áp sau movement của tick đó, chặn attacks ngay và movement tick sau.
Debug stun áp trước movement. Khi đã cast, unit dừng move/basic attack trong
cast time; instant cast có thể đi cùng basic attack. Stun interrupt cast;
mục tiêu chết/ra khỏi cast range lúc completion khiến cast fizzle.
Mana/cooldown bắt đầu ở cast start, không hoàn trả khi interrupt/fizzle.
Cooldown và cast time ceil lên số tick; duration effect vẫn theo Phase 3.
Kỹ năng hiện chỉ áp status effects, chưa có damage ability hay skill tree.

| Metric | Định nghĩa |
| --- | --- |
| Damage dealt | Tổng applied_damage của source, không tính overkill |
| Damage received | Tổng HP thực mất do damage, không trừ healing |
| Physical/magic/pure dealt | Damage dealt theo loại; tổng bằng damage dealt |
| Missed attacks | Số basic attack có event miss; không đếm component |
| Critical strikes | Số basic attack hit được roll critical eligible; không đếm component, kể cả nếu target đã nhận lethal từ đòn khác cùng tick |
| Stun duration applied | Tổng duration ticks sau resistance của stun do source áp, tính cả refresh/overlap; không phải thời gian target thực bị khóa |
| Time spent stunned | Tổng tick unit sống và có ít nhất một stun active sau cast resolution; overlap chỉ tính một lần, có tính tick chết |
| Healing received | HP regen thực nhận, giới hạn max HP; không tính hồi mana hoặc HP reset |
| Survival time | Thời gian đến death tick; survivor dùng thời gian kết thúc trận |

Debug source không phải combat unit nên không cộng stun-applied cho một unit.
Battle duration = tick_count / 30. Winner là team còn sống khi elimination;
hòa khi cả hai chết cùng tick hoặc hết timeout thử nghiệm. Timeout mặc định
180 giây, chỉnh trong BalanceSettings. Không phân thắng bằng lượng HP còn lại.
Dead units không move, cast, attack, regenerate hay revive.

Results là bản sao Dictionary serializable; log UI chỉ giữ 300 dòng cuối,
còn metrics thu thập toàn bộ trận. Reset xóa metrics/effect/cast/cooldown/commands,
tạo runtime mới từ source + loadout và đặt lại RNG. Cùng phiên bản, source/
equipment/abilities/balance, seed và command ticks cho cùng event/results
bất kể speed 0.5x/1x/2x/4x. Không bảo đảm replay giữa các phiên bản Godot/RNG khác nhau.
