# BÁO CÁO CÁC HIỆU ỨNG XẤU (DEBUFFS, CURSES, SCREEN EFFECTS & KNOCKBACKS) TRONG NULLSCAPE

Tài liệu này tổng hợp toàn bộ các hiệu ứng bất lợi (debuffs), lời nguyền (curses), hiệu ứng tối/biến dạng màn hình (screen visual effects) và cơ chế đẩy lùi (knockbacks) trong game. Các thông tin dưới đây được tra cứu và đối chiếu trực tiếp từ mã nguồn giải mã của game (`decompiled_Null.lua` và `MovementCore.luau`).

---

## I. HIỆU ỨNG TRẠNG THÁI (STATUS EFFECTS - CLIENT-SIDE)

Các hiệu ứng này được quản lý bởi hệ thống `StatusEffectHandler` trên Client, ảnh hưởng trực tiếp đến khả năng di chuyển hoặc giao diện của người chơi.

### 1. Concussion (Chấn thương)
* **Nguồn kích hoạt**: Rung chuông (**Bell**) khi đang chịu lời nguyền **Concussion**.
* **Hiệu ứng màn hình / Visual**: 
  * Nhân bản và hàn gắn (**Weld**) một mô hình quay tròn mang tên `Concussed` (gồm các hiệu ứng tia sáng/ngôi sao) trực tiếp lên **Đầu (Head)** của nhân vật, tạo hiệu ứng hoa mắt quay cuồng xung quanh camera.
* **Ảnh hưởng di chuyển**: 
  * Khóa hoàn toàn khả năng nhảy (**Jumping**) của người chơi trong vòng **7 giây**. Bất kỳ nỗ lực bấm phím Space để nhảy hoặc nhảy đúp đều bị trả về ngay lập tức (Dòng 1325 & 1574 trong `MovementCore.luau`).

### 2. Flesh (Xác thịt)
* **Nguồn kích hoạt**: Chạm vào các ô địa hình Flesh hoặc sàn kim loại bị ăn mòn (**CorrodedMetal**).
* **Hiệu ứng màn hình / Visual**:
  * Kích hoạt bộ lọc màu `game.Lighting.Flesh` làm nhuộm đỏ màn hình của người dùng (`TintColor = Color3.fromRGB(255, 160, 160)`, `Brightness = 0.1`, `Contrast = 0.2`, `Saturation = 1`).
  * Tạo một hiệu ứng highlight màu đỏ (`FleshHighlight` - độ trong suốt phần ruột `0.7`, viền đỏ đậm) bao bọc toàn bộ mô hình nhân vật của người chơi.
* **Ảnh hưởng di chuyển**:
  * Ép buộc hủy bỏ lập tức (**Force End**) tất cả các kỹ năng di chuyển đặc biệt đang hoạt động bao gồm: **Bắn móc (Grappling)**, **Lao xuống (Diving)**, **Hồn thể (Spirit)**, và **Tích lực (Charging)**.

### 3. Insanity (Điên loạn)
* **Nguồn kích hoạt**: Gây ra bởi lời nguyền **Cognitive Dissonance** (khi chạm vào các bản thể giả của thực thể **NIL**).
* **Hiệu ứng màn hình / Visual**:
  * Kích hoạt hiệu ứng lọc màu xám `game.Lighting.Grayscale`, đưa toàn bộ màn hình của người chơi về trạng thái **trắng đen hoàn toàn** (`Saturation = -1`).
  * Phát âm thanh thì thầm ma quái liên tục (`Insanity_Idle` và `SoloInsanity`).
  * Tự động sinh ra các ảo ảnh quái vật ma quái (`Mirage`) chạy xung quanh người chơi để gây rối loạn tầm nhìn.

### 4. Fire (Bốc cháy)
* **Nguồn kích hoạt**: Sát thương lửa hoặc lời nguyền bó hoa cháy (**Burning Bouquet**).
* **Hiệu ứng màn hình / Visual**:
  * Kích hoạt bộ lọc màu cam đỏ `game.Lighting.Fire` trên màn hình (`TintColor = Color3.fromRGB(255, 182, 148)`, `Saturation = 1.35`).
* **Ảnh hưởng di chuyển**:
  * Khóa cứng vectơ di chuyển của người chơi thành hướng thẳng về phía trước (`Vector3.new(0, 0, -1)`). Người chơi **không thể bẻ lái**, rẽ trái/phải hay đi lùi, chỉ có thể chạy thẳng theo hướng camera đang nhìn (Dòng 1842 trong `MovementCore.luau`).

