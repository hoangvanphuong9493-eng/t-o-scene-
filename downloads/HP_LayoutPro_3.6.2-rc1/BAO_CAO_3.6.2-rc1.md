# Kiểm tra HP Layout Pro 3.6.2-rc1

Ngày 16/10/2026. Mục tiêu: xử lý Quick Layout chờ đo hình + DIM khi chưa có trang, hủy yêu cầu cũ và trả lỗi rõ ràng. Bản thử dành cho SketchUp 2023 Windows; kiểm tra thực hiện trên Linux/Chromium và API SketchUp mô phỏng.

## Lỗi đã tái hiện và sửa

- 3.6.1 có thể giữ khóa dựng ảnh khi gán lại tùy chọn ShowTransition phát sinh lỗi. Hàng đợi thấy đang chụp sẽ tiếp tục chờ. Cùng phép thử làm lỗi bước khôi phục: bản cũ giữ khóa, bản mới nhả khóa. Đây là lỗi mã được tái hiện bằng mô phỏng, chưa chứng minh nó là nguyên nhân chính xác trong model/máy người dùng.
- Lỗi quét stamp trước enqueue, tạo timer và mã hóa JSON trước đây có thể chỉ hiện thông báo chung/console. Nay trả lỗi Scene có ID để hoàn tất yêu cầu đang chờ; lỗi tạo timer cũng nhả trạng thái pump.
- Ghi tiến độ/CEF bị lỗi không cản khôi phục model. Kết quả của yêu cầu đã hủy hoặc model đã đổi không được áp dụng nhầm.
- Quick Layout và Chọn Scene có nhóm yêu cầu riêng; hủy chỉ loại công việc của nhóm đó. Giữ phép đo dùng cho khít/xem khác. Các yêu cầu trùng hoàn tất dùng kết quả cache và bỏ công việc dư đang chờ.
- Giới hạn chờ giải mã ảnh 15 giây; 90 giây không có tiến độ trả lỗi ở giao diện còn phản hồi. Không thể dùng timeout JavaScript để ngắt lệnh native đang treo. Nút thử lại chỉ xóa cache lỗi đã chọn. Thêm nhật ký last_layout.log trước giai đoạn PDF và menu mở nhật ký.

## Kiểm tra bản 3.6.2

- 18 kiểm tra Ruby lõi đạt: tỷ lệ, model state, nền trắng, CAD chọn lọc, phiên PDF, bảo vệ file đích, xác nhận trang và PDF writer.
- 10 nhóm hồi quy mới Ruby đạt: tái hiện khóa 3.6.1/nhả khóa mới; callback HtmlDialog thật qua timer; lỗi quét stamp; lỗi tạo timer rồi phục hồi; dữ liệu Infinity không mã hóa được; hủy có chọn lọc; hook ghi log lỗi không cản khôi phục; đổi model khi đang chờ; xóa đúng cache khi thử lại; truyền ID/tiến độ đo trong phiên PDF qua timer.
- 8 nhóm Chromium mới đạt: MB đang chọn và 0 trang → tiến độ đo → thẻ bố cục → tạo 1 trang MB; mất phản hồi kết thúc bằng lỗi; thử lại đúng Scene lỗi; tiến độ gia hạn chờ; đổi phạm vi loại kết quả cũ; hủy Quick giữ yêu cầu khác; đóng Chọn Scene hủy đo trước khi mở Quick; ảnh không phát load/error kết thúc bằng timeout. Không có lỗi JavaScript ngoài dự kiến.
- 7 nhóm hàng đợi xem trước đạt: bỏ yêu cầu trang cũ, một công việc mỗi timer, ưu tiên trang đang xem, giữ yêu cầu dùng chung, epoch, lỗi ảnh không kẹt hàng đợi và thứ tự focus.
- Kiểm tra chọn nhiều cấu kiện/Scene, ghép chung, 1 trang/1 view, tìm kiếm, giữ trang/chú thích cũ, khung và hủy lựa chọn đạt.
- Khít giữ node, bấm lại không gọi dựng ảnh mới; trang đã tải dùng lại cache; chuyển trang nhanh chỉ chụp trang cuối; không mất chữ đang sửa; Cập nhật bỏ kết quả cũ; chỉ lưu khi có sửa đạt. Đây là kiểm tra trình duyệt mô phỏng, không phải đo hiệu năng SketchUp Windows.
- PDF theo mảnh có tổng hợp nhiều trang + phối cảnh crop/zoom + chú thích: 3 trang hoàn tất, giải phóng ảnh đạt; phản hồi đo đã dùng ID mới. Mã ghép PDF/tile và công thức camera giữ như 3.6.1.
- Cú pháp tất cả Ruby/JavaScript và script nội tuyến được kiểm tra khi đóng gói. ZIP được đối chiếu từng byte với mã nguồn, có 28 file; SHA256 của 3 tài liệu/gói được ghi trong SHA256SUMS.txt.

Bài thử 42 Scene/840 mảnh ở 3.6.1 là bằng chứng của bản trước, không phải phép đo thời gian hay lần chạy lại 42 Scene trong đợt sửa này. Bản 3.6.2 giữ luồng ảnh qua file tạm, canvas tối đa 1536×1536 và chặn tài nguyên trước dựng ảnh. Không tự giảm DPI để vượt chặn, không hỏi tiếp tục về tỷ lệ/DPI.

## Giới hạn và dữ liệu cần nếu vẫn lỗi

Không có SketchUp 2023 Windows/GPU native trong môi trường này; chưa xác nhận hết BugSplat hay hết mọi khựng trên model lớn. Model SKP mới vượt giới hạn tải 32 MiB nên chưa mở được. Không xuất bản model, ảnh khách hàng hoặc dữ liệu crash.

Chưa có log/dump/XML để kết luận xung đột extension. HP SCENE dùng namespace Fbu::EasyScenes khác HP::LayoutPro; observer/timer DIM là tương tác có thể cần khảo sát, chưa phải nguyên nhân xác minh. Không tự bật/tắt extension khác.

Cần đóng hoàn toàn SketchUp và mở lại sau cài để xóa khóa/trạng thái bản cũ. Nếu Quick Layout còn dừng: Extensions → HP Layout Pro v3.6.2-rc1 → Nhật ký đo/xếp Scene…; file %APPDATA%\HP_LayoutPro\last_layout.log. Nếu đã xuất PDF: last_pdf_export.log trong cùng thư mục. Nếu BugSplat: bugsplat.log và XML trong View Report Details giúp xác định bước/module thay vì suy đoán từ ảnh.
