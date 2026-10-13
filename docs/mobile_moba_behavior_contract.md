# Clashborn — Mobile MOBA Behavior Contract

**Trạng thái:** Proposed — chờ duyệt gameplay  
**Phiên bản:** 1.0  
**Nguồn luật duy nhất cho:** lính lane, lính công thành, quái rừng, trụ, nhà chính,
Recall/Fountain và bot hero.

## 1. Mục đích và phạm vi

Contract này định nghĩa hành vi nền tảng theo quy ước MOBA mobile quen thuộc
(như Liên Quân Mobile và Mobile Legends): có thể dựa vào để chơi, dự đoán và
test, nhưng không sao chép thông số hoặc luật phiên bản cụ thể của bất kỳ game
nào.

Contract xác định **quy tắc**, thứ tự ưu tiên và vòng đời quyết định. Các con
số như sát thương, máu, phạm vi, thời lượng và tốc độ là **tham số cân bằng**;
chúng không được dùng để thay đổi ý nghĩa của luật.

Ngoài phạm vi bản 1.0: kỹ năng đặc biệt làm đổi aggro, tàng hình, triệu hồi,
taunt, teleport, boss mục tiêu lớn, inhibitor và super creep. Một tính năng
ngoài phạm vi không được lặng lẽ phá luật trong tài liệu này.

## 2. Thuật ngữ chuẩn

| Thuật ngữ | Nghĩa |
| --- | --- |
| **Actor** | Một thực thể có thể quyết định: creep, quái rừng, trụ, core hoặc bot hero. |
| **Intent** | Quyết định duy nhất của actor ở một thời điểm: `state`, `target_id`, `destination`, `expiry_tick`, `reason`. |
| **Legal target** | Mục tiêu còn sống, là địch, nhìn thấy/đánh được, không bị khoá và thoả mọi ràng buộc state. |
| **Aggro** | Việc actor đã chọn mục tiêu combat. Không đồng nghĩa với chỉ đứng gần. |
| **Leash** | Giới hạn actor được phép đuổi mục tiêu, tính từ một origin được quy định cho từng state. |
| **Direct hero damage** | Damage có nguồn là hero và đích là hero địch; không gồm phản damage, môi trường hay một sự kiện đã bị đánh dấu `reflected`. |
| **Recall** | Kênh quay về fountain. Unit không di chuyển/đánh trong lúc channel; damage nhận vào huỷ Recall. |

## 3. Luật hệ thống bắt buộc

1. Mỗi actor có đúng **một Intent đang hiệu lực**. Chỉ controller của loại actor
   đó được tạo Intent và chỉ world executor được áp Intent thành lệnh di chuyển
   hay combat.
2. Mỗi lần ra quyết định dùng snapshot nhất quán của thế giới theo thứ tự:
   `event của tick trước → validate target hiện tại → chọn intent → áp một lệnh → resolve combat`.
3. Không helper tổng quát, UI, damage callback hay lane follower nào được ghi
   trực tiếp `target_id`, đường đi hoặc gọi lệnh di chuyển cho actor AI.
4. Target hợp lệ được xếp theo thứ tự: **priority rule → khoảng cách mép hitbox
   ngắn nhất → unit id tăng dần**. Vì vậy replay cùng input phải cho kết quả
   giống nhau.
5. Actor giữ target hiện tại nếu target còn hợp lệ trong state hiện tại. Không
   đổi target chỉ vì có mục tiêu mới gần hơn; chỉ đổi khi luật ưu tiên cao hơn
   xuất hiện, target mất hợp lệ hoặc target lock hết hạn.
6. Khi path đến target thất bại, actor bỏ intent combat đó, ghi lý do
   `UNREACHABLE`, đi về state fallback của mình và có cooldown trước khi thử lại.
7. Mọi bán kính đều tính theo khoảng cách giữa mép collision, không theo tâm
   sprite. Mọi đơn vị thời gian được lưu theo simulation tick, không theo FPS.

## 4. Tham số cân bằng đề xuất ban đầu

