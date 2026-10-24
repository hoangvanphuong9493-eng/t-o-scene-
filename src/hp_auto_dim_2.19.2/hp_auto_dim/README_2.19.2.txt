HP Auto Dim 2.19.2 — SketchUp 2023+

Sửa cập nhật theo kích thước đối tượng:
- Điểm bắt trên đỉnh/cạnh khi chiếu sang trục đo vẫn lưu liên kết nguồn
  cùng độ dịch cục bộ; trước đây điểm bị chiếu có thể trở thành tọa độ tĩnh.
- Kiểm tra đường dẫn instance và chủ sở hữu của đỉnh/cạnh. Khi Make Unique
  hoặc thay definition, không đọc lại đỉnh của definition cũ còn tồn tại.
- Điểm neo mới trong group/component lưu thêm tỷ lệ trong bounds cục bộ
  để dự phòng khi topology thay đổi. Ưu tiên đỉnh/cạnh thật còn tồn tại;
  tỷ lệ bounds là phương án dự phòng, không đảm bảo tái nhận diện mọi chi tiết.
- DIM cũ còn dữ liệu trk dùng dự phòng theo đối tượng như trước.
- Mất liên kết nguồn thì giữ DIM và báo chưa cập nhật; không âm thầm
  dùng tọa độ cũ của đỉnh/cạnh rồi báo đã cập nhật.
- Lệnh Cập nhật kích thước xóa cả cache PID và vùng ảnh hưởng trước khi tính.

Giữ tính năng 2.19.0/2.19.1:
Thư mục Tags HP DIM, tag <scene> — DIM <loại>. Chuyển DIM cũ bằng
Extensions > HP Auto Dim v2.19.2 > Chuyển DIM cũ sang Tags theo scene (HP DIM).
Không chuyển hàng loạt khi mở file; không đổi tag nguồn hoặc DIM tự vẽ.
Giữ khoảng cách hàng mới theo cài đặt cho DIM liên tiếp/cắt ở chế độ
chân DIM theo cài đặt; gõ chiều dài riêng hoặc '-' vẫn theo người dùng.
Giữ độ dịch hàng khi cập nhật kích thước.

DIM cũ đã mất nguồn hoàn toàn (chỉ còn tọa độ p/w, không có đỉnh/cạnh,
path hoặc trk) không thể tự phục hồi chính xác. Cần tạo lại bộ DIM đó bằng
bản mới; không suy đoán hoặc tự gán sang đối tượng gần bên.
Cập nhật DIM theo scene hiện tại như các bản trước; DIM đối tượng có thể
cập nhật giữa các scene. Bật “Tự động cập nhật khi đối tượng thay đổi”
hoặc dùng “Cập nhật kích thước”. DIM đã bung nhóm/ngừng tự cập nhật,
xóa bớt hoặc biến đổi riêng nhóm DIM không tự được dựng lại.

Kiểm tra ngoài SketchUp:
- Tái hiện lỗi điểm chiếu mất nguồn trên mã 2.19.1 (test thất bại như dự kiến).
- Mã 2.19.2 đạt test điểm chiếu trên đỉnh/cạnh, chỉnh đỉnh, Scale,
  sửa bounds bên trong, Make Unique, nguồn cũ và mất nguồn.
- Chạy hàm compute_line và refresh_all thật với API giả lập: thay số đo,
  cập nhật tự động/thủ công, cache không đổi, giữ DIM khi mất nguồn.
- Chạy compute_obj/draw_obj_dims thật, kiểm tra endpoints theo bounds/Scale.
- Kiểm tra hồi quy Tags/scene, khoảng cách hàng, cú pháp Ruby và ZIP.
- Đối chiếu kiểu dữ liệu API với kho SketchUp/ruby-api-stubs chính thức.

CHƯA KIỂM THỬ TRONG SKETCHUP THẬT: cài RBZ 2023+, các trường hợp
Push/Pull/Scale/Make Unique thực tế, Undo/Redo, native observers/timer,
nhãn DIM hiển thị, lưu/mở lại, cảnh chuyển động và model lớn.
Test giả lập không chứng minh mọi thao tác trong model thực tế đều đúng.
