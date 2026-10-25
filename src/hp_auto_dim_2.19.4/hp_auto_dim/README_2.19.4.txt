HP Auto Dim 2.19.4 — SketchUp 2023+
Bản vá nhỏ trên 2.19.3-rc1 đã được người dùng xác nhận chức năng cập nhật ổn.

Chỉ sửa hai phần:
1. DIM số tròn ở nhóm HP ngoài cùng bỏ .0/.00: 100.0 -> 100, 600.0 -> 600.
   Số lẻ và cách làm tròn theo Units giữ nguyên. Khi kích thước thay đổi từ số
   tròn sang số lẻ, chữ cũ được bỏ để native hiển thị giá trị mới.
   DIM nằm lồng trong group hoặc definition dùng chung giữ chữ native để
   không gây sai số khi group cha Scale; không sửa cấu trúc nhóm để ép định dạng.
2. Hàng DIM mới nhận diện hàng trước theo cùng hướng nhìn, kể cả mặt cánh và
   khung/đợt lệch chiều sâu. Khoảng cách dùng đúng “Các dim sau cách dim trước”.
   Kéo tự do vẫn giữ khoảng cách tối thiểu đó; kéo xa hơn được giữ nguyên.
   Gõ chiều dài riêng vào VCB giữ hành vi cũ. Không đổi vị trí DIM đã tạo.
   Vị trí xem trước và độ dịch lưu lại dùng cùng kết quả khi dựng/cập nhật DIM.

Để áp dụng định dạng cho DIM đã tạo: Cập nhật kích thước ở scene đang mở.
DIM tạo sau nhận định dạng mới ngay.

Giữ nguyên từng byte so với 2.19.3-rc1: anchors, live_geometry, interaction,
rendering, scheduler, tracking, tagging, verification và toàn bộ icons.
main.rb chỉ thay hàm set_clean_text; ngoài hàm đó nội dung không đổi.
Không đổi tính hình học, theo dõi đợt/hồi/cánh/tim lỗ, Tags/scene hoặc chân DIM.

Kiểm tra ngoài SketchUp: 26 đối chiếu riêng về định dạng và đặt hàng DIM;
62 kiểm tra hồi quy hình học/render/cập nhật; hồi quy Tags và khoảng cách hàng;
đối chiếu hình học trích từ model mẫu. Chạy trên Ruby 2.7.8 và 3.2.6.
Đã kiểm tra cú pháp và ZIP; thay đổi này chưa được thao tác trực tiếp trong
SketchUp thật. Không đưa model riêng của người dùng vào gói hoặc kho công khai.