Các giá trị này là baseline có thể tune sau playtest; đổi số không đổi thứ tự
ưu tiên.

| Key | Giá trị khởi đầu | Ý nghĩa |
| --- | ---: | --- |
| `lane_creep.detect_range` | 600 | Bán kính tìm lính lane địch. |
| `lane_creep.chase_leash` | 850 | Leash combat lính-lính, tính từ điểm bắt đầu đuổi. |
| `lane_creep.hero_aggro_range` | 600 | Vùng creep nhận call-for-help. |
| `lane_creep.hero_leash` | 500 | Leash khi creep trả đũa hero. |
| `lane_creep.hero_aggro_duration` | 3 giây | Thời gian tối đa đuổi hero sau call-for-help. |
| `tower.protection_radius` | 700 | Vùng hero đồng minh được trụ bảo hộ. |
| `tower.target_lock` | 0.5 giây | Lock chống flicker cho target thông thường. |
| `jungle.detect_radius` | 350 | Vùng quái có thể nhận aggro khi bị kích hoạt. |
| `jungle.home_leash` | 420 | Bán kính tối đa tính từ camp center. |
| `jungle.aggro_duration` | 10 giây | Thời gian tối đa quái giữ aggro. |
| `recall.channel_time` | 4 giây | Thời gian channel Recall. |
| `fountain.radius` | 250 | Vùng hồi phục ở nhà. |
| `bot.recall_hp_threshold` | 28% HP | Ngưỡng bot cân nhắc Recall. |
| `bot.recover_hp_threshold` | 72% HP | HP tối thiểu để bot rời fountain. |

## 5. Lính lane và lính công thành

Lính thường, lính đánh xa và lính công thành dùng cùng state machine. Lính
công thành chỉ khác chỉ số và hệ số damage công trình; không có luật aggro
riêng.

### 5.1 Priority và state

| Ưu tiên | State | Điều kiện vào | Target / hành động | Điều kiện thoát |
| ---: | --- | --- | --- | --- |
| 1 | `HERO_RETALIATE` | Hero địch gây direct hero damage lên hero đồng minh trong `hero_aggro_range` của creep | Chỉ hero gây damage; đuổi/đánh trong `hero_leash` | 3 giây hết hạn, target chết, vượt leash hoặc không tới được |
| 2 | `LANE_COMBAT` | Có lính lane địch hợp lệ trong `detect_range` | Lính lane địch gần nhất; không bao gồm quái rừng | Target chết, vượt `chase_leash` hoặc không tới được |
| 3 | `STRUCTURE_SIEGE` | Không có lính lane địch hợp lệ và công trình kế tiếp của lane hợp lệ/được phát hiện | Chỉ công trình kế tiếp theo chuỗi | Công trình chết/khoá; xuất hiện lính lane địch; path lỗi |
| 4 | `LANE_ADVANCE` | Không có state cao hơn | Đi waypoint kế tiếp của lane mình | Có state cao hơn hoặc hết route |
| 5 | `RETURN_TO_LANE` | Mất target sau khi chase/path lỗi | Đi waypoint forward gần nhất trên lane của mình | Đạt waypoint hoặc có state cao hơn |

### 5.2 Quy tắc quan trọng

- Lính không chủ động target hero chỉ vì hero đi qua, đứng gần, đánh lính hay
  đánh trụ. Chỉ `HERO_RETALIATE` mới cho phép creep đánh hero.
- Một call-for-help chỉ ảnh hưởng creep lane cùng lane với hero bị đánh.
- `HERO_RETALIATE` là intent bị giới hạn, không kéo creep qua trụ, sang lane
  khác hoặc về fountain. Hết leash là bỏ target ngay.
- Khi hai wave gặp nhau, creep phải thực sự exchange combat trước khi creep
  nào tiếp tục waypoint. Không được xuyên qua wave vì target scan chậm.
- Creep chỉ chọn **công trình kế tiếp** trên lane. Không tìm global, không nhảy
  qua T1/T2/T3, không dùng fallback sang trụ sâu hơn nếu registry thiếu.
