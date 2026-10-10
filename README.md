# Clashborn — Playable MOBA Match

Trận MOBA 2D điều khiển hero Blue đấu bot Red, có creep ba lane, trụ và nhà chính.
Combat Sandbox và Map Prototype vẫn là hai mode riêng có thể mở từ trận đấu.
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

## Trận MOBA điều khiển trực tiếp

F5 mở `scenes/match/moba_match.tscn`. Bạn điều khiển hero Blue; bot Red tự đi MID,
chọn mục tiêu và chiến đấu. Creep hai đội xuất hiện ngay rồi mỗi 20 giây trên
TOP/MID/BOT, mỗi lane hai lính cận chiến và một lính đánh xa. Trụ và nhà chính
bắn mục tiêu trong tầm, ưu tiên creep. Hero chết hồi sinh sau 8 giây tại base.
Phá nhà chính Red để thắng; nhà chính Blue bị phá thì thua. Có nút Chơi lại.
Về vòng tròn **FOUNTAIN** tại điểm spawn của đội mình để hồi nhanh:
thêm 20% máu tối đa và 25% mana tối đa mỗi giây; rời vòng tròn ngừng hồi thêm.

- **WASD / mũi tên / bốn nút góc trái**: di chuyển, terrain chặn đường.
- **J / ĐÁNH LÍNH–TRỤ**: tự chọn creep địch; nếu không có thì chọn trụ/nhà chính.
- **K / ĐÁNH HERO**: chỉ chọn hero địch. Click địch để khóa mục tiêu cụ thể.
- Sau lệnh đánh, hero tự đi vào tầm và tiếp tục đánh. Di chuyển hoặc **Space** hủy.
- Chuột phải đi đến điểm; **Ra MID** tự tìm đường ra lane giữa.
- **Tab / Trang bị hai đội**: xem level, chỉ số và 6 ô đồ của bạn/đối thủ.
- **B / Shop–Hero**: mua/bán đồ, xem tăng chỉ số mỗi cấp; chọn hero rồi bắt đầu trận mới.
- **P** tạm dừng; **F** theo hero; chuột giữa pan, wheel zoom, click minimap xem vùng.
- Bốn nút hỗ trợ touch/drag và nhiều ngón; chưa có bản xuất Android/iOS được kiểm thử.

Trụ 5000 HP, sát thương 220; hero gây 50% damage lên công trình sau giáp.
Khởi đầu 250 vàng, tự tăng 1 vàng mỗi 2 giây. Shop có icon, giá/bonus riêng cho trận;
đồ tấn công đã giảm bonus và bot cũng mua đồ bằng vàng kiếm được. Creep cận chiến
hình tròn/dấu kiếm; creep đánh xa hình thoi/dấu cung. Chi tiết cân bằng: `docs/match_balance.md`.

Stats/tốc độ lính, interval/cap wave, respawn và tầm tìm mục tiêu chỉnh tại
`data/match/default_match.tres`; map vẫn dùng `data/maps/moba_foundation.tres`.
Đây là trận local 1v1 với đồ họa hình học; có chọn Xạ thủ/Đỡ đòn/Pháp sư,
level/XP, vàng và shop. Chưa có skill buttons, jungle objectives, multiplayer hoặc 5v5.
Chưa có tránh va chạm
động giữa unit hay khóa nhà chính bằng trụ. Chi tiết: `docs/playable_match.md`.

## Map Prototype (Phase 6)

Từ Combat Sandbox, nhấn **Map Prototype**. Hoặc chạy scene trực tiếp:

```powershell
& 'C:\Users\Admin\.codex\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --path 'D:\Clashborn' res://scenes/map/map_prototype.tscn
```

Map 40×40 ô, mỗi ô 128 world units: base Blue góc dưới-trái, Red góc trên-phải,
TOP/MID/BOT, jungle passages, sông trung tâm và terrain bị chặn. Hai probe dùng
stats/view unit hiện có để thử navigation; map không chạy combat engine riêng.

- Click chọn probe / dropdown; chuột phải để tìm đường đến vị trí world chính xác.
- WASD di chuyển trực tiếp; collision chặn terrain. TOP/MID/BOT chạy theo lane.
- Chuột giữa kéo hoặc phím mũi tên pan; wheel zoom; F follow; O xem toàn map.
- Bảy overlay bật/tắt riêng: grid, walkability, lane waypoints, navigation paths,
  collision circles, base spawns và tower markers. Reset/Stop/Pause thử navigation.
- **Combat Sandbox** trở lại mode cũ; **Chơi trận MOBA** mở trận điều khiển hero.

