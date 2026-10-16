# Kiểm tra HP Layout Pro 3.6.1-rc1

Ngày 16/10/2026. Mục tiêu: giảm nguy cơ crash tài nguyên/native khi bắt đầu xuất PDF, giảm khựng lúc khít trang và chuyển view. Chưa xác định DLL gây BugSplat trên máy người dùng; chưa chạy SketchUp 2023 Windows trực tiếp.

## Thay đổi

1. Hàng đợi native ngoài callback HtmlDialog: mỗi timer dựng một Scene, khóa chống gọi chồng, nhường một nhịp lúc bắt đầu để các cập nhật model đang chờ kết thúc. Hủy/đổi model loại công việc đang chờ. Giữ công thức camera và tỷ lệ giấy của bản trước.
2. PNG xuất trên nền giấy trắng không dùng alpha; ảnh native được giữ trong thư mục tạm riêng và tải qua URL file có mã hóa đường dẫn. Không đưa PNG native lớn qua JSON/base64 của HtmlDialog. File tạm được dọn khi xong/hủy; thử dọn lại nếu Windows còn giữ khóa file.
3. Tờ PDF được vẽ theo mảnh tối đa 1536×1536 pixel trên canvas nhỏ; không tạo bitmap GPU/OffscreenCanvas cho cả tờ. PDF chứa các ảnh đặt đúng tọa độ pixel/đơn vị giấy. Các đoạn base64 tối đa 65.536 ký tự được ghi đĩa và xác nhận lần lượt, không nối cả trang trong Ruby.
4. Chặn trước write_image khi một ảnh vượt 32 MP; chặn tổng ảnh trên trang vượt 48 MP. Không âm thầm giảm DPI mới để vượt chặn. Các giới hạn/camera cap có sẵn và DPI thực tế vẫn phụ thuộc viewport native.
5. Khít cùng trang giữ DOM, cập nhật tỷ lệ/ảnh. Khít không đổi tỷ lệ không lưu/dựng lại. Kết quả chờ có kiểm tra trang/model/epoch. Chỉ dựng ảnh chính xác sau khi ngừng chuyển trang; dùng lại ảnh trực giao nếu đủ nội dung/độ nét màn hình. Danh sách Scene đầy đủ được nạp khi mở dropdown.
6. Lưu dự án khi có sửa hoặc khi xác nhận xuất, tránh gửi cả dự án mỗi lần chuột rời tờ giấy. Nhật ký ghi extension đang nạp và các checkpoint trước/sau API native; có mục menu mở log.

## Kết quả

- **42 Scene → 42 trang A3, 6720×4752 pixel/trang**: 20 mảnh/trang, 840 mảnh; 1258 đoạn dữ liệu được xác nhận; không gọi confirm khi tỷ lệ/DPI thấp hơn mục tiêu thử.
- Canvas lớn nhất: **31.933.440 → 2.359.296 pixel** (~128 MB → 9,4 MB cho riêng một buffer RGBA). Không suy ra tổng RAM hay thời gian SketchUp từ số này.
- Bài thử tải ảnh bằng URL file thật có khoảng trắng trong đường dẫn. Cố tình vô hiệu createImageBitmap, OffscreenCanvas và CompressionStream: đường xuất theo mảnh vẫn hoàn tất bằng PNG RGB.
- Toàn bộ thông điệp thực từ Chromium được phát lại qua Session Ruby và PdfWriter thật; đủ 42 xác nhận trang. PyMuPDF mở đúng 42 khổ A3, đọc/vẽ đủ 840 ảnh.
- Hai tờ đầu (một view và hai view, có chữ/đường chú thích) được ghép lại toàn bộ RGB để so với canvas cả tờ: bounds trùng khớp; không có vệt trắng ở các đường chia mảnh trong hình. RGB không trùng từng byte khi raster hóa theo mảnh: sai khác trung bình 0,0112 và 0,0119 trên thang 255/kênh; điểm khác lớn tập trung ở rìa/nét. Không tuyên bố toàn bộ pixel giống bản trước.
- Luồng tổng hợp tiếp trang + phối cảnh crop/zoom + chú thích theo mảnh: 3 trang đạt; dọn ảnh sau hoàn tất đạt.
- 18 kiểm tra Ruby lõi, 7 kiểm tra hàng đợi xem trước và 8 nhóm ổn định mới đạt: native ngoài callback/một Scene mỗi timer, file ảnh riêng, đúng vị trí 4 mảnh, hủy trước native, sai thứ tự/thiếu mảnh không hoàn tất, khóa chống gọi chồng, chặn ảnh trước write_image, liệt kê extension không thay trạng thái, dọn file đang khóa vẫn gọi hoàn tất một lần.
- Khít trang giữ các node/giá trị tỷ lệ, bấm lại không vẽ; dropdown mở đủ Scene; quay lại trang dùng cache; không mất trường chữ đang gõ; trang bỏ qua không chụp; kết quả sau Cập nhật bị loại; chỉ lưu có sửa/force xuất đạt. Thử chuyển lại trang đã có cache khoảng 40 ms trong trình duyệt mô phỏng, không phải thời gian native/GPU Windows.
- Kiểm tra chọn nhiều nhóm/Scene, tìm kiếm, tạo đủ trang, khung bao và các phương án bố cục đạt. 16 nhóm planner và 13 kiểm tra JS lõi đạt.

## Xung đột và giới hạn xác minh

Đọc mã HP SCENE 3.23 trong kho: namespace Fbu::EasyScenes khác HP::LayoutPro; có observer/timer tự cập nhật DIM, không tìm thấy trùng module trực tiếp. Chưa có danh sách extension thực trên máy, crash XML/log/dump hoặc phép thử chỉ bật một extension nên **không kết luận có/không xung đột** hay quy lỗi cho extension cụ thể. Cửa sổ BugSplat là bằng chứng crash ứng dụng, không chỉ ra module gây crash.

model SKP mới vượt giới hạn tải 32 MiB của công cụ nên chưa đọc model. Không đưa SKP, ảnh người dùng hoặc dữ liệu crash vào bản phát hành. Nhật ký mới và bugsplat.log/XML cần được xem để chẩn đoán tiếp nếu Windows vẫn crash. Những kiểm tra mô phỏng ở trên không thay thế việc xác minh BugSplat trên máy thực.