- Nếu registry chuỗi công trình thiếu hoặc không nhất quán: creep dừng an toàn
  với state `CONFIG_ERROR`, ghi lỗi debug; không tự đoán target.

## 6. Trụ, base guard và core

Trụ/core bất động. `target_id` của chúng là target combat duy nhất; chúng không
phát lệnh navigation.

### 6.1 Target priority

| Ưu tiên | Intent | Điều kiện | Target |
| ---: | --- | --- | --- |
| 1 | `PROTECT_HERO` | Hero địch ở trong tầm trụ đã gây direct hero damage lên hero đồng minh đang ở trong `protection_radius` | Hero aggressor đó |
| 2 | `DEFEND_MINION` | Có lính lane/catapult địch trong attack range | Lính theo ưu tiên loại: siege → melee → ranged; rồi khoảng cách/id |
| 3 | `DEFEND_HERO` | Không có lính hợp lệ trong tầm | Hero địch gần nhất |
| 4 | `IDLE` | Không target hợp lệ | Không làm gì |

### 6.2 Quy tắc aggro trụ

- `PROTECT_HERO` ghi đè target lính ngay lập tức ở tick quyết định kế tiếp và
  được giữ đến khi hero aggressor chết, rời attack range hoặc protection event
  không còn hợp lệ. Không đổi sang hero khác chỉ vì hero đó gần hơn.
- Trụ không đổi target thông thường trong `tower.target_lock` nếu target còn
  hợp lệ. Lock chỉ chống flicker, không chặn `PROTECT_HERO`.
- Hero không bị trụ đánh chỉ vì đứng trong tầm khi còn lính địch hợp lệ;
  nhưng sẽ nhận aggro nếu kích hoạt `PROTECT_HERO`.
- Quái rừng không phải target hợp lệ của trụ. Pet/summon được thêm sau này phải
  có priority riêng, không được ngầm coi như creep.
- Công trình bị khoá vẫn có thể phòng thủ nếu thiết kế map yêu cầu, nhưng không
  nhận damage và không được người chơi/AI chọn làm objective phá huỷ.

### 6.3 Chuỗi phá công trình và điều kiện mở khoá

Đây là luật **damageability** bắt buộc; nó không phải chỉ là gợi ý target cho
AI. Một công trình đang khoá vẫn hiển thị trên map và có thể phòng thủ, nhưng
mọi damage vào nó phải bị từ chối bởi combat resolver.

```text
TOP:  T1_TOP  → T2_TOP  → T3_TOP ┐
MID:  T1_MID  → T2_MID  → T3_MID ├─ phá ÍT NHẤT MỘT T3 → mở cả T4_LEFT, T4_RIGHT
BOT:  T1_BOT  → T2_BOT  → T3_BOT ┘

T4_LEFT + T4_RIGHT đều bị phá → mở CORE
```

| Công trình | Điều kiện để nhận damage / được chọn làm objective |
| --- | --- |
| `T1_<lane>` | Luôn mở từ đầu match. |
| `T2_<lane>` | `T1_<lane>` đã bị phá. |
| `T3_<lane>` | `T2_<lane>` đã bị phá. |
| `T4_LEFT`, `T4_RIGHT` | **Ít nhất một** trong `T3_TOP`, `T3_MID`, `T3_BOT` đã bị phá. Cả hai T4 cùng mở. |
| `CORE` | Cả `T4_LEFT` và `T4_RIGHT` đã bị phá. |

Vì thế T1/T2/T3 mở khoá **độc lập theo từng lane**: phá T1 TOP không được mở
T2 MID/BOT; phá T3 TOP có thể mở hai T4 base. Chỉ T4/Core là objective chung.
Một entity đã chết phải bị loại khỏi collision, chọn mục tiêu và registry runtime
ngay.

### 6.4 Cấu trúc objective bắt buộc cho AI

