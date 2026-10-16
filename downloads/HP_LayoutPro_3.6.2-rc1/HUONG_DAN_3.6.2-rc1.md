# HP Layout Pro 3.6.2-rc1 — Sửa chờ đo Scene trong Quick Layout

Dành cho SketchUp 2023 Windows. Bản này xử lý các đường lỗi có thể khiến Quick Layout đứng ở “Đang đo hình + DIM và so sánh bố cục…” khi chưa tạo trang.

## Cài đặt

Window → Extension Manager → Install Extension → chọn **HP_LayoutPro_v3.6.2-rc1.rbz**. Lưu công việc, đóng hoàn toàn tất cả cửa sổ SketchUp rồi mở lại. Kiểm tra góc HP Layout Pro hiện **v3.6.2-rc1**. Chỉ đóng cửa sổ plugin không xóa trạng thái khóa Ruby của bản cũ đang chạy.

Mở model → Quick Layout → chọn cấu kiện/Scene → chờ phương án → Tạo trang. Bố cục khung, lựa chọn nhiều cấu kiện/Scene, 1 trang/1 view và các trang/chú thích đã lưu tiếp tục được giữ.

## Sửa lỗi đo/xếp Scene

- Khóa dựng ảnh luôn được nhả sau khi xử lý, kể cả khi bước khôi phục tùy chọn SketchUp phát sinh lỗi.
- Lỗi trước khi đưa vào hàng đợi, lỗi timer, kết quả không mã hóa được và thay model trả thông báo về đúng yêu cầu đo.
- Đổi lựa chọn hoặc đóng hộp chọn sẽ bỏ yêu cầu đo đang chờ của hộp đó. Kết quả cũ không được áp dụng vào lựa chọn mới; yêu cầu khít/xem khác vẫn được giữ.
- Quick Layout hiện Scene và bước đang xử lý. Khi có lỗi, hiện nội dung lỗi và nút **Thử đo lại Scene lỗi**; chỉ xóa phép đo lỗi của những Scene đang chọn.
- Ảnh không giải mã xong trong 15 giây trả lỗi. Yêu cầu đo không có tiến độ trong 90 giây trả lỗi nếu cửa sổ HTML vẫn phản hồi; mỗi tiến độ mới gia hạn thời gian chờ.

Giới hạn thời gian ở giao diện không thể ngắt một lệnh native đang treo hoặc ngăn mọi BugSplat. Chưa xác nhận nguyên nhân chính xác trên máy Windows của người dùng.

## Nếu vẫn dừng khi đo

Mở **Extensions → HP Layout Pro v3.6.2-rc1 → Nhật ký đo/xếp Scene…**.

File: **%APPDATA%\HP_LayoutPro\last_layout.log**. Nhật ký này ghi từ lúc đo/xếp, không cần bắt đầu xuất PDF. Ghi ID yêu cầu, Scene, bước, số công việc chờ, trạng thái khóa và lỗi. File xoay vòng khi vượt khoảng 2 MB; không chứa ảnh hay hình học model. Tên Scene và lỗi có thể chứa thông tin dự án, nên xem lại trước khi chia sẻ.

Nếu vẫn không tạo được trang, gửi nhật ký này và ảnh bước đang dừng. Nếu SketchUp bị đóng/BugSplat, gửi thêm **bugsplat.log** và **.xml** trong danh sách **View Report Details…**, thường ở **%LOCALAPPDATA%\Temp**. Ảnh BugSplat không cho biết DLL hay stack gây lỗi.

## Xuất PDF

Giữ luồng dựng Scene qua timer ngoài callback HtmlDialog, ảnh native qua file tạm và PDF theo mảnh tối đa 1536×1536 pixel. Giữ tỷ lệ/DPI đã chọn; không hỏi tiếp tục khi tỷ lệ/DPI thấp hơn mục tiêu.

Giữ chặn trước dựng ảnh khi một ảnh vượt 32 MP hoặc tổng ảnh một trang vượt 48 MP; báo lỗi tài nguyên để người dùng chia trang/chọn DPI khác. Không tự giảm DPI để vượt chặn. Xem **Nhật ký xuất PDF…** hoặc **%APPDATA%\HP_LayoutPro\last_pdf_export.log** nếu đã bắt đầu xuất.

## Xác minh và giới hạn

Đã tái hiện lỗi khóa còn giữ của 3.6.1 bằng API mô phỏng phát sinh lỗi ở bước khôi phục tùy chọn; bản mới nhả khóa. Đã kiểm tra Chromium thật/API SketchUp mô phỏng: MB chưa có trang → đo → tạo trang; lỗi/thử lại/hủy/đổi phạm vi; khít/xem trang; chọn nhiều nhóm; PDF theo mảnh có tổng hợp, phối cảnh và chú thích. Không coi các thử nghiệm này là kiểm chứng SketchUp 2023 Windows thực.

Chưa có crash dump/log để kết luận xung đột extension. Mã HP SCENE trong kho dùng namespace Fbu::EasyScenes, khác HP::LayoutPro; có observer/timer DIM nên tương tác chỉ là khả năng cần kiểm tra, chưa phải nguyên nhân đã xác minh. Plugin không tự tắt extension khác.

Model SKP mới vượt giới hạn tải 32 MiB của công cụ nên chưa được mở/phân tích trực tiếp. Gói phát hành không chứa model, ảnh hay dữ liệu crash của người dùng.
