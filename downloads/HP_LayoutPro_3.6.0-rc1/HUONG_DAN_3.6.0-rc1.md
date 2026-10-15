# HP Layout Pro 3.6.0-rc1 — Chọn nhiều cấu kiện, 1 trang/1 view và xuất liên tục

## Cài đặt

SketchUp 2023 Windows: Window → Extension Manager → Install Extension → chọn **HP_LayoutPro_v3.6.0-rc1.rbz**. Đóng/mở lại SketchUp và kiểm tra góc plugin hiện **v3.6.0-rc1**.

## Chọn nhiều cấu kiện và tạo một trang cho từng view

1. Bấm **▦ Chọn Scene tạo trang** ở cột trái.
2. Tích các cấu kiện cần xuất, hoặc tích Scene lẻ từ nhiều cấu kiện.
3. Chọn **1 trang / 1 view**. Ví dụ 2 cấu kiện, mỗi cấu kiện có 8 Scene được chọn → 16 trang, mỗi trang đúng 1 Scene.
4. Nhập tiền tố tên trang, bấm **Xem bố cục → Tạo N trang**.

Mỗi Scene khít vùng vẽ theo chiều giới hạn, có khung bao, ghi tỷ lệ riêng và tên cấu kiện. Tạo thêm trang vào cuối danh sách; giữ các trang/chú thích đang có. Chế độ này không áp dụng giới hạn 24 Scene của chế độ ghép chung. Phần xem trước hiển thị 12 trang mỗi lượt; bấm Xem thêm để xem tiếp. Khi tạo vẫn đủ toàn bộ trang đã chọn.

Vẫn có **Ghép các view trên 1 trang** trong cùng hộp thoại, tối đa 24 Scene/tờ và có xem trước. Cấu kiện ở đây là các nhóm Scene mà plugin liệt kê, không phải tự tạo Scene từ vật thể chưa có Scene.

## Mượt hơn khi sắp và khít trang

- Tính phương án bố cục trên luồng nền khi trình duyệt hỗ trợ, giữ giao diện có thể phản hồi. Hủy kết quả cũ khi đổi lựa chọn, đóng hộp hoặc Cập nhật.
- Dùng ảnh thu nhỏ riêng cho thẻ phương án. Ảnh chính xác của trang và ảnh xuất giữ chất lượng đã chọn.
- Quick Layout hiển thị 6 tờ đầu mỗi phương án, bấm Xem thêm để xem tiếp; tạo trang vẫn lấy đủ phương án.
- Khít tất cả xử lý từng đợt 8 trang, dùng lại thông tin đã đo, có tiến độ. Cập nhật hủy các đợt khít/tính cũ; ảnh chính xác chỉ dựng cho trang đang xem.
- Giữ cache ảnh, cập nhật riêng ảnh trong ô và ưu tiên trang đang mở như bản trước. Lần đo/dựng đầu tiên vẫn cần SketchUp/GPU xử lý.

Bố cục khung thẳng hàng của 3.5.1 được giữ. Muốn sắp lại trang cũ: Quick Layout → Khung cân đối → Tạo trang. Tạo trang trong Quick Layout thay các trang/chú thích của nhóm được chọn; lưu bản SKP riêng nếu cần giữ phương án cũ.

## Xuất nhiều Scene liên tục

- Xuất theo từng trang, giải phóng ảnh đã dùng trước khi dựng trang kế tiếp; không nạp sẵn toàn bộ ảnh độ phân giải cao của 50 Scene.
- Dùng lại ảnh đo Scene còn hợp lệ, theo model/thiết lập cỡ DIM; không đo lại mọi Scene từ đầu khi thông tin đã có.
- Nén PDF không mất dữ liệu bằng luồng nền, tận dụng bộ mã hóa PNG RGB của trình duyệt khi có hỗ trợ; có đường xử lý dự phòng. File có thể lớn hơn kiểu nén cũ do ưu tiên tốc độ.
- **Bỏ hộp hỏi có tiếp tục về tỷ lệ và DPI/chất lượng ảnh.** Bấm Xuất sẽ chạy liên tục theo tỷ lệ, cỡ DIM và chất lượng đã chọn. Không tự đổi tỷ lệ hoặc hạ DPI để vượt cảnh báo.
- Vẫn báo lỗi thật: Scene thiếu, ảnh không dựng được/trắng, hình hoặc DIM bị cắt, dữ liệu trang không hoàn tất, không ghi được file.

In PDF ở **100% / Actual size**. PDF vẫn là ảnh; CAD vẫn theo luồng CAD 3D của bản trước. Chọn chất lượng trong hộp Xuất như trước: 200/300/400/500 dpi; DPI cao và model phức tạp cần nhiều thời gian hơn.

## Kiểm tra

Đã kiểm tra bằng Linux/Chromium và API mô phỏng: chọn nhiều nhóm và tạo đủ 50 trang một view/trang; giao diện phản hồi khi tính bố cục; khít theo đợt và hủy khi Cập nhật; luồng xuất 50 Scene/50 trang A3 ở mức 400 dpi, không hỏi tỷ lệ/DPI; khung và toàn bộ điểm ảnh khớp bản đối chiếu; PDF đọc lại đúng khổ, đủ trang.

Bản này chưa được chạy trực tiếp trong SketchUp 2023 Windows tại môi trường kiểm tra. Thời gian đo trong mô phỏng không phải cam kết tốc độ trên model/GPU thực. PDF minh họa dùng dữ liệu tự tạo, không dùng model/ảnh khách hàng.
