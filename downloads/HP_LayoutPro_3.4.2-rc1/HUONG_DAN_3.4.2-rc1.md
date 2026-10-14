# HP Layout Pro 3.4.2-rc1 — Sửa lag tải ảnh và chuyển trang

Bản này sửa trực tiếp luồng xem trước Scene trong trang bản vẽ, dựa trên phản hồi bản 3.4.1-rc1 vẫn khựng khi tải ảnh/chọn trang.

## Thay đổi

- Ưu tiên trang đang chọn, bỏ yêu cầu dựng ảnh/đo Scene của trang đã bỏ qua; không bỏ việc đo chung còn cần cho Quick Layout.
- Khi bấm lướt nhanh, chờ dừng khoảng 220 ms trước khi yêu cầu ảnh rõ hơn, tránh dựng liên tục các trang chỉ vừa đi qua.
- Dùng ngay ảnh Scene đã đo nếu có, giữ tỷ lệ/hình dạng và vị trí; thay bằng ảnh xem trước chính xác khi SketchUp dựng xong.
- Ảnh trả về cập nhật trực tiếp trong ô. Giữ các ô, trường đang gõ và chú thích; không dựng lại toàn trang cho từng ảnh.
- Giữ ảnh đã giải mã trong bộ nhớ để quay lại trang nhanh. Cache tối đa 90 ảnh và khoảng 96 MiB dữ liệu ảnh đã giải mã ước tính; ưu tiên giữ ảnh của trang đang mở. Giải phóng khi Cập nhật/đóng cửa sổ.
- Mỗi lượt hàng đợi xử lý một ô hoặc một Scene đo, tránh gom hàng loạt biến thể của cùng Scene vào một lượt dài.
- Bỏ callback/yêu cầu cũ sau khi đổi trang hoặc Cập nhật. Lỗi ảnh được báo và bỏ trạng thái chờ thay vì quay mãi.

Chất lượng ảnh xem trước chính xác vẫn như bản trước. Giữ nguyên bộ dựng ảnh xuất, tỷ lệ/DIM, độ phân giải xuất PDF, bố cục, khung tên, dữ liệu dự án và xuất CAD.

## Cài đặt

1. Trong SketchUp 2023: Window → Extension Manager → Install Extension.
2. Chọn HP_LayoutPro_v3.4.2-rc1.rbz.
3. Đóng và mở lại SketchUp để cả mã Ruby và giao diện được cập nhật.
4. Mở plugin; kiểm tra góc cửa sổ hiển thị v3.4.2-rc1. Dùng các trang đã có như trước.

Scene chưa từng được đo/dựng vẫn cần SketchUp tạo ảnh lần đầu. Nếu đã đo qua Quick Layout thì ảnh đó được dùng ngay trong lúc chờ ảnh rõ hơn. Không cần tạo lại Scene hoặc chia lại trang để dùng bản sửa.

## Kiểm tra

Đã tái hiện trên bản cũ và kiểm tra bằng Chromium: 6 ảnh trả về khiến trang dựng lại 6 lần; bản sửa 0 lần. Ảnh có sẵn hiện trước khi ảnh rõ hơn hoàn tất; quay lại trang đã tải không gửi yêu cầu dựng mới. Đạt kiểm tra bấm lướt nhanh, gõ/drag trong lúc ảnh về, kết quả trả sai thứ tự, Cập nhật khi đang tải và cache ảnh đã giải mã.

18 kiểm tra Ruby lõi + 7 kiểm tra hàng đợi, 13 kiểm tra JavaScript, hồi quy bố cục và luồng xuất nhiều trang đạt. PDF đọc lại đúng A3, các điểm ảnh khớp bản đối chiếu. Các kiểm tra thực hiện trong môi trường Linux/Chromium với API SketchUp giả lập; bản này chưa được chạy trực tiếp trong SketchUp 2023 Windows ở đây.
