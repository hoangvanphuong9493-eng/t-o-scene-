# Kiểm tra hiệu năng HP Layout Pro 3.4.1-rc1

Ngày kiểm tra: 14/10/2026. Bản đối chiếu: 3.4.0-rc1, bản người dùng đã xác nhận chạy/in ổn định.

Môi trường: Linux; Ruby 3.3 với API SketchUp giả lập; Chromium 153. API của SketchUp 2023 Windows và tốc độ GPU của máy người dùng không được mô phỏng đầy đủ. Không có thay đổi thuật toán chia trang/tỷ lệ/DIM hoặc giảm chất lượng để đạt số đo.

## Lưu và khôi phục trạng thái model

500.000 Drawingelement giả lập, 5 lần cho mỗi bản; kiểm tra đầy đủ thứ tự/giá trị trạng thái ẩn. Thời gian trung vị:

| Thành phần | 3.4.0-rc1 | 3.4.1-rc1 |
|---|---:|---:|
| Lưu trạng thái | 131 ms | 98 ms |
| Khôi phục trạng thái | 276 ms | 63 ms |

Các thao tác chọn Scene, render và khôi phục đều có lợi từ phần xử lý này trên model lớn; số đo không bao gồm thời gian gọi API SketchUp thật.

## Giao diện

Dự án giả lập 300 trang, 3 vòng × 100 lần cập nhật/chuyển chọn. Cưỡng bức đo layout DOM sau mỗi lần để tránh chỉ đo tạo chuỗi HTML.

Trung vị mỗi vòng: 2328 ms → 23 ms. Kiểm tra giữ node danh sách, dấu chọn trang/tổng hợp, lọc trang, thanh công cụ tác động đúng trang và không tính khít thừa đều đạt. Đổi mục tiêu tỷ lệ tham khảo không dựng lại các phương án.

## Nén PDF

Ảnh A3 6720 × 4752 px (~406 dpi), mỗi lượt dùng canvas mới như khi xuất thật; 3 lần mỗi bản, đảo thứ tự. Đo đến khi có dữ liệu Base64 gửi cho Ruby. Hai ảnh mẫu được trích tại chỗ từ PDF người dùng; ảnh đầu vào không nằm trong gói phát hành.

| Mẫu | Nén bản cũ (trung vị) | Nén bản mới (trung vị) | Khoảng gián đoạn luồng giao diện lớn nhất: cũ → mới |
|---|---:|---:|---:|
| Synthetic dense A3 | 2970 ms | 2666 ms | 3090 → 189 ms |
| User sample PDF page 1 | 1082 ms | 1109 ms | 1420 → 26 ms |
| User sample PDF page 5 | 1098 ms | 1050 ms | 1407 → 26 ms |

Đây là phép đo heartbeat trình duyệt mỗi 10 ms; có thể bao gồm ảnh hưởng lập lịch/GC của môi trường. Thời gian nén tổng thể còn dao động, đặc biệt ở mẫu tổng hợp; chưa đủ để cam kết một mức tăng tốc cho toàn bộ lần xuất. Cải thiện rõ nhất là giao diện tiếp tục nhận lượt xử lý khi nén, giảm cập nhật DOM và giảm chi phí lưu/khôi phục model.

## Tính đúng

- 18 kiểm tra Ruby và 11 kiểm tra JavaScript đạt; hồi quy khít giấy và 8 phương án chia trang đạt.
- So sánh dữ liệu RGB sau giải nén ở ba ảnh A3 lớn: giống hệt từng byte giữa hai bộ nén. Độ dài dữ liệu nén cũng giữ nguyên trong các ca này.
- Chạy toàn bộ luồng xuất trong Chromium: 5 trang gồm bảng tổng hợp nối trang, chú thích và 3 trang dùng chung ảnh Scene. Hash điểm ảnh từng trang giống bản cũ; ảnh chỉ được giải phóng sau trang cuối sử dụng.
- Phát lại dữ liệu gửi từ Chromium qua Renderer Ruby và PdfWriter thật; đọc lại PDF bằng PyMuPDF, hash RGB khớp và kích thước giấy A3 chính xác.
- Kiểm tra đường dự phòng khi thiếu OffscreenCanvas/createImageBitmap, khi worker bị chặn và khi thiếu CompressionStream.
- Kiểm tra duy trì khôi phục model sau lỗi chụp, dữ liệu dự án, thiếu Scene/trang, hủy tác vụ, thứ tự trang và chặn xuất đồng thời.
- Cú pháp Ruby/JavaScript đạt. Không chỉnh các API dựng ảnh, thông số scale_factor/DPI, công thức chia trang, bộ ghi PDF hoặc xuất CAD.

## Sử dụng

Cài RBZ qua Extension Manager và khởi động lại SketchUp. Dữ liệu bố cục/khung tên hiện có tiếp tục được dùng. Bản phát hành này cần được đánh giá thời gian thực tế trên chính model/máy SketchUp 2023 Windows của người dùng; các kết quả trên là kiểm tra thành phần, không phải phép đo đầu-cuối trên SketchUp.
