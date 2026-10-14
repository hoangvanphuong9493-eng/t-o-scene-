# Báo cáo kiểm tra tải ảnh/xem trang — HP Layout Pro 3.4.2-rc1

Ngày: 14/10/2026. Đối chiếu: 3.4.1-rc1.

## Nguyên nhân tái hiện được

1. Hàng đợi giữ ảnh của các trang/biến thể đã bỏ qua. Bản cũ gom tất cả yêu cầu cùng Scene vào một lượt, kể cả các biến thể không còn cần.
2. Khi mỗi ảnh về, giao diện dựng lại toàn trang, gồm các ô, danh sách chọn Scene, trường nhập và lớp chú thích.
3. Callback đo Scene về trễ có thể đặt lại timer và gửi yêu cầu ảnh cho trang đã rời khỏi.
4. Blob ảnh được lưu nhưng không giữ một đối tượng ảnh đã giải mã sẵn; trạng thái chờ không được xóa khi dựng ảnh gặp lỗi.

## Kiểm tra Chromium

Trang giả lập 6 ô, trả 6 ảnh lần lượt. Ảnh Scene tổng hợp; không dùng hình học native của model người dùng.

| Chỉ tiêu | 3.4.1-rc1 | 3.4.2-rc1 |
|---|---:|---:|
| Số lần dựng lại toàn trang khi nhận 6 ảnh | 6 | 0 |
| Ảnh đo sẵn hiện trước ảnh rõ hơn | Không | Có |
| Giữ các node ô và trường đang gõ | Không | Có |
| Giữ đối tượng ảnh đã giải mã | Không | Có |

Quay lại trang đã có đủ ảnh: khoảng 43.7 ms trong ca kiểm tra (gồm chờ các khung hình), không gửi yêu cầu dựng ảnh mới; đủ ảnh chính xác đã giải mã. Số đo này thuộc trình duyệt thử nghiệm, không phải cam kết độ trễ trên máy SketchUp của người dùng.

Các ca đạt:

- Bấm qua hai trang cách nhau 120 ms rồi dừng ở trang thứ ba: chỉ trang cuối gửi yêu cầu ảnh.
- Chuyển A → B rồi trả kết quả đo B trước A: A không phát sinh yêu cầu dựng ảnh sau khi đã rời trang.
- Ảnh về trong khi đang gõ: không thay trường nhập hoặc mất nội dung/focus.
- Ảnh về khi đang drag/sửa chú thích: hoãn thay ảnh đến khi kết thúc thao tác.
- Cập nhật trong lúc chờ/đổi blob: kết quả thuộc lần tải cũ bị bỏ, không ghi đè cache mới.
- Quick Layout vẫn có đủ các phương án và ảnh thu nhỏ; kiểm tra khít giấy và đa dạng bố cục đạt.

## Kiểm tra hàng đợi Ruby

API capture giả lập để đếm số yêu cầu, không giả lập thời gian GPU/SketchUp thật.

Sáu lần đổi trang/biến thể cùng Scene trước khi timer chạy: bản cũ xử lý 6 yêu cầu trong một lượt, bản mới chỉ giữ 1 yêu cầu cuối. Với sáu ô đang hiển thị thực sự, bản mới xử lý một ô mỗi lượt rồi trả quyền cho vòng sự kiện.

Bảy ca đạt: bỏ capture cũ; giới hạn một ô/lượt; ưu tiên probe đang xem và giữ probe Quick Layout; nâng probe dùng chung từ view lên toàn bộ; chặn dữ liệu trước Cập nhật; báo lỗi và tiếp tục ô kế; chặn thông điệp chọn trang đến sai thứ tự.

## Kiểm tra xuất và tính đúng

- 18 kiểm tra Ruby lõi và 13 kiểm tra JavaScript đạt.
- Kiểm tra khít giấy/8 phương án bố cục, chuyển/tạo trang và hồi quy nền giấy đạt.
- Xuất 5 trang trong Chromium gồm tổng hợp nối trang, chú thích và ảnh dùng chung: hash RGB từng trang giống bản đối chiếu.
- Phát lại dữ liệu qua Renderer/PdfWriter Ruby, đọc lại bằng PyMuPDF: đúng A3, các hash RGB khớp.
- Các file scenes.rb, exporter.rb, pdf_writer.rb và store.rb giữ nguyên từng byte so với 3.4.1-rc1. Không hạ chất lượng ảnh chụp xem trước chính xác hoặc ảnh xuất để lấy tốc độ.
- Ảnh xem tạm lấy từ ảnh đo có sẵn; phép biến đổi theo tỷ lệ giấy, crop/zoom phối cảnh được kiểm tra riêng. Ảnh này chỉ phục vụ xem trước, không thay thế ảnh xuất.

## Giới hạn

Linux, Chromium 153, Ruby 3.3 với API SketchUp giả lập. Không chạy SketchUp 2023 Windows tại môi trường này. Một lệnh write_image đang chạy cần hoàn tất; chỉ hủy các việc chưa bắt đầu. Scene chưa có dữ liệu vẫn cần đo/dựng lần đầu. Ảnh đang hiển thị được giữ khi giới hạn cache ước tính đạt ngưỡng; tài nguyên thật do trình duyệt quản lý nên dung lượng RAM thực tế có thể khác.
