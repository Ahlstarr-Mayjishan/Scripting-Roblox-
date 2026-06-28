# BÁO CÁO CÁC HIỆU ỨNG XẤU (DEBUFFS, CURSES & SCREEN EFFECTS) TRONG NULLSCAPE

Tài liệu này tổng hợp toàn bộ các hiệu ứng bất lợi (debuffs), lời nguyền (curses) và các hiệu ứng biến dạng màn hình (screen visual effects) ảnh hưởng trực tiếp đến Client và màn hình của người chơi trong game. Các thông tin dưới đây được tra cứu trực tiếp từ mã nguồn giải mã của game (`decompiled_Null.lua` và `MovementCore.luau`).

---

## I. HIỆU ỨNG TRẠNG THÁI NỔI BẬT (STATUS EFFECTS - CLIENT-SIDE)

Các hiệu ứng này được quản lý bởi hệ thống `StatusEffectHandler` trên Client và ảnh hưởng trực tiếp đến khả năng di chuyển hoặc giao diện của người chơi.

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
  * **Tích cơ bản**: Tăng nhẹ tốc độ di chuyển thụ động thêm `10%`.
  * **Tiêu cực**: Triệt tiêu hoàn toàn lượng gia tốc nhảy móc (**Grapple Jump Velocity Boost**) khi người chơi móc vào các tấm **JumpPad**. Giới hạn tốc độ bay tối đa thoát ra bị bóp mạnh từ `180` studs/s (hoặc `140` studs/s) xuống chỉ còn vỏn vẹn **`120` studs/s** (hoặc **`75` studs/s** nếu có thêm lời nguyền WeakJumpPads) (Dòng 1253 trong `MovementCore.luau`).

---

## II. LỜI NGUYỀN MÔI TRƯỜNG & BIẾN DẠNG MÀN HÌNH (ENVIRONMENTAL CURSES & VISUAL EFFECTS)

Các hiệu ứng này tác động lên toàn cảnh môi trường chơi, thời tiết hoặc bẻ cong camera để tăng độ khó và hạn chế tầm nhìn của người chơi.

### 1. Oblivion / Realistic Oblivion (Sự quên lãng)
* **Nguồn kích hoạt**: Lời nguyền thuộc nhóm Greater Curse.
* **Hiệu ứng màn hình / Visual**:
  * Tạo các hạt đen bụi mù mịt (`OblivionAttack`, `OblivionAmbient`) bay xung quanh góc nhìn của người chơi.
  * Hiển thị một thanh đo mức độ phơi nhiễm màu tím (`OblivionBar`) trên màn hình. Mức độ phơi nhiễm càng cao, màn hình càng rung lắc dữ dội (`OblivionShake`), âm thanh cảnh báo càng dồn dập.
  * Khi bắt đầu hoặc kết thúc (sống sót/chết), màn hình sẽ bị **lóa sáng cực mạnh** thông qua chỉnh sáng `game.Lighting.Oblivion` (`Brightness = 2`, `Contrast = 3`).
* **Gameplay / Cơ chế**:
  * **Mặc định (Oblivion)**: Hệ thống liên tục quét một tia raycast thẳng xuống dưới chân (`Vector3.new(0, -1024, 0)`). Người chơi bắt buộc phải đứng trên một bề mặt vững chắc. Nếu lơ lửng trên không trung hoặc rơi tự do quá lâu, thanh đo phơi nhiễm sẽ đầy và gây tử vong lập tức (**Obliterated**).
  * **Realistic Oblivion**: Hướng quét tia ngược lên trời (`Vector3.new(0, 1024, 0)`). Người chơi bắt buộc phải đứng dưới các mái che/trần nhà. Đứng ngoài trời trống trải sẽ tích lũy phơi nhiễm và chết.

### 2. Pixelate (Điểm ảnh hóa)
* **Nguồn kích hoạt**: Lời nguyền **Pixelate**.
* **Hiệu ứng màn hình / Visual**:
  * Làm nhòe và vỡ hạt pixel toàn bộ màn hình của người chơi bằng cách kích hoạt đối tượng `PixelateBlur` trong `Lighting`. Hiệu ứng này kéo dài vĩnh viễn suốt cả trận đấu, thậm chí ảnh hưởng cả khi bạn quay về Sảnh chờ (Lobby).

### 3. Fear (Sợ hãi)
* **Nguồn kích hoạt**: Kích hoạt khi người chơi đạt đến Phòng 100 (**Level 100**) hoặc một số khu vực đặc biệt.
* **Hiệu ứng màn hình / Visual**:
  * Kích hoạt tính năng `game.Lighting.Fear.Enabled = true`, tạo hiệu ứng tối sầm ở các góc màn hình (vignette) và giảm mạnh tầm nhìn xa để tạo không khí kinh dị.

### 4. Rung nhiễu & Bão xoáy (Hiệu ứng Biome Storm - Level 5 đến 30+)
Trong các màn chơi có cấp độ bão lớn (như bão sét trong biome Unkowned), Client sẽ bị ép chịu các hiệu ứng biến đổi ánh sáng/camera cực kỳ khó chịu:
* **Pulsating Blur (Cấp 5+)**: Màn hình liên tục co giãn độ mờ (blur) theo hàm sin: `Blur.Size = math.sin(time() * 3) ^ 4 * v23 * 2`, gây mỏi mắt và khó ngắm bắn.
* **Spinning Sun (Cấp 7+)**: Trục ánh sáng mặt trời liên tục xoay tròn 360 độ: `game.Lighting.GeographicLatitude = time() * 90 * v26 % 360`, khiến các bóng đổ của địa hình quay cuồng liên tục trên mặt đất.
* **Viewport Shake/Tilt (Cấp 30+)**: Góc nghiêng camera (`CFrame.Angles`) liên tục bị bẻ cong theo các trục ngẫu nhiên dựa trên thuật toán tiếng ồn (`math.noise`), gây hiện tượng lệch tâm ngắm vật lý.

