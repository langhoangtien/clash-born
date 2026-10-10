# Clashborn — Phase 1

Nền tảng Godot cho sandbox chiến đấu MOBA 2D. Phiên này chỉ triển khai Phase 1:
arena 1600×900, hai unit hình tròn, đồng hồ mô phỏng 30 Hz và UI cơ bản.
Hai unit đứng yên; chưa có tấn công, chỉ số, HP/Mana, AI, kỹ năng hay trang bị.

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
- **Reset**: đưa thời gian về 0, xóa phần tick chưa hoàn tất, dừng đồng hồ; giữ tốc độ đã chọn.
- **Clock speed**: 0.5x, 1x, 2x hoặc 4x. Không thay đổi độ dài tick.

UI hiển thị trạng thái, thời gian mô phỏng và số tick. Các nút chỉ điều khiển
đồng hồ; cấu hình trận đấu và chỉnh stats sẽ được xây dựng ở phase sau.

## Kiểm tra

Import trước khi chạy test từ checkout mới để Godot đăng ký các lớp GDScript:

```powershell
$godotExe = 'C:\Users\Admin\.codex\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godotExe --headless --path 'D:\Clashborn' --editor --import
& $godotExe --headless --path 'D:\Clashborn' --script res://tests/test_phase1.gd
& $godotExe --path 'D:\Clashborn' --script res://tests/test_phase1.gd -- --capture
```

Test trả exit code 0 nếu pass, 1 nếu fail. Kiểm tra tick, pause/resume, reset,
tốc độ, độc lập tốc độ render, scene/unit và liên kết nút UI. Lệnh cuối chạy
renderer thật, lưu ảnh vào `.local/phase1-preview.png`, rồi tự thoát.

Đã xác minh trên máy hiện tại bằng Godot 4.7.2: import/editor thành công;
23 kiểm tra headless và 26 kiểm tra có renderer đều pass. Scene chính chạy
180 frame rồi thoát với exit code 0, không có lỗi runtime trong log.
Ảnh render 1280×720 đã được kiểm tra: hai unit và UI hiển thị đầy đủ.

## Cấu trúc và mở rộng

- `scenes/main.tscn`: điểm vào, ghép arena và controller UI.
- `scenes/sandbox/combat_sandbox.tscn`: arena và hai instance unit.
- `scenes/units/combat_unit.tscn`: unit hiển thị tái sử dụng.
- `scripts/core/simulation_clock.gd`: RefCounted thuần, không phụ thuộc scene/render/input.
- `scripts/sandbox/arena.gd`: vẽ nền và lưới bằng primitive.
- `scripts/units/`: Resource thông tin hiển thị và phần vẽ unit.
- `scripts/ui/sandbox_controller.gd`: chuyển thao tác UI sang lệnh đồng hồ, trình bày trạng thái.
- `data/units/*.tres`: ID, tên, màu và bán kính hai unit; không phải combat archetype.
- `tests/test_phase1.gd`: test native Godot, không dùng framework ngoài.

Clock phát signal `ticked(tick_index)` theo thứ tự. Thời gian = số tick / 30;
phần thời gian dư chỉ dùng để lên lịch tick. Bước tiếp theo có thể đăng ký
combat simulation vào signal này và giữ tính toán tách khỏi phần vẽ.
Frame chậm được xử lý hết số tick tương ứng, không bỏ tick để che độ trễ.

Đổi ngoại hình primitive qua các `.tres`. Thêm combat archetype, trang bị và
công thức chiến đấu chưa được hỗ trợ ở Phase 1. Bước đề xuất tiếp theo là
**Phase 2 — Core Combat**, chỉ khi được yêu cầu.
