# HP Layout Pro 3.6.1-rc1 — Sửa luồng xuất PDF và khít/xem trang

Dành cho SketchUp 2023 Windows. Đây là bản sửa sau báo cáo BugSplat ngay lúc bắt đầu xuất khoảng 42 Scene. Chưa có crash dump/log để xác nhận module gây crash và chưa thử trực tiếp trên máy Windows của người dùng.

## Cài đặt và sử dụng

Window → Extension Manager → Install Extension → chọn **HP_LayoutPro_v3.6.1-rc1.rbz**. Thoát và mở lại SketchUp; kiểm tra góc plugin hiện **v3.6.1-rc1**.

Bố cục, khung view, chọn nhiều cấu kiện/Scene và 1 trang/1 view giữ như 3.6.0. Câu hỏi tiếp tục về tỷ lệ/DPI vẫn được bỏ.

- **Khít trang / Khít ô**: dùng số đo đang có, cập nhật tỷ lệ và ảnh trong ô; giữ các điều khiển khi bố cục không đổi. Bấm lại khi đã khít không yêu cầu dựng ảnh mới.
- **Chuyển trang**: hiện ảnh đang có ngay, dùng lại ảnh trực giao đủ vùng/đủ độ nét cho màn hình. Chờ thao tác chuyển trang dừng rồi mới dựng ảnh chính xác còn thiếu. Việc này không đổi ảnh xuất PDF.
- **Xuất PDF**: dựng từng Scene qua hàng đợi của SketchUp; chuyển ảnh bằng file tạm; ghép tờ giấy và nén trực tiếp theo mảnh nhỏ, gửi dữ liệu theo từng đoạn có xác nhận. Giữ khổ giấy và tỷ lệ; không tự giảm DPI để vượt giới hạn an toàn mới.

Một ảnh native vượt **32 triệu pixel**, hoặc tổng ảnh một trang vượt **48 triệu pixel**, sẽ dừng bằng thông báo có số liệu/hướng xử lý. Khi gặp giới hạn này, chọn DPI thấp hơn hoặc chia view/khổ giấy trước khi xuất lại. Đây là báo lỗi tài nguyên, không phải hộp hỏi có tiếp tục hay không. Ảnh rất lớn và model phức tạp vẫn phụ thuộc GPU, RAM và driver của SketchUp.

## Nhật ký và BugSplat

Sau khi bắt đầu xuất, mở **Extensions → HP Layout Pro v3.6.1-rc1 → Nhật ký xuất PDF…**.

File trên Windows: **%APPDATA%\HP_LayoutPro\last_pdf_export.log**.

Nhật ký ghi bản SketchUp/plugin, tên/phiên bản/trạng thái nạp của các extension, bước đo/đổi Scene/chụp ảnh/khôi phục model, kích thước ảnh và trang đã ghi. Nếu ứng dụng crash trong API native, dòng cuối giúp khoanh vùng bước dừng. Nhật ký mới thay nhật ký của lượt xuất trước.

Để xác định nguyên nhân BugSplat, cần thêm **bugsplat.log** và tệp **.xml** được liệt kê trong cửa sổ **View Report Details…** (ảnh đã gửi cho thấy chúng nằm ở **%LOCALAPPDATA%\Temp**). Chỉ ảnh cửa sổ BugSplat không cho biết DLL hay stack lỗi.

## Kiểm tra khả năng xung đột

Không thể xác định những extension đang nạp trên máy chỉ từ file SKP. Đối chiếu mã HP SCENE 3.23 trong kho hiện có cho thấy nó dùng namespace **Fbu::EasyScenes**, khác **HP::LayoutPro**; chưa thấy trùng tên module/constant trực tiếp. HP SCENE có observer và timer tự cập nhật DIM; các extension khác cũng có thể phản ứng với đổi Scene/style/camera. Đây là khả năng cần kiểm tra bằng log, chưa phải kết luận nguyên nhân crash.

Nếu cần thử tách extension: dùng một bản sao SKP đã lưu Scene; trong Extension Manager chỉ bật HP Layout Pro, khởi động lại SketchUp rồi thử xuất ít trang trước. Nếu lượt đó chạy được, bật lại từng nhóm extension và khởi động lại để khoanh vùng. Bản sửa ghi danh sách extension, không tự thay trạng thái bật/tắt của extension khác.

## Phạm vi kiểm tra

Đã kiểm tra Linux/Chromium với API SketchUp mô phỏng: 42 Scene/42 trang A3 ở 16 px/mm (khoảng 400 dpi), 840 mảnh ảnh đọc được trong PDF; tổng hợp nhiều trang, phối cảnh, chú thích, hủy, thứ tự dữ liệu, khôi phục trạng thái và giới hạn trước khi gọi write_image. Kiểm tra khít giữ DOM, sửa chữ không mất, dropdown đủ Scene, chuyển trang nhanh không chụp trang cũ và chỉ lưu khi có sửa đạt.

Canvas PDF lớn nhất trong bài thử giảm từ 31.933.440 xuống 2.359.296 pixel. Đây là kích thước canvas, không phải tổng RAM/GPU của SketchUp hay cam kết hết BugSplat. Vị trí hình trong hai tờ đối chiếu trùng khớp; raster hóa theo mảnh có khác biệt nhỏ tại rìa/nét so với canvas cả tờ, không hạ DPI. In ở 100% / Actual size.

File model SKP mới người dùng gửi vượt giới hạn tải 32 MiB của công cụ, nên chưa được mở/phân tích trực tiếp. Gói phát hành không chứa model, ảnh hay báo cáo crash của người dùng.
