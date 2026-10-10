# Clashborn — Range & Projectile Sandbox

Combat sandbox MOBA 2D, hoàn thành đến **Phase 5 — Combat Sandbox**.
Godot **4.7.2 stable**, GDScript, Compatibility renderer; không cần thư viện ngoài.
Đã có STR/AGI/INT, HP/Mana, ba loại damage, giáp âm/dương, attack speed,
evasion/accuracy/crit, status effects và 14 món trang bị với sáu slot mỗi unit.
Phase 5 thêm cấu hình 1–5 unit mỗi team, AI, kỹ năng tối thiểu, editor stats,
combat log và kết quả từng unit. Combat chạy 30 Hz độc lập với rendering/input.

## Chạy

Mở `project.godot` bằng Godot rồi nhấn **F5**, hoặc chạy PowerShell:

```powershell
& 'C:\Users\Admin\.codex\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --path 'D:\Clashborn'
& 'C:\Users\Admin\.codex\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --path 'D:\Clashborn' --editor
```

Máy khác cần thay đường dẫn executable. Godot portable nằm ngoài repository;
[bản phát hành chính thức](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable).

## Thử một trận

1. Đặt số unit **BLUE / RED** từ 1 đến 5 ở đầu màn hình.
2. Chọn archetype từng slot: Physical Tank, Magic Tank, Melee Carry, Ranged Carry, Mage.
3. Click unit trong arena, hoặc chọn ID trong tab **Stats / Equipment**.
4. Trong **Stats**, chỉnh chỉ số gốc, primary attribute, AI mode và bật/tắt kỹ năng.
   Final/current stats ở phía trên; cuộn để xem các trường còn lại.
   Trường phần trăm dùng 0–100: evasion 30 tương ứng fraction 0.3.
5. Trong **Equipment**, chọn đồ ở sáu slot; chọn Empty để gỡ. Tooltip có bonus,
   mô tả và giá tham khảo. Reset equipment chỉ xóa đồ của unit đang chọn.
6. Chọn seed, tốc độ 0.5x/1x/2x/4x rồi nhấn **Start**. Pause/Resume và Step +1
   dùng để quan sát từng tick. Các nút debug cuối màn hình áp effect ở tick kế tiếp.
7. Mở tab **Log** để xem event; khi trận kết thúc tab **Results** tự mở.
8. Nhấn **Reset** để chạy lại cùng nguồn stats, loadout và seed.

Đổi team count, archetype, stats, AI hoặc trang bị sẽ pause/reset toàn trận,
phục hồi HP/Mana, xóa effect/cast/cooldown/log/metrics và khởi tạo lại RNG.
Reset trận giữ loadout; đổi archetype giữ trang bị của slot nhưng thay stats gốc.
Slot tạm tắt giữ chỉnh sửa và loadout khi bật lại. Cấu hình lưu trong phiên chạy,
chưa tự lưu ra file. Các tab dùng cùng selection; unit được chọn hiển thị attack range (trắng) và cast range (xanh).

Unit có tên ngắn, HP/Mana bars, số damage, MISS/CRIT và mã trạng thái:
**S** stun, **L** slow, **A** giảm giáp, **C** đang cast. Tab Stats hiển thị tên
effect đầy đủ, thời gian còn lại và cooldown kỹ năng. Unit chết có nhãn DEAD.
Log giữ **300 dòng mới nhất** để UI gọn; metrics tính từ toàn trận.

AI có Passive, Attack nearest, Attack lowest HP và Attack highest damage
(estimated basic DPS, không tính crit). Melee tiến đến range, ranged dừng ở range;
không có kiting nâng cao. Có steering/tách unit cơ bản, không có terrain/pathfinding.
AI dùng kỹ năng đủ mana/cooldown/range theo thứ tự Resource, retarget khi mục tiêu chết.
Melee range 150; ranged range 550 và dùng projectile; cast range 700 độc lập.
Các kỹ năng mặc định kế thừa cast range unit, có thể override trong Resource.
Stats có tốc độ projectile (mặc định 900), kiểu homing/fixed-position và xử lý
target chết. Range Lens / Cast Focus tăng riêng attack/cast range.
AbilityData hỗ trợ ENEMY, DIRECTIONAL, GROUND; effect_radius mặc định 250.
Quy ước khoảng cách mép va chạm và timing chi tiết nằm trong `DESIGN.md`.

Trận kết thúc khi một team hết unit sống và projectile còn bay đã resolve;
posthumous hit có thể tạo hòa.
Stalemate/Passive được giới hạn **180 giây mô phỏng** và trả hòa `time_limit`;
giới hạn thử nghiệm nằm trong BalanceSettings, không ép team nào thắng.

## Test

Import khi dùng checkout mới, rồi chạy toàn bộ script native Godot:

```powershell
$godotExe = 'C:\Users\Admin\.codex\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godotExe --headless --path 'D:\Clashborn' --editor --import
foreach ($phase in 1..5) {
    & $godotExe --headless --path 'D:\Clashborn' --script "res://tests/test_phase$phase.gd"
    if ($LASTEXITCODE -ne 0) { throw "Phase $phase failed" }
}
& $godotExe --headless --path 'D:\Clashborn' --script res://tests/test_range_projectiles.gd
& $godotExe --path 'D:\Clashborn' --script res://tests/test_phase5.gd -- --capture
& $godotExe --path 'D:\Clashborn' --script res://tests/test_range_projectiles.gd -- --capture
```

Test trả exit code 0 khi pass, 1 khi fail. Hai lệnh cuối chạy renderer thật và lưu ảnh trong `.local/`, gồm
`phase5-preview.png`, `phase5-results.png`, `range-projectile-preview.png`, rồi tự thoát.
Phase 5 kiểm tra targeting/movement/retarget/separation, ability cost/cooldown/cast
và interruption, metrics, giới hạn team, editor/selection/equipment/reset và 5v5
có evasion/crit dùng cả ba kỹ năng. Replay ở bốn tốc độ phải có cùng event/metrics.
Test UI cũ đã được cập nhật cho việc unit bắt đầu ngoài melee range và layout mới;
test công thức ở API duel vẫn chạy không có AI.

Đã xác minh bằng Godot 4.7.2: **170 kiểm tra Phase 5 headless** và **175 kiểm tra
Phase 5 có renderer** pass, gồm click chọn unit trong arena đã scale. Kiểm tra
hồi quy Phase 1/2/3/4: **23 / 112 / 170 / 645** đều pass.
Import/editor thành công; scene chính chạy 180 frame, exit code 0, không có lỗi
runtime/resource leak trong log. Đã xem ảnh 5v5 và kết quả 1280×720; inspector,
team config, controls, range clipping và metrics hiển thị đúng.
Hệ thống range/projectile pass **93 kiểm tra headless / 94 kiểm tra renderer**;
bao gồm damage tại impact, hình học effect, pause, source/target death và replay.
Toàn bộ suite cũng chạy với renderer: Phase 1–5 đạt **26 / 114 / 172 / 650 / 175**,
không có failure, lỗi runtime hay resource leak trong log.

## Cấu trúc và mở rộng

- `scripts/core/`: clock, engine, công thức stats/hit/damage, balance Resource.
- `scripts/units/`: UnitStats nguồn, UnitRuntimeState thuần, unit presentation.
- `scripts/ai/combat_ai.gd`: target selection, steering và separation.
- `scripts/abilities/`: AbilityData và danh sách AbilityEffectData tái sử dụng.
- `scripts/effects/`: refresh, stacking và expiration của hiệu ứng.
- `scripts/equipment/`: Resource đồ, sáu slot và tổng hợp modifier duy nhất.
- `scripts/simulation/combat_metrics.gd`: metrics từng unit.
- `scripts/ui/`: controller, editor stats và panel trang bị.
- `data/units/archetypes/`: năm archetype; `data/abilities/`: ba kỹ năng.
- `data/equipment/`: 14 món; `data/balance/default_balance.tres`: hằng số thử nghiệm.
- `scenes/`: main, arena và unit; `tests/`: kiểm tra native từng phase.

Thêm archetype: tạo UnitStats `.tres`, cấu hình stats/AI/abilities rồi thêm preload
vào ARCHETYPES trong sandbox_controller.gd. Thêm trang bị: tạo EquipmentData
`.tres` với ID duy nhất, tên/mô tả/giá/modifiers, thêm vào CATALOG của equipment_panel.gd.
Các key được hỗ trợ nằm trong EquipmentData.SUPPORTED_MODIFIERS; allow_multiple
điều khiển nhiều bản sao. Thêm kỹ năng effect: tạo AbilityData với cost/cooldown/
range/cast_time/target_type/effects và gán vào UnitStats; không cần script riêng từng hero.

Input UI → source configuration/debug commands → fixed-step engine → serializable
events/runtime snapshots → presentation/log/results. Engine không dùng Node, Control,
render delta hay global randomness. API `reset_scenario` nhận danh sách unit;
`reset` giữ cách gọi duel không AI để kiểm tra công thức. Thời gian tính từ số tick.

Thứ tự tick và định nghĩa metrics: `docs/sandbox_metrics.md`.
Công thức đã triển khai: `docs/combat_formulas.md`.
Chưa triển khai batch simulations, preset experiment suite hay CSV export của
**Phase 6 — Balance Laboratory**. Chưa có networking, shop economy, map MOBA,
tower/minion/jungle hay skill tree. Dừng sau hệ thống range/projectile. File đính kèm Phase 4.5 là phạm vi riêng;
lifesteal/spell vamp/central healing chưa tồn tại trong checkout này và chưa được
thêm trong lần sửa range. Bước tiếp theo phù hợp là Phase 4.5 nếu được yêu cầu.