### 5. Panic (Hoảng loạn)
* **Nguồn kích hoạt**: Các sự kiện gây hoảng loạn trong màn chơi.
* **Ảnh hưởng di chuyển**:
  * Vô hiệu hóa khả năng giảm ma sát khi trượt trên sàn kim loại bị ăn mòn (**CorrodedMetal**). Lực ma sát bị giữ nguyên ở mức `100%`, khiến người chơi không thể thực hiện các chuỗi trượt tăng tốc (slide chains) để tích lũy hoặc bảo toàn đà di chuyển.

### 6. Overtuned (Quá tải)
* **Nguồn kích hoạt**: Lời nguyền **Overtuned Springer**.
* **Hiệu ứng màn hình / Visual**:
  * Tạo một lớp phủ nhiễu sóng tivi cổ điển (Static Noise Overlay) đè lên màn hình người dùng thông qua việc đặt `ImageTransparency = 0.35` cho `StaticGUI.Static`.
  * Phát kèm tiếng rè rè, nhiễu sóng khó chịu (`script.Idle`).

### 7. Medal (Huy chương)
* **Nguồn kích hoạt**: Lời nguyền **Medal**.
* **Ảnh hưởng di chuyển**:
  * **Tích cực**: Tăng nhẹ tốc độ di chuyển thụ động thêm `10%`.
  * **Tiêu cực**: Triệt tiêu hoàn toàn lượng gia tốc nhảy móc (**Grapple Jump Velocity Boost**) khi người chơi móc vào các tấm **JumpPad**. Giới hạn tốc độ bay tối đa thoát ra bị bóp mạnh từ `180` studs/s (hoặc `140` studs/s) xuống chỉ còn vỏn vẹn **`120` studs/s** (hoặc **`75` studs/s** nếu có thêm lời nguyền WeakJumpPads) (Dòng 1253 trong `MovementCore.luau`).

---

## II. HIỆU ỨNG TỐI MÀN HÌNH & BIẾN DẠNG THỊ GIÁC (SCREEN DARKENING & VISUAL EFFECTS)

Các hiệu ứng tác động trực tiếp làm giảm độ sáng của màn hình, hạn chế tầm nhìn hoặc gây nhiễu loạn thị giác người chơi.

### 1. Darkness / Fear (Tối sầm màn hình)
* **Nguồn kích hoạt**: Đạt phòng 100 (**Level 100**) hoặc một số khu vực đặc biệt.
* **Hiệu ứng**: Bật `game.Lighting.Fear.Enabled = true`. Hiệu ứng này tạo một lớp bóng tối bao phủ xung quanh rìa màn hình (vignette) và kéo giảm tầm nhìn xa (Fog) xuống mức tối thiểu, khiến người chơi chỉ nhìn thấy khu vực rất gần xung quanh mình.

### 2. Chế độ đồ họa kỳ dị (Peculiar Graphics Mode)
* **Nguồn kích hoạt**: Cài đặt đồ họa trong game.
* **Hiệu ứng**: Khi chế độ này được kích hoạt, hệ thống sẽ hạ chỉ số phơi sáng của màn hình xuống mức cực hạn: `game.Lighting.ExposureCompensation = -12`. Toàn bộ màn chơi sẽ chìm vào **bóng tối đen kịt như mực**, ngoại trừ các chi tiết tự phát sáng (**Neon**) là có thể hiển thị.

### 3. Bão sét làm tối môi trường (Unkowned Biome Storm)
* **Nguồn kích hoạt**: Các giai đoạn giông bão sét trong màn chơi.
* **Hiệu ứng**: Môi trường xung quanh sẽ tự động tối sầm đi trước khi sét đánh thông qua việc hạ độ sáng môi trường của `game.Lighting.Ambient` từ `179` xuống `113` (`Color3.fromRGB(113, 113, 113)`).

### 4. Oblivion / Realistic Oblivion (Sự quên lãng)
* **Nguồn kích hoạt**: Lời nguyền thuộc nhóm Greater Curse.
* **Hiệu ứng màn hình**:
  * Khi Convergence diễn ra, màn hình bị nhuộm xám tối qua `game.Lighting.Oblivion` (`Brightness = 0.26`, `Contrast = 0.65`, `TintColor = Color3.fromRGB(223, 167, 167)`).
  * Khi bắt đầu hoặc kết thúc, màn hình sẽ bị **lóa sáng cực mạnh** thông qua chỉnh sáng (`Brightness = 2`, `Contrast = 3`).
* **Gameplay**:
  * **Mặc định (Oblivion)**: Quét tia raycast thẳng xuống chân (`Vector3.new(0, -1024, 0)`). Người chơi bắt buộc phải đứng trên một bề mặt vững chắc. Rơi tự do quá lâu sẽ làm đầy thanh đo phơi nhiễm và gây tử vong lập tức (**Obliterated**).
  * **Realistic Oblivion**: Quét tia ngược lên trời (`Vector3.new(0, 1024, 0)`). Người chơi bắt buộc phải đứng dưới các mái che/trần nhà, nếu đứng ngoài trời trống trải sẽ chết.

