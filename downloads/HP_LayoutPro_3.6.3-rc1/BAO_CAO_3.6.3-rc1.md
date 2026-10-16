# Kiểm tra HP Layout Pro 3.6.3-rc1

Ngày 16/10/2026. Mục tiêu: sửa thông báo chặn tổng ảnh khi xuất trang có nhiều view, giữ tỷ lệ/bố cục và chất lượng đã chọn. Môi trường kiểm tra: Linux, Chromium thật, API SketchUp mô phỏng và PDF writer thật; không có SketchUp 2023 Windows/GPU native.

## Nguyên nhân được tái hiện

3.6.2 giữ các ảnh gốc của trang đồng thời trong cửa sổ PDF và chặn khi tổng vượt 48 MP. Ảnh native theo aspect viewport có thể dư nhiều vùng ngoài ô, nhất là view cao/hẹp. Trang 4 view thử (2 view rộng bên trái và 2 view cao bên phải) có ảnh 3749×2343, 3749×2343, 6093×3808, 6093×3808: tổng 63.972.102 pixel, từng ảnh dưới 32 MP. Bản 3.6.2 trả đúng thông báo chặn bộ nhớ giống ảnh người dùng.

Đây là tái hiện đường chặn bằng dữ liệu tổng hợp, chưa phải phân tích model SKP thực của người dùng. Ảnh thông báo cho biết lỗi này khác BugSplat native đã báo trước.

## Sửa đổi

- Đăng ký đường dẫn/kích thước file native mà không giải mã toàn bộ ảnh trên tờ. Dựng từng Scene qua timer và lưu file như trước; không dựng lại Scene cho từng mảnh PDF.
- Khi ghép từng mảnh, chỉ nạp view giao với vùng vẽ. Cache thu hồi ảnh cũ theo nhu cầu: ảnh thường trú tối đa 32 MP, ảnh đang giữ/nạp/cắt tối đa 48 MP theo số pixel được quản lý. Tổng file nguồn trên một trang không bị coi là tổng ảnh cùng đang mở.
- Cắt ảnh ở tọa độ pixel nguyên, không nội suy lại khi cắt; giữ mật độ điểm ảnh, công thức camera và bố cục. Phần đệm chừa lọc ảnh và nét đậm. Kiểm tra bbox hình/DIM trên ảnh gốc trước cắt, giữ kiểm tra thiếu ảnh/ảnh trắng/mất nội dung.
- Thứ tự khung/tiêu đề → ảnh → chú thích/khung tên giữ nguyên. Đồng bộ khóa ảnh với annotation_scale khác 1 và gộp các yêu cầu trùng key.
- Giữ giới hạn ảnh native riêng lẻ 32 MP trước write_image, giới hạn kích thước ảnh/khổ PDF có sẵn, truyền mảnh 64 KiB có xác nhận và bảo vệ file đích. Không tăng giới hạn để giữ mọi ảnh gốc, không giảm DPI để vượt lỗi tổng ảnh, không hỏi tiếp tục tỷ lệ/DPI.
- Nhật ký PDF ghi stream_images và thống kê giải mã/cắt/cache. Mã scenes.rb dựng camera/chụp ảnh giống từng byte với 3.6.2; thay đổi ở quản lý ảnh và ghép PDF.

48 MP trên là ngân sách các bộ đệm ảnh do cache quản lý, không phải tổng RAM/GPU của SketchUp. Nó không bao gồm toàn bộ tài nguyên model, bộ giải mã nội bộ trình duyệt, tile canvas và driver. Không cam kết hết mọi crash/lag.

## Kết quả kiểm tra

