# hp gcode 0.32.29 beta — giảm dung lượng tem One Click

Tên hiển thị mới là **hp gcode**, áp dụng trong Extension Manager, menu Extensions, thanh công cụ, tiêu đề cửa sổ, cài đặt và tài liệu xuất. Cài `hp_gcode_0.32.29_beta.rbz` để cập nhật bản HP Tool đã cài; thoát hoàn toàn SketchUp rồi mở lại. Bộ cài giữ cùng mã đăng ký và vị trí lưu cấu hình để nhận lại post, dao, layer và mẫu tem cũ.

Bản này giữ các sửa chống treo của 0.32.28: khởi động chỉ nạp menu/thanh công cụ, hủy worker khi đóng/chuyển model, dấu lỗi tạm mặc định tắt và không ghi thêm hình học vào file.

## Cách giảm dung lượng tem

1. Mở file gốc và dùng **Lưu thành / Save As** để tạo bản riêng.
2. Chọn **Extensions → hp gcode: Gọn tem One Click (giảm dung lượng)**. Lệnh dùng được mà không cần mở cửa sổ xếp tấm.
3. Kiểm tra ID/tên và hướng vân; Lưu thành bản mới sau khi gọn.
4. Đóng rồi mở lại bản mới để giải phóng dữ liệu Undo trong RAM. So sánh dung lượng file trước/sau.

## Giảm dung lượng thật: Gọn tem One Click

Chỉ ẩn tag giúp giảm tải hiển thị; hình học chữ vẫn nằm trong file. Để giảm dung lượng thật, chọn **Extensions → hp gcode: Gọn tem One Click (giảm dung lượng)**, hoặc nút **Gọn tem One Click** trên cửa sổ hp gcode.

Lệnh thay các nhóm chữ tem được vẽ bằng nhiều cạnh bằng một Text nhẹ của SketchUp. Chỉ xử lý nhóm con nằm trong `oneclick_label` có hình học thuần cạnh và không có vạch vân. Nhóm tem, các cạnh chỉ hướng vân, số/tên của tấm và dữ liệu gia công vẫn được giữ. Các định nghĩa chữ cũ chỉ được bỏ khi không còn instance nào sử dụng; không chạy Purge Unused toàn model.

- Trên mẫu kiểm tra, 252 nhóm chữ có thể bỏ 430.067 cạnh và 252 định nghĩa chữ; giữ 252 vạch vân, tạo 252 Text nhẹ.
- Kiểu chữ trên model sẽ đơn giản hơn, hiển thị ID/tên chi tiết. Tem in PDF tiếp tục dùng dữ liệu chi tiết và thiết kế mẫu tem; không lấy các nét chữ 3D đã xóa.
- Có thể Hoàn tác trong phiên hiện tại. Muốn giữ nguyên kiểu chữ gốc lâu dài, giữ file gốc và **Lưu thành file mới**.
- Sau khi Lưu thành, đóng rồi mở lại bản mới để giải phóng dữ liệu Undo còn giữ hình học cũ trong RAM.
- Không nhận dạng rõ hoặc dùng chung định nghĩa khiến ID không xác định: nhóm đó được giữ nguyên và báo số mục bỏ qua. Giới hạn 500 tem/mỗi lần và một triệu cạnh để tránh xử lý quá lâu.

Kết quả kiểm thử qua facade API trên dữ liệu hình học của mẫu cho 271 record nguồn và toàn bộ liên kết trước/sau trùng nhau, không lỗi đọc dữ liệu; thao tác lặp không xóa thêm. Chưa có SketchUp Desktop trong môi trường này để đo dung lượng `.skp` sau Save As, nên không cam kết một tỷ lệ giảm MB cụ thể.

## Phần bổ sung 0.32.29

Có những model chứa nhiều tem One Click đã chuyển chữ thành đường cạnh: mẫu kiểm tra có 252 tem, khoảng 431.225 cạnh trong khối tem, trên tổng 474.277 cạnh đang được dùng. Khối tem chiếm gần 91% số cạnh của model. Đây là nguồn tải hiển thị lớn; kiểm tra cấu trúc file chưa chứng minh được mọi nguyên nhân tự đóng SketchUp.

- **Extensions → hp gcode: Xem nhẹ - ẩn tem 3D**: ẩn tag `Fuji_label`/`OneClick_label`, không quét hàng trăm nghìn cạnh, không xóa hình học.
- **Extensions → hp gcode: Hiện lại tem 3D**: hiện lại tag tem khi cần. Cũng có hai nút tương ứng trên đầu cửa sổ hp gcode.
- Lệnh thực hiện trong một thao tác có thể Hoàn tác. Thông tin tem, mã chi tiết, hướng vân trong nhóm tem, khoan/rãnh/mộng và bản thân các tấm vẫn được giữ.
- Nếu đổi scene làm tag tem hiện lại, bấm Xem nhẹ lần nữa. Đây là điều khiển trạng thái hiển thị của model hiện tại, không sửa các scene đã lưu.
- Dùng **Lưu thành** để giữ riêng bản xem nhẹ và bản gốc.

Cài RBZ bằng Extension Manager trong một model trống, thoát hoàn toàn SketchUp rồi mở lại. Không cần mở cửa sổ hp gcode để dùng hai lệnh xem nhẹ trong Extensions.

Bộ kiểm tra đã xác nhận lệnh chỉ đổi trạng thái tag tem, không chạm các tag chi tiết/layer gia công; Hoàn tác và hiện lại hoạt động trong facade API. Dữ liệu gồm 267 tấm có định danh One Click; bộ đọc nhận tổng cộng 271 record, đã đối chiếu toàn bộ liên kết trước/sau. Các thử nghiệm tự động không thay thế việc mở chính file đó trong SketchUp Desktop, môi trường hiện tại không có SketchUp Desktop.

