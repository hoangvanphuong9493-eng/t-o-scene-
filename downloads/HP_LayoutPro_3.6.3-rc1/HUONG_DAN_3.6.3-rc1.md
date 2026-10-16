# HP Layout Pro 3.6.3-rc1 — Sửa chặn PDF khi trang có nhiều view

Dành cho SketchUp 2023 Windows. Bản này sửa thông báo “Ảnh các view trên trang vượt ngưỡng bộ nhớ an toàn” khi xuất trang có nhiều view. Giữ các sửa lỗi chờ đo/xếp Scene của 3.6.2.

## Cài đặt

Window → Extension Manager → Install Extension → chọn **HP_LayoutPro_v3.6.3-rc1.rbz**. Lưu công việc, đóng hoàn toàn tất cả cửa sổ SketchUp rồi mở lại. Kiểm tra góc HP Layout Pro hiện **v3.6.3-rc1**. Chỉ đóng cửa sổ plugin không xóa trạng thái khóa Ruby của bản cũ đang chạy.

Mở lại model và xuất các trang đã có; không cần tạo lại bố cục chỉ để áp dụng sửa lỗi PDF này. Bố cục khung, lựa chọn nhiều cấu kiện/Scene, 1 trang/1 view và các trang/chú thích đã lưu tiếp tục được giữ.

## Sửa bộ nhớ ảnh PDF

Bản trước có thể chặn khi cộng toàn bộ pixel của các ảnh gốc trên một trang vượt 48 triệu pixel. Ảnh gốc giữ tỷ lệ viewport SketchUp; view cao/hẹp thường có vùng lớn nằm ngoài ô trên giấy. Vì vậy tổng pixel ảnh gốc có thể lớn dù vùng in trên tờ vẫn vừa.

- Ảnh native được dựng qua timer như trước, lưu thành file; danh sách file được giữ mà không mở tất cả ảnh cùng lúc trong cửa sổ PDF.
- Mỗi mảnh PDF chỉ nạp các view giao với vùng đang vẽ. Cache ảnh được thu hồi theo nhu cầu, tối đa 32 MP thường trú; bộ đệm ảnh đang nạp/cắt/giữ có ngân sách 48 MP theo pixel được quản lý.
- Phần ngoài ô được cắt bằng tọa độ pixel nguyên, không đổi mật độ pixel hoặc camera. Chừa vùng lọc và nét đậm để không cắt mất nét ở mép. Hình/DIM được kiểm tra trên ảnh gốc trước khi cắt.
- Khung/tiêu đề, ảnh, chú thích và khung tên giữ thứ tự lớp. Không tự đổi trang, tỷ lệ hoặc DPI để vượt lỗi tổng ảnh của bản trước.
- Cache là một phần bộ nhớ; những con số trên không phải giới hạn tổng RAM/GPU của SketchUp, bộ giải mã, canvas hay model. Không có cam kết hết mọi BugSplat.

## Sửa lỗi đo/xếp Scene

- Khóa dựng ảnh luôn được nhả sau khi xử lý, kể cả khi bước khôi phục tùy chọn SketchUp phát sinh lỗi.
- Lỗi trước khi đưa vào hàng đợi, lỗi timer, kết quả không mã hóa được và thay model trả thông báo về đúng yêu cầu đo.
- Đổi lựa chọn hoặc đóng hộp chọn sẽ bỏ yêu cầu đo đang chờ của hộp đó. Kết quả cũ không được áp dụng vào lựa chọn mới; yêu cầu khít/xem khác vẫn được giữ.
- Quick Layout hiện Scene và bước đang xử lý. Khi có lỗi, hiện nội dung lỗi và nút **Thử đo lại Scene lỗi**; chỉ xóa phép đo lỗi của những Scene đang chọn.
- Ảnh không giải mã xong trong 15 giây trả lỗi. Yêu cầu đo không có tiến độ trong 90 giây trả lỗi nếu cửa sổ HTML vẫn phản hồi; mỗi tiến độ mới gia hạn thời gian chờ.

Giới hạn thời gian ở giao diện không thể ngắt một lệnh native đang treo hoặc ngăn mọi BugSplat. Chưa xác nhận nguyên nhân chính xác trên máy Windows của người dùng.

## Nếu vẫn dừng khi đo

Mở **Extensions → HP Layout Pro v3.6.3-rc1 → Nhật ký đo/xếp Scene…**.

File: **%APPDATA%\HP_LayoutPro\last_layout.log**. Nhật ký này ghi từ lúc đo/xếp, không cần bắt đầu xuất PDF. Ghi ID yêu cầu, Scene, bước, số công việc chờ, trạng thái khóa và lỗi. File xoay vòng khi vượt khoảng 2 MB; không chứa ảnh hay hình học model. Tên Scene và lỗi có thể chứa thông tin dự án, nên xem lại trước khi chia sẻ.

Nếu vẫn không tạo được trang, gửi nhật ký này và ảnh bước đang dừng. Nếu SketchUp bị đóng/BugSplat, gửi thêm **bugsplat.log** và **.xml** trong danh sách **View Report Details…**, thường ở **%LOCALAPPDATA%\Temp**. Ảnh BugSplat không cho biết DLL hay stack gây lỗi.

## Xuất PDF

Giữ luồng dựng Scene qua timer ngoài callback HtmlDialog, ảnh native qua file tạm và PDF theo mảnh tối đa 1536×1536 pixel. Giữ tỷ lệ/DPI đã chọn; không hỏi tiếp tục khi tỷ lệ/DPI thấp hơn mục tiêu.

Giữ chặn trước dựng ảnh native riêng lẻ vượt 32 MP; giữ các giới hạn kích thước ảnh/khổ PDF có sẵn. Bản sửa không tăng chặn để giữ đồng thời mọi ảnh lớn và không tự hạ DPI để vượt lỗi tổng ảnh. Nhật ký **%APPDATA%\HP_LayoutPro\last_pdf_export.log** có thống kê giải mã/cắt ảnh và số pixel ảnh đang quản lý; mở bằng **Nhật ký xuất PDF…**.

## Xác minh và giới hạn

Đã tái hiện chặn tổng ảnh của 3.6.2 trên một trang 4 view. Luồng mới xuất được 3 trang A3 ở 16 px/mm (khoảng 400 dpi), đọc độc lập đủ 60 mảnh ảnh và đối chiếu với bộ vẽ cũ; không có vệt trắng ở đường ghép, bounds hình khớp trong 1 pixel. Raster theo mảnh có sai khác nhỏ tại rìa/nét, không tuyên bố pixel giống từng byte. Luồng 50 Scene/50 trang được kiểm tra riêng ở 4 px/mm để xác minh thứ tự và vòng đời ảnh; không có câu hỏi tỷ lệ/DPI. Kiểm tra ảnh lỗi, giới hạn, Quick Layout, khít/xem trang và PDF tổng hợp đạt. Đây là Chromium thật/API SketchUp mô phỏng, chưa phải kiểm chứng SketchUp 2023 Windows thực.

Chưa có crash dump/log để kết luận xung đột extension. Mã HP SCENE trong kho dùng namespace Fbu::EasyScenes, khác HP::LayoutPro; có observer/timer DIM nên tương tác chỉ là khả năng cần kiểm tra, chưa phải nguyên nhân đã xác minh. Plugin không tự tắt extension khác.

Model SKP mới vượt giới hạn tải 32 MiB của công cụ nên chưa được mở/phân tích trực tiếp. Gói phát hành không chứa model, ảnh hay dữ liệu crash của người dùng.