- Trang 4 view bị chặn trong 3.6.2 xuất được bằng luồng mới. Lượt thử gồm 3 trang A3 ở 16 px/mm (406,4 dpi, khoảng 400 dpi), có trang phối cảnh crop/offset, DIM, nét đậm, khung và chú thích; 60 mảnh PNG RGB không mất dữ liệu, giấy 6720×4752 pixel.
- Đỉnh cache ảnh 27.445.766 pixel; đỉnh ảnh đang giữ/nạp/cắt 47.014.929 pixel, dưới ngân sách 48 MP. 11 yêu cầu native/11 lần giải mã cho 11 view qua 3 trang, 7 lần cắt phần dư; không gọi native theo từng tile. Số liệu là trong thử nghiệm, không phải tổng bộ nhớ máy thực hoặc phép đo tốc độ SketchUp.
- Thông điệp thực Chromium phát lại qua Session Ruby/PdfWriter; PDF được PyMuPDF mở và giải mã đủ 3 trang/60 ảnh. So với bộ vẽ cả trang nguyên bản 3.6.2 dùng cùng file PNG: bounds màu/hình khớp trong 1 pixel, kiểm tra tất cả đường ghép ngang/dọc không thấy khoảng hở. Sai khác RGB trung bình 0,03691 / 0,01398 / 0,03691 trên thang 255/kênh, tập trung tại raster/rìa/nét; không tuyên bố pixel trùng từng byte.
- 50 Scene khác nhau: 50 trang A3 ở 4 px/mm (bài thử vòng đời/thứ tự, không phải bài chất lượng 400 dpi), 100 mảnh ảnh, 50 yêu cầu ảnh và 50 lần giải mã; đủ 50 xác nhận trang theo thứ tự, không có câu hỏi tỷ lệ/DPI, không giữ ảnh hay descriptor sau hoàn tất. Session/PDF writer thật và bộ đọc độc lập xác nhận đủ 50 trang/100 ảnh, 50 trang raster có nội dung khác nhau.
- 7 trường hợp cache đạt: thu hồi ảnh cũ/nạp lại, dọn ảnh, chặn riêng ảnh >32 MP, file thiếu, kích thước sai, Scene trắng và hết thời gian đọc ảnh.
- PDF tổng hợp tiếp trang + phối cảnh crop/zoom + chú thích qua stream_images: 3 trang hoàn tất và dọn ảnh đạt.
- Bộ vẽ đầy đủ so với bản nền cũ: danh mục, chú thích và Scene lặp có RGB giống từng byte; sửa phép kiểm tra đời sống ảnh để kiểm tra sau giao trang/hoàn tất, đúng thứ tự xác nhận đã có từ 3.6.0.
- 18 kiểm tra Ruby lõi và 8 nhóm ổn định native/Session đạt: chống gọi chồng, một capture mỗi timer, hủy, giữ trạng thái model, lỗi dữ liệu trang, ảnh lớn chặn trước write_image, file đích và khóa file tạm.
- Exporter.run thật trong môi trường mô phỏng bật stream_images/tiled_pdf/defer_native và giữ trang/tỷ lệ/chất lượng; scenes.rb đối chiếu byte đúng với 3.6.2.
- 8 nhóm Quick Layout đạt: MB chưa có trang → đo → tạo trang; timeout/thử lại/hủy/đổi phạm vi và giữ yêu cầu khác. Kiểm tra khít giữ DOM, không gọi dựng lại khi không đổi, cache trang, chuyển nhanh, sửa chữ, bỏ kết quả cũ sau Cập nhật và chỉ lưu khi sửa đạt.
- Đóng gói kiểm tra toàn bộ cú pháp Ruby, JavaScript/script nội tuyến; ZIP 29 file đối chiếu từng byte mã nguồn. SHA256 của RBZ và tài liệu được ghi trong SHA256SUMS.txt.

## Phạm vi và sử dụng

Cài RBZ bằng Extension Manager, đóng hoàn toàn SketchUp rồi mở lại; xác nhận v3.6.3-rc1. Có thể xuất các trang đã lưu, không cần xếp lại. Không đổi trạng thái extension khác, không có thay đổi xuất CAD.

Chưa xác nhận kết quả trên SketchUp 2023 Windows thực hoặc nguyên nhân BugSplat/xung đột extension. Model SKP mới vượt giới hạn tải 32 MiB của công cụ nên chưa được đọc. Không xuất bản model, tên file khách hàng, ảnh người dùng hoặc dữ liệu crash.

Nếu còn lỗi khi xuất: Extensions → HP Layout Pro v3.6.3-rc1 → Nhật ký xuất PDF…; file %APPDATA%\HP_LayoutPro\last_pdf_export.log. Nếu dừng trước khi tạo trang: Nhật ký đo/xếp Scene… / last_layout.log. Tên Scene và thông tin extension trong nhật ký có thể liên quan dự án; xem lại trước khi chia sẻ.
