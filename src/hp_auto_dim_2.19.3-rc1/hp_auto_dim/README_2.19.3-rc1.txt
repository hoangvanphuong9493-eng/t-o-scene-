HP Auto Dim 2.19.3-rc1 — SketchUp 2023+
BẢN ỨNG VIÊN KIỂM THỬ, CHƯA NGHIỆM THU TRONG SKETCHUP THẬT

Mục tiêu: DIM lấy từ hình học hiện tại khi đổi kích thước, dựng lại chi tiết,
thêm/xóa/di chuyển đợt, hồi, cánh và tim lỗ; không coi tọa độ suy ra theo
hộp bao là bằng chứng liên kết đúng cạnh thật.

Dùng với model cũ:
1. Chọn nhóm DIM liên tiếp/cắt HP cần theo dõi thêm/bớt đợt, hồi.
2. Extensions > HP Auto Dim v2.19.3-rc1 >
   Theo dõi thêm/bớt đợt, hồi (DIM đã chọn).
   Lệnh có Undo, không đổi tag nguồn và không chuyển Tags hàng loạt.
3. Cập nhật kích thước, rồi Kiểm tra DIM với hình học hiện tại.
   Cập nhật thủ công đầu tiên cũng lưu phạm vi cánh theo tên/metadata nguồn.
   Nhóm thiếu nguồn/mơ hồ/sửa tay phải xử lý riêng; không được hiểu là đã đạt.

DIM mới:
Mặc định bật DIM mới: theo dõi thêm/bớt đợt, hồi. Chỉ tự bật quét cho DIM
có nguồn group/component xác định được; chuỗi điểm tự do/đảo chiều giữ
cách đo từng điểm. Có thể tắt tùy chọn này để đo các điểm chọn riêng lẻ.
DIM gần hai biên nguồn (dung sai max(độ dày,25mm)) theo toàn bộ chiều nguồn;
chuỗi ở giữa giữ phạm vi chọn. Giao cắt giới hạn trong group nguồn.
Ở chế độ base, tính cả chi tiết lùi theo chiều sâu trong dung sai; không
lấy chi tiết nằm lệch sang khoang bên cạnh chỉ vì nó ở gần.
Ngưỡng bỏ đoạn độ dày vẫn là giá trị mm đã cài: nếu Scale làm ván dày hơn
ngưỡng, đoạn đó vẫn hiện đúng theo hình học, không tự đoán nó là độ dày ván.

Bốn loại DIM:
- Đối tượng: kích thước bao của hình học nguồn, loại trừ DIM/annotation.
- Liên tiếp: chế độ theo nguồn tính lại các giao cắt trong phạm vi đo,
  không chỉ nối lại danh sách điểm cũ khi thêm/bớt chi tiết.
- Cắt: tính lại các mặt cắt; trục, phía đặt và phạm vi bám hệ nguồn khi
  Scale/di chuyển/xoay. Điểm nguồn cũ mất ID cần bật lệnh chuyển nêu trên.
- Cánh + tim lỗ: đo các cánh và tâm lỗ thật; không dùng khoảng đợt để thay
  cho khoảng tim bản lề. Xóa hết cánh không biến tủ thành một cánh mới.
  Trạng thái không còn cánh vẫn theo dõi để khi thêm cánh trở lại sẽ dựng DIM.

Độ tin cậy và dữ liệu:
- Nhận diện lại chi tiết Fuji bằng sheet/node/door ID nếu duy nhất trong
  đúng phạm vi. Điểm dự phòng phải khớp đỉnh/cạnh thật, không đoán hàng xóm.
- Nếu nguồn không có định danh ổn định và không nhận diện lại được duy nhất,
  giữ dữ liệu, báo chưa xác nhận được; không đảm bảo tự phục hồi mọi model
  hoặc mọi plugin dựng lại hình học.
- Nhãn DIM dùng số đo native, không ghi số đo thành chữ cố định; định dạng
  và độ chính xác hiển thị theo Units của model.
- Đối chiếu số đoạn, hai đầu, offset và chữ theo hình học hiện tại; sai số
  tọa độ so sánh 0,05mm. Không khớp/thiếu nguồn không được báo đạt.
- DIM tự vẽ được giữ, kể cả vẽ thêm trong nhóm HP. Nhóm đã sửa tay không bị
  tự dựng đè. Lệnh xóa DIM HP giữ phần không có dấu sở hữu HP.
- Giữ thư mục Tags HP DIM và tag riêng theo loại/scene. Scene đổi sẽ yêu cầu
  cập nhật trì hoãn sau khi camera dừng; không tính hình học mỗi khung hình.
- Mở file không tự quét DIM/chuyển Tags; giữ debounce, chia lượt, ngân sách
  cập nhật nền và bảo toàn DIM cũ khi tính/vẽ thất bại.

Đã kiểm tra ngoài SketchUp:
62 phép đối chiếu tổng hợp chạy các hàm tính/render/refresh thật qua API
thay thế, bao phủ 4 loại DIM, thay số lượng chi tiết, định danh mới, mất nguồn,
bộ nhớ đệm, Scale/di chuyển/xoay, cánh/lỗ về 0 rồi thêm lại, DIM tay,
lỗi vẽ/khôi phục/thử lại, observer scene, xem trước lưu cache và raytest.
Có thêm kiểm tra số đo trên hình học trích từ model mẫu của người dùng;
model mẫu và hình học riêng không đưa vào gói hoặc kho mã công khai.
Kiểm tra cú pháp Ruby, hồi quy Tags, khoảng cách hàng, ZIP và API stubs.

CHƯA XÁC NHẬN:
Chưa chạy SketchUp thật nên chưa nghiệm thu cài RBZ, thao tác chuột/bắt
điểm, observer/timer native, Undo/Redo, lưu/mở lại, scene transition,
plugin Fuji thật và hiệu năng trên model lớn. Không cam kết chính xác tuyệt
đối hay không còn lỗi từ kiểm tra giả lập. Cần kiểm thử native trước khi
coi đây là bản ổn định. Bài thử native ở tests/hp_autodim_2193 trong kho mã
chỉ chạy với model mới hoàn toàn trống và lưu kết quả JSON để đối chiếu.