World phải lưu objective bằng semantic ID, prerequisite rõ ràng, không suy luận
bằng vị trí hay bằng việc “trụ nào gần nhất”. Ví dụ schema dữ liệu:

```text
StructureNode {
  id: "red_mid_t2",
  team: RED,
  lane: MID | BASE,
  tier: 1 | 2 | 3 | 4 | CORE,
  prerequisites_all: ["red_mid_t1"],
  prerequisites_any: [],
  alive: true
}

red_base_guard_left.prerequisites_any  = [red_top_t3, red_mid_t3, red_bot_t3]
red_base_guard_right.prerequisites_any = [red_top_t3, red_mid_t3, red_bot_t3]
red_core.prerequisites_all             = [red_base_guard_left, red_base_guard_right]
```

`is_attackable(node)` phải là hàm duy nhất kiểm tra:

1. Node còn sống;
2. Mọi ID trong `prerequisites_all` đã chết;
3. Nếu có `prerequisites_any`, có ít nhất một ID trong danh sách đã chết.

Không controller nào tự kiểm tra tier, scan “trụ sống gần nhất”, hay có fallback
sang trụ sâu hơn. Registry thiếu ID/prerequisite là `CONFIG_ERROR`, dừng lựa
chọn objective và báo debug.

### 6.5 Luật target objective của creep và bot

- Creep ở TOP/MID/BOT chỉ được gọi `next_lane_objective(team, own_lane)`. Hàm
  này trả về lần lượt T1, T2, T3 **cùng lane**, và chỉ khi node đó attackable.
- Khi đã hết T1/T2/T3 của lane, creep không được tự chọn T4 hay Core. Creep
  tiếp tục lane route/rally base; `BaseObjectiveController` là controller duy
  nhất có thể phân công T4 sau khi chúng được mở khoá.
- Hero bot có thể nhận T4 qua `BaseObjectiveController`, nhưng chỉ khi ít nhất
  một T3 đã chết, T4 còn sống và có creep cover. Core chỉ là target sau khi cả
  hai T4 chết.
- Combat resolver phải gọi `is_attackable` ở lúc impact, không chỉ lúc chọn
  target. Do đó projectile đã bay cũng không thể gây damage lên objective vừa
  bị khoá/không hợp lệ.
- Nếu creep đang đuổi hero (`HERO_RETALIATE`), leash giới hạn ở origin của
  event. Khi target chạy về phía T3 hay base, creep phải bỏ chase khi hết
  `hero_leash`, quay về `RETURN_TO_LANE`, rồi mới evaluate T1/T2/T3 hợp lệ.
  Creep không bao giờ dùng vị trí hero để suy ra objective sâu hơn.

## 7. Quái rừng

Quái rừng là neutral NPC, độc lập hoàn toàn với lane.

| Ưu tiên | State | Điều kiện vào | Hành động | Điều kiện thoát |
| ---: | --- | --- | --- | --- |
| 1 | `RETALIATE` | Bị hero/unit playable gây damage, hoặc bị kích hoạt theo rule camp trong `detect_radius` | Đánh aggressor đã kích hoạt | Target chết, hết 10 giây, target/monster ra `home_leash`, path lỗi |
| 2 | `RETURN_HOME` | `RETALIATE` bị thoát và quái không ở camp center | Bỏ target, về camp center | Trong bán kính reset của center |
| 3 | `IDLE_HOME` | Spawn hoặc đã về camp | Đứng tại camp | Nhận kích hoạt hợp lệ |

- Quái chỉ target unit đã tạo aggro; không target lính lane, trụ, hero chỉ đi
  ngang hoặc mục tiêu global.
- Khi `RETURN_HOME`, camp reset: dừng combat, xoá aggro, hồi máu theo rule camp
  đã chọn. Bản 1.0 chọn **hồi đầy ngay khi về camp center** để dễ đọc/test.
- Một camp chỉ respawn khi toàn bộ thành viên camp đã chết; respawn đủ cả camp
  sau cùng một timer. Không respawn từng con.
