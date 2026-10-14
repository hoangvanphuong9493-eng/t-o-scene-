# HP Layout Pro 3.4.1-rc1 — Tối ưu hiệu năng

Phát triển trên bản 3.4.0-rc1 mà người dùng đã xác nhận chạy và in ổn định trong SketchUp 2023 Windows. Bản này tập trung vào tốc độ xử lý và độ mượt.

## Thay đổi

- Chuyển chuyển đổi màu và nén PDF không mất dữ liệu sang tác vụ nền trong cửa sổ xuất; dùng lại tác vụ giữa các trang. Tự dùng bộ nén cũ nếu trình duyệt nhúng không hỗ trợ.
- Giải phóng ảnh Scene ngay sau trang cuối sử dụng ảnh đó; giữ ảnh dùng chung cho đến khi ghép đủ các trang.
- Giữ danh sách Scene, trang và thanh công cụ khi nội dung không đổi. Chuyển trang chỉ cập nhật dấu chọn, giúp dự án nhiều trang phản hồi nhanh hơn.
- Đổi mục tiêu tỷ lệ tham khảo trong Quick Layout chỉ cập nhật thông tin so sánh; không tính lại toàn bộ các phương án.
- Bỏ lượt tính khít thừa sau “Khít tất cả”; bỏ quét dấu thay đổi model trùng trong cùng một lần mở/cập nhật cửa sổ.
- Lưu trạng thái hình học ẩn trong một lượt; khôi phục trạng thái với ít cấp gọi hàm hơn trên model lớn.

Khổ giấy, bố cục, tỷ lệ, cỡ DIM, độ phân giải, mức đậm nét và cách xuất CAD được giữ theo bản 3.4.0-rc1. Bộ ghi PDF và công thức dựng Scene giữ nguyên. Các lệnh SketchUp vẫn chạy trên luồng chính.

## Cài đặt

1. Trong SketchUp 2023, mở Window → Extension Manager → Install Extension.
2. Chọn HP_LayoutPro_v3.4.1-rc1.rbz.
3. Đóng và mở lại SketchUp; cửa sổ plugin hiển thị v3.4.1-rc1.
4. Mở model và xuất như trước với cùng mức chất lượng.

Không cần tạo lại Scene, bố cục hoặc khung tên chỉ để sử dụng bản tối ưu này.

## Kiểm tra

18 kiểm tra Ruby và 11 kiểm tra JavaScript đạt. Kiểm tra giao diện bằng Chromium đạt; PDF nhiều trang gồm bảng tổng hợp, chú thích và ảnh Scene dùng chung có dữ liệu điểm ảnh giống bản 3.4.0-rc1. Đã đọc lại PDF bằng PyMuPDF và kiểm tra kích thước A3.

Đo riêng khâu lưu/khôi phục trạng thái với 500.000 đối tượng giả lập: tổng trung vị 407 ms → 161 ms. Đo 100 lần cập nhật/chuyển chọn trong danh sách 300 trang giả lập: 2.328 ms → 23 ms. Đây là phép đo các thành phần trong môi trường kiểm tra, không phải toàn bộ thời gian xuất trên SketchUp.

Thời gian nén hai ảnh PDF mẫu gần tương đương giữa hai bản; độ đáp ứng giao diện khi nén cải thiện rõ. Tốc độ xuất thực tế còn phụ thuộc độ phức tạp model và cấu hình máy. Bản 3.4.1-rc1 chưa được chạy trực tiếp trong SketchUp 2023 Windows tại môi trường này.