Dữ liệu chỉnh ở `data/maps/moba_foundation.tres`; nav dùng AStarGrid2D, movement
liên tục bằng CharacterBody2D. Cấu trúc/tệp thay đổi/giới hạn: `docs/phase6_map.md`.
Mode Map Prototype chỉ thử navigation; creep và tower combat nằm trong mode Trận MOBA.

## Thử Combat Sandbox

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
foreach ($phase in 1..6) {
    & $godotExe --headless --path 'D:\Clashborn' --script "res://tests/test_phase$phase.gd"
    if ($LASTEXITCODE -ne 0) { throw "Phase $phase failed" }
}
& $godotExe --headless --path 'D:\Clashborn' --script res://tests/test_range_projectiles.gd
& $godotExe --headless --path 'D:\Clashborn' --script res://tests/test_playable_match.gd
& $godotExe --headless --path 'D:\Clashborn' --script res://tests/test_progression_shop.gd
& $godotExe --headless --path 'D:\Clashborn' --script res://tests/test_fountain.gd
& $godotExe --headless --fixed-fps 60 --path 'D:\Clashborn' --script res://tests/test_match_balance.gd -- --soak
& $godotExe --path 'D:\Clashborn' --script res://tests/test_phase5.gd -- --capture
& $godotExe --path 'D:\Clashborn' --script res://tests/test_range_projectiles.gd -- --capture
& $godotExe --path 'D:\Clashborn' --script res://tests/test_phase6.gd -- --capture
& $godotExe --path 'D:\Clashborn' --script res://tests/test_playable_match.gd -- --capture
& $godotExe --path 'D:\Clashborn' --script res://tests/test_progression_shop.gd -- --capture
& $godotExe --path 'D:\Clashborn' --script res://tests/test_fountain.gd -- --capture
& $godotExe --fixed-fps 60 --path 'D:\Clashborn' --script res://tests/test_match_balance.gd -- --capture
```

Test trả exit code 0 khi pass, 1 khi fail. Các lệnh cuối chạy renderer thật và lưu ảnh trong `.local/`, gồm
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

Phase 6 đã chạy bằng Godot 4.7.2: **690 kiểm tra headless / 692 kiểm tra renderer**
pass, gồm hai team qua đủ ba lane, collision vật lý, camera, desktop input,
overlays và chuyển qua lại hai mode. Các suite Phase 1–5 và range/projectile vẫn
pass. Cả scene map lẫn sandbox chạy trực tiếp 180 frame, exit code 0; log không
có lỗi runtime/resource leak. Ảnh overview/navigation đã được kiểm tra trực quan.

Level/shop đã pass **43 kiểm tra headless / 44 kiểm tra renderer**, gồm khác biệt
hero, XP/cap/overflow, mua bán/giá/slot, giữ máu/cooldown, reward và UI. Xem
`docs/progression_shop.md`.

Trận MOBA đã pass **66 kiểm tra headless / 67 kiểm tra renderer** bằng Godot
4.7.2: wave, chọn mục tiêu, damage tại impact, trụ ưu tiên lính, hồi sinh,
pause, thắng trận, UI bốn hướng/multitouch và native physics. Ảnh
`.local/playable-match.png` đã được kiểm tra. Các suite Phase 1–6 và range/projectile
đã chạy lại headless, đều pass.

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
- `scripts/map/`: dữ liệu map, AStarGrid2D, terrain collision, probes, camera và controls.
- `data/maps/`: map authoring Resource; `scenes/map/`: Map Prototype.
- `scripts/match/`, `scenes/match/`, `data/match/`: trận playable và cấu hình.
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
Theo yêu cầu mới, Phase 6 là **MOBA Map Foundation**; nhãn Balance Laboratory
trong master prompt cũ không còn dùng cho Phase 6. Không triển khai batch/CSV,
networking, jungle combat hay skill tree. Phần
lifesteal/spell vamp/central healing trong prompt Phase 4.5 vẫn là phạm vi riêng.
Theo yêu cầu tiếp theo, đã thêm trận playable có creep/trụ/hero controls ở mode riêng.
Không mở rộng sang các tính năng MOBA đầy đủ khác.

Xe bắn đá xuất hiện đợt 1/4/7/...; lính gần 700 HP, xa 450 HP, xe 1600 HP.
XP chia cho hero gần; vàng hạ hero theo cấp, có hỗ trợ và ghi công khi trụ kết liễu.
Công thức, cấu hình và giới hạn: `docs/siege_rewards.md`.
