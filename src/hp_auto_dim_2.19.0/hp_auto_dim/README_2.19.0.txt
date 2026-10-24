HP Auto Dim 2.19.0 — SketchUp 2023+

Nguồn: HP_AutoDim_v2.18.0.rbz, commit
3ef544b, nhánh downloads/hp-auto-dim-2.18.0,
hoangvanphuong9493-eng/t-o-scene-.

DIM mới nằm trong thư mục Tags HP DIM. Mỗi scene có các tag:
<tên scene> — DIM Đối tượng
<tên scene> — DIM Liên tiếp
<tên scene> — DIM Cắt
<tên scene> — DIM Cánh + tim lỗ
Tag được tạo khi dùng loại DIM tương ứng. Liên tiếp cũ (chain) và
liên tiếp nối điểm (cont) dùng cùng loại tag.
DIM tạo khi model chưa có scene dùng “Không scene”, hiển thị mọi scene.
Nếu tên tag trùng tag không thuộc plugin, thêm hậu tố để giữ tag có sẵn.
Scene bị xóa giữ ID và DIM, không tự chuyển sang scene khác.

Chuyển DIM cũ: Extensions > HP Auto Dim v2.19.0 >
Chuyển DIM cũ sang Tags theo scene (HP DIM).
Lệnh có Undo. Chỉ chuyển nhóm/DIM có ID bộ DIM HP đã lưu;
không xóa tag cũ, không đổi tag nguồn hay DIM tự vẽ.
Nếu dữ liệu quá cũ thiếu ID scene và không suy ra được từ tag cũ,
hủy toàn bộ thao tác thay vì tự đoán scene. Sao lưu model trước khi thử.
Mở file chỉ gắn observer trì hoãn, không quét hoặc chuyển hàng loạt.
Cập nhật DIM cũ không tự chuyển cấu trúc Tags.

Scene lưu trạng thái Visible Tags cho tag DIM tương ứng. Các scene được
bật lưu Visible Tags để chuyển scene áp dụng đúng trạng thái DIM.
Không gọi Page#update để tránh ghi lại camera/trạng thái nguồn.
Scene mới được thiết lập trạng thái các tag DIM do 2.19.0 quản lý.

Giữ nguyên thuật toán hình học, bắt điểm, chân DIM, rendering và tracking
2.18.0; scheduler chỉ thêm observer cho scene mới.

Kiểm tra: cú pháp Ruby mọi file; mô hình API giả lập cho tag/scene,
chuyển đổi, giữ DIM tay/tag nguồn và chạy lại không tạo tag trùng;
kiểm tra ZIP và đối chiếu file kế thừa.
CHƯA KIỂM THỬ TRONG SKETCHUP THẬT: cài RBZ trên 2023+, chuyển/hoạt cảnh
scene, lưu/mở lại, Undo/Redo, model lớn, bắt điểm, cập nhật kích thước,
chân DIM và lỗi treo thực tế. Kiểm tra giả lập không thay thế kiểm tra này.