### 5. Pixelate (Điểm ảnh hóa)
* **Nguồn kích hoạt**: Lời nguyền **Pixelate**.
* **Hiệu ứng**: Làm nhòe và vỡ hạt pixel toàn bộ màn hình của người chơi bằng cách kích hoạt đối tượng `PixelateBlur` trong `Lighting`. Hiệu ứng này kéo dài vĩnh viễn suốt cả trận đấu, thậm chí ảnh hưởng cả khi bạn quay về Sảnh chờ (Lobby).

---

## III. CƠ CHẾ ĐẨY LÙI VÀ KHỐNG CHẾ LỰC (KNOCKBACK MECHANICS)

Cơ chế đẩy lùi từ các nguồn bẫy hoặc vật thể đặc biệt gây ảnh hưởng nghiêm trọng đến đà (momentum) của nhân vật.

### 1. Springer Shockwave (Sóng xung kích của Springer)
Khi người chơi chạm vào vòng sóng xung kích của Springer (`SpringerShockwave`), game sẽ tính toán lực đẩy lùi dựa trên khoảng cách và các lời nguyền hiện có (Dòng 1033 trong `MovementCore.luau`):
* **Hướng đẩy**: Hướng ngang đẩy ra xa tâm sóng xung kích: `local Unit = ((p1.RootPart.Position - p2.Position) * Vector3.new(1, 0, 1)).Unit`
* **Cường độ lực đẩy (`v3`)**:
  * **Trường hợp mặc định (Không có lời nguyền)**:
    * Lực đẩy cơ bản: `Unit * 40` (ngang) + `Vector3.new(0, 75, 0)` (dọc).
    * Nếu Springer có thuộc tính `"Big"`, lực đẩy nhân thêm **`1.3x`** (tổng: `52` ngang / `97.5` dọc).
  * **Trường hợp có lời nguyền `Springloaded` (Cực đại)**:
    * Lực đẩy tăng mạnh: **`Unit * 100` (ngang) + `Vector3.new(0, 120, 0)` (dọc)**.
    * Nếu Springer có thuộc tính `"Big"`, lực đẩy nhân thêm **`1.15x`** (tổng: `115` ngang / `138` dọc).
* **Lời nguyền `SpringerKill`**: Nếu lời nguyền này hoạt động, chạm vào sóng xung kích sẽ **chết ngay lập tức** thay vì bị đẩy lùi.
* **Thời gian khống chế**: Nhân vật bị ép chuyển sang trạng thái `Freefall`, gán vận tốc bằng lực đẩy `v3` và khóa cứng hướng di chuyển điều khiển (`WantDirection` và `MoveDirection`) theo hướng đẩy trong vòng **1 giây** (debounce).

### 2. Mighty Gong / Teleporting Bell Shockwave (Sóng xung kích của chuông)
* **Nguồn kích hoạt**: Chuông (**Bell**) dịch chuyển (teleport) khi đang kích hoạt lời nguyền **Mighty Gong**.
* **Cơ chế hoạt động**:
  * Khi chuông chuẩn bị biến mất và dịch chuyển (`WarpIn`), sau **1 giây** trì hoãn sẽ kích hoạt sóng xung kích `Harmonizer` dạng quả cầu năng lượng phình to.
  * **Bán kính ảnh hưởng**: **`38` studs** tính từ tâm chuông.
* **Hậu quả khống chế**:
  * **Hiệu ứng gián tiếp**: Tự động áp dụng tất cả hiệu ứng của một cú rung chuông trực tiếp (kích hoạt `Concussion` cấm nhảy nếu có lời nguyền Concussion, hoặc `Flesh` cấm kỹ năng nếu có Bloody Bell).
  * **Lực đẩy lùi (Knockback)**: Đẩy người chơi ra xa tâm chuông với lực đẩy tăng dần khi càng ở gần tâm. Công thức tính vận tốc đẩy lùi:
    $$\text{Velocity} = \text{Velocity} + \vec{u} \times (86 - d) \times 2.35$$
    *(Trong đó $\vec{u}$ là vectơ đơn vị hướng ra xa tâm chuông, $d$ là khoảng cách từ người chơi đến tâm chuông).*
    * Ở sát rìa vùng ảnh hưởng ($d = 38$ studs): Nhận lực đẩy **`112.8` studs/s**.
    * Ở ngay tâm chuông ($d = 0$ studs): Nhận lực đẩy cực đại lên tới **`202.1` studs/s** (gần như thổi bay người chơi ra khỏi bản đồ).