### 5. Razorbloom (Chim bẫy)
* **Nguồn kích hoạt**: Lời nguyền **Razorbloom**.
* **Gameplay / Cơ chế**:
  * Một con chim Razorbloom sẽ đậu trực tiếp lên đầu nhân vật của bạn. Nó sẽ liên tục gây bất lợi cho đến khi bạn đi qua và chạm vào một tấm **Jump Pad** để xua đuổi nó đi.

---

## III. CÁC LOẠI LỰC ĐẨY & GIẬT MÀN HÌNH (KNOCKBACKS & SHOCKWAVES)

Hệ thống tính toán lực đẩy (knockback) vật lý khi người chơi va chạm với các đợt sóng xung kích (shockwaves) hoặc các vụ nổ trong game:

### 1. Springer Shockwave (Sóng xung kích của Springer)
* **Nguồn kích hoạt**: Người chơi chạm vào Part mang tên `SpringerShockwave`.
* **Hiệu ứng vật lý (Knockback)**:
  * Vectơ hướng đẩy ngang hướng từ tâm sóng xung kích ra ngoài: `Unit = ((RootPart.Position - Shockwave.Position) * Vector3.new(1, 0, 1)).Unit`.
  * **Trường hợp chịu lời nguyền `Springloaded`**:
    * Lực đẩy rất mạnh: `Vận tốc = Unit * 100 + Vector3.new(0, 120, 0)` (100 studs/s theo chiều ngang và 120 studs/s hất tung lên trời).
    * Nếu Springer có thuộc tính `Big` (Khổng lồ): Lực đẩy nhân tiếp với `1.15` (115 studs/s ngang và 138 studs/s dọc).
  * **Trường hợp bình thường (Không có Springloaded)**:
    * Lực đẩy tiêu chuẩn: `Vận tốc = Unit * 40 + Vector3.new(0, 75, 0)` (40 studs/s ngang và 75 studs/s dọc).
    * Nếu Springer có thuộc tính `Big`: Lực đẩy nhân tiếp với `1.3` (52 studs/s ngang và 97.5 studs/s dọc).
* **Lời nguyền chí mạng (`SpringerKill`)**: 
  * Nếu lời nguyền này đang hoạt động, chạm vào sóng xung kích Springer sẽ **gây tử vong ngay lập tức** thay vì bị đẩy.
  * Nếu không chết, trạng thái Humanoid của người chơi chuyển thành `Freefall`, bị áp đặt đà bay và hướng đi theo vectơ lực đẩy trên. Áp dụng debounce **1 giây** trước khi có thể bị trúng đợt đẩy tiếp theo.

### 2. Cursed Bell / Mighty Gong (Sóng đẩy của Chuông nguyền)
* **Nguồn kích hoạt**: Chuông dịch chuyển tức thời (teleport) khi đang chịu lời nguyền **Mighty Gong**.
* **Hiệu ứng vật lý (Knockback)**:
  * Khi chuông dịch chuyển, nó tạo ra một quả cầu xung kích tàng hình nở rộng từ bán kính `85` studs lên `115` studs.
  * Quét tất cả người chơi trong **bán kính 38 studs** tính từ tâm dịch chuyển.
  * Mức độ đẩy tỷ lệ nghịch với khoảng cách từ người chơi đến tâm chuông:
    `Vận tốc cộng thêm = Unit * (86 - Khoảng_Cách) * 2.35` (trong đó `Unit` hướng từ tâm chuông ra người chơi).
    * *Đứng sát tâm chuông (0 studs)*: Bị thổi bay với tốc độ cực đại $\approx$ **`202.1` studs/s**!
    * *Đứng ở mép tầm ảnh hưởng (38 studs)*: Bị đẩy với tốc độ $\approx$ **`112.8` studs/s**.
  * **Cơ chế lây lan**: Trúng sóng đẩy này sẽ tự động kích hoạt sự kiện truyền trạng thái của chuông giống như bạn đã gõ chuông trực tiếp (kéo theo kích hoạt cấm nhảy `Concussion` hoặc khóa kỹ năng `Flesh` nếu các lời nguyền tương ứng đang có hiệu lực).

### 3. Mart Slide (Đẩy do va chạm Mart)
* **Nguồn kích hoạt**: Va chạm với quái vật **Mart** khi đang chịu lời nguyền **MartSlide**.
* **Hiệu ứng vật lý (Knockback)**:
  * Người chơi bị hất văng theo hướng ngẫu nhiên dựa trên vận tốc của Mart (giới hạn cap tối đa `80` studs/s) cộng thêm một xung lực hướng lên `Vector3.new(0, 20, 0)` và một vectơ ngẫu nhiên có độ lớn từ `45` đến `70` studs/s.
  * Toàn bộ lực đẩy được nhân tỷ lệ thuận theo kích thước (`Scale`) của Mart (tối đa nhân `2.0`).
