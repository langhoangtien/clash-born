# Clashborn — Phase 4

Sandbox chiến đấu MOBA 2D, hoàn thành đến **Phase 4 — Equipment**.
Arena 1600×900, hai unit đấu tại vị trí cố định, STR/AGI/INT, HP/Mana và hồi phục,
sát thương vật lý/phép/thuần, giáp âm/dương, tấn công cơ bản và xử lý chết.
Combat chạy 30 Hz bằng trạng thái thuần GDScript, độc lập với scene/rendering.
Đã có attack speed, evasion/accuracy, chí mạng, status resistance,
stun, slow và giảm giáp; RNG có seed để tái hiện cùng chuỗi lệnh.
Đã có 12 Resource trang bị, sáu slot riêng cho mỗi unit, UI thêm/gỡ/reset
và tính lại final stats từ nguồn. Unit giữ nguyên ngoại hình khi đổi đồ.

## Chạy dự án

Godot **4.7.2 stable**, GDScript, renderer Compatibility. Không cần thư viện ngoài.
Mở `project.godot` bằng Godot, nhấn **F6** với scene chính hoặc **F5** chạy dự án.

PowerShell trên máy hiện tại:

```powershell
& 'C:\Users\Admin\.codex\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --path 'D:\Clashborn' --editor
& 'C:\Users\Admin\.codex\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --path 'D:\Clashborn'
```

Nếu dùng máy khác, thay đường dẫn executable. Godot portable đã được tải từ
[bản phát hành chính thức](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable).

## Điều khiển

- **Start / Pause / Resume**: chạy hoặc dừng đồng hồ.
- **Step +1 tick**: tiến đúng 1/30 giây khi đang pause.
- **Reset**: đưa thời gian về 0, phục hồi HP/Mana, trạng thái sống và lịch tấn công; giữ tốc độ đã chọn.
- **Clock speed**: 0.5x, 1x, 2x hoặc 4x. Không thay đổi độ dài tick.
- **Seed (on Reset)**: seed số nguyên; nhấn Reset để khởi tạo lại RNG.
- **Debug effects**: chọn Red/Blue, áp stun 4 giây, slow 40% trong 5 giây hoặc
  giảm giáp 15 trong 6 giây. Lệnh chạy ở tick kế tiếp; khi pause nhấn Step.
  Đây là công cụ kiểm tra hiệu ứng, chưa phải kỹ năng (không tốn mana/cooldown).
- **Equipment**: chọn Blue Unit hoặc Red Unit ở panel bên phải, chọn món ở từng
  slot. Chọn **Empty** để gỡ. Dropdown hiển thị bonus; tooltip có mô tả và giá.
  Dòng Gear hiển thị tổng bonus, hover để xem toàn bộ khi nội dung dài.
- **Reset equipment (selected unit)**: xóa cả sáu slot của unit đang chọn.

Mỗi thay đổi trang bị tự pause và reset trận, tính lại stats ngay, phục hồi
HP/Mana và khởi tạo RNG từ seed đang chọn. Đây là quy tắc thử nghiệm cho
loadout trước trận, không phải thay đồ giữa trận. **Reset trận giữ loadout**;
reset equipment chỉ xóa đồ của unit đang chọn. Loadout hiện lưu trong phiên chạy,
không tự lưu ra file. Giá chỉ để tham khảo, chưa có shop/economy.

Nhấn **Start** để xem hai unit tấn công. UI hiển thị HP/Mana, thuộc tính,
sát thương và giáp cuối cùng. Trận tự dừng khi một hoặc cả hai unit chết;
nhấn Reset để đấu lại. Mana hồi phục nhưng chưa bị tiêu hao vì chưa có kỹ năng.
UI hiển thị APS, evasion, accuracy, crit, resistance, movement speed và thời gian
còn lại của hiệu ứng. Slow thay đổi movement speed, unit chưa có movement AI.
Blue mặc định có accuracy 30 điểm phần trăm để khắc chế evasion 30% của Red;
chỉnh accuracy về 0 trong Resource để thử né tránh. Cả hai có crit và resistance.

Chỉnh `data/units/blue_stats.tres` và `red_stats.tres` trong Godot Inspector,
lưu rồi chạy lại scene. Khi Resource đang được chỉnh trong cùng runtime,
Reset tính lại stats từ Resource đó. Chưa có editor stats trong UI hay shop.
Các hằng số thử nghiệm nằm trong `data/balance/default_balance.tres`.
Tạo unit data mới bằng Resource `UnitStats`, gán vào `combat_data` của instance;
engine hiện chỉ hỗ trợ hai unit đối địch, chưa hỗ trợ team configuration.

## Kiểm tra

Import trước khi chạy test từ checkout mới để Godot đăng ký các lớp GDScript:

```powershell
$godotExe = 'C:\Users\Admin\.codex\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godotExe --headless --path 'D:\Clashborn' --editor --import
& $godotExe --headless --path 'D:\Clashborn' --script res://tests/test_phase1.gd
& $godotExe --headless --path 'D:\Clashborn' --script res://tests/test_phase2.gd
& $godotExe --headless --path 'D:\Clashborn' --script res://tests/test_phase3.gd
& $godotExe --headless --path 'D:\Clashborn' --script res://tests/test_phase4.gd
& $godotExe --path 'D:\Clashborn' --script res://tests/test_phase4.gd -- --capture
```

