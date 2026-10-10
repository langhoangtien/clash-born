# Clashborn — Phase 3

Sandbox chiến đấu MOBA 2D, hoàn thành đến **Phase 3 — Advanced Combat**.
Arena 1600×900, hai unit đấu tại vị trí cố định, STR/AGI/INT, HP/Mana và hồi phục,
sát thương vật lý/phép/thuần, giáp âm/dương, tấn công cơ bản và xử lý chết.
Combat chạy 30 Hz bằng trạng thái thuần GDScript, độc lập với scene/rendering.
Đã có attack speed, evasion/accuracy, chí mạng, status resistance,
stun, slow và giảm giáp; RNG có seed để tái hiện cùng chuỗi lệnh.

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
& $godotExe --path 'D:\Clashborn' --script res://tests/test_phase3.gd -- --capture
```

Chạy ba script headless ở trên để kiểm tra toàn bộ phần đã triển khai.
Test trả exit code 0 nếu pass, 1 nếu fail. Phase 1 kiểm tra clock/UI;
Phase 2 kiểm tra công thức, chuyển thuộc tính, hồi phục, tấn công đúng tick,
sát thương hỗn hợp, chết/hòa/reset, event JSON và kết quả giống nhau ở các tốc độ.
Phase 3 kiểm tra caps, evasion stacking, miss rate trên 10.000 lượt, accuracy,
crit flags/thứ tự RNG, lịch APS không trôi, stun/slow/armor stacking và expiration,
reset RNG/commands/effects, deterministic replay ở cả bốn tốc độ và nút debug UI.
Lệnh cuối chạy renderer thật, lưu ảnh hiệu ứng vào `.local/phase3-preview.png`,
rồi tự thoát. Đồng thời kiểm tra log để phát hiện lỗi runtime/rendering.

Đã xác minh bằng Godot 4.7.2: **170 kiểm tra Phase 3 headless**, **172 kiểm tra
Phase 3 có renderer**, **23 kiểm tra Phase 1** và **112 kiểm tra Phase 2** đều pass.
Scene chính chạy 180 frame, exit code 0; không có lỗi runtime/resource leak trong log.
Ảnh render 1280×720 đã được kiểm tra: stats, giáp âm, trạng thái và thời gian
còn lại của cả ba hiệu ứng hiển thị đầy đủ.

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
- `scripts/units/`: Resource chỉ số gốc, trạng thái runtime và phần vẽ unit.
- `scripts/ui/sandbox_controller.gd`: điều khiển clock/engine và trình bày trạng thái/event.
- `data/units/*.tres`: thông tin hiển thị và nguồn stats riêng biệt.
- `data/balance/default_balance.tres`: thông số chuyển thuộc tính và giáp.
- `tests/test_phase1.gd`, `test_phase2.gd`, `test_phase3.gd`: test native Godot.

Clock phát signal `ticked(tick_index)` theo thứ tự. Thời gian = số tick / 30;
phần thời gian dư chỉ dùng để lên lịch tick. Controller đăng ký combat engine
vào signal này, chuyển event sát thương sang số nổi và trạng thái HP/Mana sang bars.
Engine không tham chiếu Node, Control, input hay rendering.
Frame chậm được xử lý hết số tick tương ứng, không bỏ tick để che độ trễ.

Quy tắc thử nghiệm Phase 3: đánh ngay tick 1, sau đó theo APS; kiểm tra
khoảng cách tâm unit so với attack range. Các đòn cùng tick được thu thập trước
khi áp dụng sát thương để tránh ưu tiên Blue; cả hai có thể chết và hòa.
Thứ tự tick: hết hạn effect → xử lý lệnh effect đã xếp → hồi phục unit sống
→ thu thập đòn (hit rồi crit) → áp dụng các component
vật lý/phép/thuần → xử lý chết → xác định kết quả. Unit chết không hồi phục.
Event phân biệt raw damage, final damage sau giáp và applied damage thực mất HP
(không tính overkill). Primary attribute cộng vào sát thương vật lý cơ bản.

Chưa triển khai kỹ năng, trang bị, AI, chỉnh stats qua UI, 5v5 hoặc batch experiments.
Chi tiết công thức: `docs/combat_formulas.md`. Bước tiếp theo đề xuất là
**Phase 4 — Equipment**, chỉ khi được yêu cầu.