- Camp center phải nằm ngoài lane corridor cộng buffer để lane/path không vô
  tình kích hoạt camp.

## 8. Hero người chơi, Recall và Fountain

### 8.1 Player

- Di chuyển thủ công hủy attack order, target lock và Recall.
- Lệnh attack click giữ target được click cho đến khi target chết, mất vision,
  vượt command leash, người chơi hủy hoặc ra lệnh mới.
- Lệnh auto-attack chỉ tìm trong command radius local; không tìm toàn bản đồ.
- Player **không** tự động chạy về fountain khi HP thấp. Quyết định rút lui là
  của người chơi.

### 8.2 Recall

| State | Điều kiện vào | Hành động | Điều kiện thoát |
| --- | --- | --- | --- |
| `RECALL_CHANNEL` | Người chơi nhấn Recall, hoặc bot quyết định Recall | Dừng di chuyển/đánh, đếm `recall.channel_time` | Hoàn tất: teleport fountain; nhận direct damage, di chuyển, đánh/cast chủ động hoặc chết: hủy |
| `FOUNTAIN_RECOVER` | Unit đang trong fountain và chưa đủ điều kiện rời | Không combat; nhận HP/mana hồi theo giây | Player ra lệnh; bot đạt ngưỡng hồi phục |

- Fountain chỉ hồi HP/mana cho unit trong `fountain.radius`; không tự hồi ngoài
  vùng này.
- Hồi fountain không resurrect unit chết. Respawn là hệ thống riêng.

## 9. Bot hero

Bot dùng cùng luật combat, Recall và Fountain với player; khác duy nhất là
nguồn phát lệnh là bot controller.

| Ưu tiên | State | Điều kiện | Action |
| ---: | --- | --- | --- |
| 1 | `DEAD` | Không còn sống | Chờ respawn |
| 2 | `RECALL_CHANNEL` / `FOUNTAIN_RECOVER` | HP ≤ retreat threshold; hoặc Recall/Fountain đang diễn ra | Recall hợp lệ, hồi đến recover threshold |
| 3 | `EXIT_TOWER_RANGE` | Trụ địch đang target bot | Chỉ đi ra ngoài range + safety margin; không đánh trả trong lúc thoát |
| 4 | `HERO_RETALIATE` | Player hero vừa gây direct hero damage lên bot và chase an toàn | Đánh player trong leash/time giới hạn |
| 5 | `DEFEND_BASE` | Lính lane địch vào base-defense radius | Đánh lính intruder |
| 6 | `LANE_FIGHT` | Có lính lane địch local | Đánh creep ưu tiên gần nhất |
| 7 | `HERO_FIGHT` | Hero địch local và không tower dive không có creep cover | Đánh hero |
| 8 | `SIEGE` | Công trình kế tiếp mở khoá, local và có allied creep cover | Đánh công trình |
| 9 | `RALLY` | Không có mục tiêu ưu tiên cao hơn | Theo frontline cùng lane; không có frontline thì chờ ngoài range trụ kế tiếp |

- Bot không được quay về fountain chỉ vì wave chết hoặc không còn target.
- `EXIT_TOWER_RANGE` chỉ kết thúc khi bot thực sự ra khỏi attack range cộng
  safety margin; sau đó evaluate lại bảng từ đầu.
- Bot chỉ Recall khi không đang bị trụ target và có thể channel an toàn. Nếu bị
  chase/có direct damage mới, bot có thể ưu tiên di chuyển về vị trí an toàn rồi
  Recall; không được teleport miễn phí.
- `HERO_RETALIATE` cao hơn farm/siege để player không thể đánh bot miễn phí.

## 10. Event, quyền sở hữu và thực thi

### 10.1 Event facts

Damage event chỉ được tạo **fact có thời hạn**, không được tự phát movement:

| Event | Fact được tạo | Consumer duy nhất |
| --- | --- | --- |
| Hero A direct-damage hero B | `hero_damage_fact(attacker, victim, tick)` | creep lane gần victim, trụ của victim, bot là victim |
| Playable unit damage quái rừng | `camp_aggro_fact(attacker, camp, tick)` | controller quái rừng của camp |
| Trụ bắt đầu target bot | `tower_threat_fact(tower, bot, tick)` | bot controller |
| Target chết/không tới được | `target_invalid_fact(target, reason)` | controller đang sở hữu actor |

Facts được consume trước bước `decide` của tick kế tiếp; loại event này phải
được trace để QA thấy ai đổi aggro vì điều gì.

### 10.2 Ownership bắt buộc

| Actor | Controller quyết định | Executor duy nhất phát movement/combat |
| --- | --- | --- |
| Lane creep/catapult | `LaneCreepController` | `MatchIntentExecutor` |
| Jungle creep | `JungleCreepController` | `MatchIntentExecutor` |
| Tower/base guard/core | `StructureController` | `MatchIntentExecutor` (combat-only) |
| Bot hero | `BotHeroController` | `MatchIntentExecutor` |
| Player hero | `PlayerCommandController` | `MatchIntentExecutor` |

`MatchScene` chỉ là world adapter: snapshot, query, event queue, intent
executor và lifecycle. Nó không chứa priority table riêng của bất cứ loại actor
nào.

## 11. Debug và tiêu chí nghiệm thu

Mọi thay đổi state/target phải ghi: `tick, actor_id, old_state, new_state,
reason, old_target, new_target, destination`. Debug overlay phải xem được Intent
hiện hành, target, remaining leash/expiry và source của movement order.

Contract được xem là implement đúng khi tối thiểu các scenario sau pass:

1. Hai wave chạm nhau: mỗi bên chọn lính địch và gây damage trước khi advance.
2. Khi wave địch chết, creep sống sót chỉ target T1 hợp lệ cùng lane; không
   target T2/T3/base guard/core.
3. T2 MID không nhận damage trước khi T1 MID chết; T3 MID không nhận damage
   trước khi T2 MID chết. Việc phá tower ở TOP/BOT không làm thay đổi hai luật
   này của MID.
4. Khi chưa có T3 nào bị phá, cả T4 đều từ chối damage. Khi một T3 bất kỳ chết,
   cả hai T4 cùng trở thành attackable; Core vẫn từ chối damage cho đến khi cả
   hai T4 chết.
5. Hero đánh hero gần wave: creep cùng lane trả đũa tối đa 3 giây/500 range,
   sau đó trở lại lane.
6. Trụ đang bắn lính: hero đánh hero đồng minh trong vùng trụ thì trụ đổi sang
   hero aggressor; hero rời range thì trụ chọn lại lính hợp lệ.
7. Hero đứng trong tầm trụ nhưng không gây damage hero: trụ vẫn ưu tiên lính.
8. Quái rừng bị đánh rồi bị kéo quá leash: bỏ target, về camp, reset full HP;
   không đi sang lane và không target lính.
9. Player thấp HP không tự về nhà; Recall hoàn thành mới teleport. Damage trong
   channel hủy Recall.
10. Bot thấp HP Recall đúng luật, hồi đủ ở fountain, rồi ưu tiên dọn lính vào
   base trước khi quay lại rally/lane.
11. Bot bị trụ target: rời tower range trước; không vừa chạy vừa chọn siege.
12. Cùng snapshot, replay 100 lần cho cùng state/target/movement trace.

## 12. Quy trình thay đổi contract

1. Mọi luật mới hoặc ngoại lệ phải được thêm vào tài liệu này trước.
2. Mỗi thay đổi phải nêu actor bị ảnh hưởng, priority, entry/exit, event source
   và regression scenario mới.
3. Thay đổi balance-only cập nhật asset/settings; không sửa controller logic.
4. Khi contract được duyệt, các tài liệu `behavior_contract_v2.md` và
   `ai_state_machine.md` trở thành tài liệu lịch sử hoặc được rút gọn để trỏ về
   tài liệu này. Không duy trì nhiều bảng ưu tiên song song.