Chạy bốn script headless ở trên để kiểm tra toàn bộ phần đã triển khai.
Test trả exit code 0 nếu pass, 1 nếu fail. Phase 1 kiểm tra clock/UI;
Phase 2 kiểm tra công thức, chuyển thuộc tính, hồi phục, tấn công đúng tick,
sát thương hỗn hợp, chết/hòa/reset, event JSON và kết quả giống nhau ở các tốc độ.
Phase 3 kiểm tra caps, evasion stacking, miss rate trên 10.000 lượt, accuracy,
crit flags/thứ tự RNG, lịch APS không trôi, stun/slow/armor stacking và expiration,
reset RNG/commands/effects, deterministic replay ở cả bốn tốc độ và nút debug UI.
Phase 4 kiểm tra 12 món đúng giá/bonus, sáu slot, duplicate policy, 100 vòng
equip/unequip không drift, thay đồ không cộng trùng, caps/stacking, tác động
combat, reset/replay và UI thêm/gỡ/chọn unit/reset. Lệnh capture còn kiểm tra
panel không tràn xuống thanh điều khiển và final stats hiển thị trong panel.
Lệnh cuối chạy renderer thật, lưu ảnh trang bị vào `.local/phase4-preview.png`,
rồi tự thoát. Đồng thời kiểm tra log để phát hiện lỗi runtime/rendering.

Đã xác minh bằng Godot 4.7.2: **631 kiểm tra Phase 4 headless**, **636 kiểm tra
Phase 4 có renderer**, cùng **23 kiểm tra Phase 1**, **112 kiểm tra Phase 2** và
**170 kiểm tra Phase 3** đều pass. Import/editor thành công; scene chính chạy
180 frame, exit code 0, không có lỗi runtime hoặc resource leak trong log.
Ảnh render 1280×720 đã được kiểm tra: sáu slot, bonus, final stats và các
điều khiển hiển thị đầy đủ, panel không che thanh điều khiển mô phỏng.

## Cấu trúc và mở rộng

- `scenes/main.tscn`: điểm vào, ghép arena và controller UI.
- `scenes/sandbox/combat_sandbox.tscn`: arena và hai instance unit.
- `scenes/units/combat_unit.tscn`: unit hiển thị tái sử dụng.
- `scripts/core/simulation_clock.gd`: RefCounted thuần, không phụ thuộc scene/render/input.
- `scripts/sandbox/arena.gd`: vẽ nền và lưới bằng primitive.
- `scripts/core/combat_engine.gd`: duel fixed-step, phát event dạng Dictionary có thể serialize.
- `scripts/core/stat_calculator.gd`, `damage_calculator.gd`: nguồn công thức duy nhất.
- `scripts/core/balance_settings.gd`: Resource hằng số cân bằng.
- `scripts/core/hit_calculator.gd`: evasion stacking, accuracy và hit/crit theo RNG.
- `scripts/effects/`: trạng thái effect, refresh/expiration và tổng hợp effect.
- `scripts/equipment/equipment_data.gd`: Resource ID/tên/mô tả/giá/modifiers/policy.
- `scripts/equipment/equipment_manager.gd`: sáu slot, validation và tổng hợp modifier duy nhất.
- `scripts/ui/equipment_panel.gd`: chọn slot và unit, hiển thị bonus/final stats.
- `scripts/units/`: Resource chỉ số gốc, trạng thái runtime và phần vẽ unit.
- `scripts/ui/sandbox_controller.gd`: điều khiển clock/engine và trình bày trạng thái/event.
- `data/units/*.tres`: thông tin hiển thị và nguồn stats riêng biệt.
- `data/balance/default_balance.tres`: thông số chuyển thuộc tính và giáp.
- `data/equipment/*.tres`: 12 món thử nghiệm, tất cả cho phép nhiều bản sao.
- `tests/test_phase1.gd` đến `test_phase4.gd`: test native Godot.

## Thêm trang bị

Tạo Resource `EquipmentData` trong `data/equipment/`, đặt ID duy nhất, tên,
mô tả, giá và modifiers; thêm `preload` vào CATALOG trong equipment_panel.gd
để xuất hiện trong UI. Ví dụ `physical_armor: 15.0` hoặc `accuracy: 0.3`.
Các modifier hỗ trợ được liệt kê trong EquipmentData.SUPPORTED_MODIFIERS.
Không cần thêm công thức riêng vào script hero. Đặt allow_multiple = false
để cấm nhiều bản sao của món trong một loadout. Chưa có item nào cần passive
đặc biệt, nên chưa xây framework passive không sử dụng.

Clock phát signal `ticked(tick_index)` theo thứ tự. Thời gian = số tick / 30;
phần thời gian dư chỉ dùng để lên lịch tick. Controller đăng ký combat engine
vào signal này, chuyển event sát thương sang số nổi và trạng thái HP/Mana sang bars.
Engine không tham chiếu Node, Control, input hay rendering.
Frame chậm được xử lý hết số tick tương ứng, không bỏ tick để che độ trễ.

Quy tắc combat: đánh ngay tick 1, sau đó theo APS; kiểm tra
khoảng cách tâm unit so với attack range. Các đòn cùng tick được thu thập trước
khi áp dụng sát thương để tránh ưu tiên Blue; cả hai có thể chết và hòa.
Thứ tự tick: hết hạn effect → xử lý lệnh effect đã xếp → hồi phục unit sống
→ thu thập đòn (hit rồi crit) → áp dụng các component
vật lý/phép/thuần → xử lý chết → xác định kết quả. Unit chết không hồi phục.
Event phân biệt raw damage, final damage sau giáp và applied damage thực mất HP
(không tính overkill). Primary attribute cộng vào sát thương vật lý cơ bản.

Chưa triển khai kỹ năng, AI, chỉnh base stats qua UI, 5v5 hoặc batch experiments.
Chi tiết công thức: `docs/combat_formulas.md`. Bước tiếp theo đề xuất là
**Phase 5 — Combat Sandbox**, chỉ khi được yêu cầu.
