# Kiểm tra HP Layout Pro 3.6.0-rc1

Ngày 15/10/2026. Môi trường Linux/Chromium và API SketchUp mô phỏng; chưa chạy trực tiếp SketchUp 2023 Windows. Yêu cầu đã được làm rõ: PDF vẫn xuất được; mục tiêu là nhanh/mượt hơn và bỏ câu hỏi tỷ lệ/DPI, không phải sửa file PDF hỏng.

## Thay đổi và kiểm tra chính

- **Một trang / một view cho nhiều cấu kiện**: chọn cả nhóm hoặc Scene lẻ, tạo đủ trang từ các nhóm, khung bật mặc định, vừa vùng vẽ theo chiều giới hạn, tiêu đề phân biệt cấu kiện. Kiểm tra 50 Scene → 50 trang, không trùng ID/Scene, có phối cảnh, giữ trang/chú thích đã có khi tạo thêm. Không áp dụng giới hạn 24 Scene của chế độ ghép.
- **Giao diện**: tính bố cục trên worker chỉ nhận số đo/cấu hình, không nhận ảnh hay nội dung trang cũ. Hủy công việc/kết quả cũ khi đổi lựa chọn, đóng hộp hoặc Cập nhật. Có kiểm tra đường dự phòng khi worker không dùng được.
- **Ảnh xem trước**: thumbnail được tạo riêng cho thẻ phương án, ảnh hiển thị chính/xuất vẫn giữ nguyên. Quick Layout hiển thị 6 tờ/lượt, hộp chọn từng view 12 tờ/lượt; tạo vẫn đầy đủ toàn bộ trang.
- **Khít tất cả / Cập nhật**: xử lý theo đợt 8 trang với tiến độ; dùng lại số đo có sẵn, hủy callback khít/tính cũ sau Cập nhật. Kiểm tra đủ 50 trang với các đợt 8/8/8/8/8/8/2 và không áp dụng kết quả khít cũ sau refresh.
- **Xuất hàng loạt**: đo theo đợt, dùng cache native còn hợp lệ; dựng/ghép/nén từng trang. Trả ảnh đã dùng trước khi dựng trang kế tiếp và giữ cache dùng chung có giới hạn. Ruby xác nhận từng trang đã nhận, kiểm tra thứ tự/phần dữ liệu trước khi hoàn tất.
- **Không hỏi tiếp tục về tỷ lệ/DPI**: bài thử chủ động đặt tỷ lệ thấp hơn mục tiêu và DPI ảnh thấp hơn mức yêu cầu, vẫn xuất liền mạch không gọi confirm hay hiển thị nút tiếp tục. Các lỗi thật như thiếu ảnh/Scene, trắng/cắt hình/DIM hoặc ghi file lỗi vẫn được giữ.

## Bằng chứng đo

Bộ giao diện 50 Scene mô phỏng, cùng phương án và số đo:

| Chỉ số | 3.5.1 | 3.6.0 |
| --- | --- | --- |
| Khoảng ngắt heartbeat lớn nhất khi tính bố cục | 327 ms | 11 ms |
| Độ dài chuỗi HTML thẻ phương án | ~121 triệu ký tự | ~7.2 triệu ký tự |
| Số tờ xem trước tạo ngay | 119 | 30 |

Các chữ ký bố cục/tỷ lệ trước và sau giống nhau; các con số trên đo giao diện với dữ liệu mô phỏng, không phải FPS hay thời gian GPU SketchUp.

Nén cùng một trang A3 6720×4752 pixel, chạy luân phiên ba lượt: trung vị đường RGB/Flate cũ **1006 ms**, đường PNG RGB mới trên worker **627 ms**. Khoảng ngắt giao diện của các lượt PNG mới là 20–27 ms. Đọc lại cả hai kiểu bằng bộ ghi PDF của plugin và PyMuPDF cho cùng toàn bộ RGB; SHA256 `adaa55e9a80adb0c7480c890e753f63ad6acaefee97ba6ed56f759538bf74dde`. Đây là tối ưu không mất điểm ảnh, không hạ DPI. File có thể lớn hơn: mẫu nén nhanh khoảng 652 KB so với 239 KB của đường cũ, tùy nội dung.

Bài xuất **50 Scene khác nhau / 50 trang A3** ở 16 px/mm (khoảng 400 dpi): kiểm tra đủ thứ tự trang, đủ khung hình, luồng nén hợp lệ, xác nhận lưu từng trang và không còn hỏi tỷ lệ/DPI. Với bộ một view/trang, đỉnh số ảnh Scene giữ đồng thời giảm từ 50 xuống 1; trang nhiều view vẫn cần giữ ảnh của các ô trên trang và cache dùng chung. Bộ ghi PDF của plugin tạo đủ 50 trang; PyMuPDF đọc lại toàn bộ 50 ảnh RGB khác nhau ở 6720×4752, đúng khổ A3. Kết quả này không phải phép đo RAM tuyệt đối hay cam kết tổng thời gian xuất trên Windows.

Mô phỏng Ruby xác nhận 50 Scene đã đo được dùng lại mà không chụp đo thêm, đủ 50 yêu cầu dựng ảnh, 50 xác nhận trang và PDF 50 trang. Dữ liệu sai thứ tự được từ chối.

## Hồi quy

- 16 nhóm kiểm tra bộ xếp và chọn Scene, 13 kiểm tra JS lõi đạt; khung/độ lớn/tỷ lệ/lọc/nhóm và một trang mỗi Scene được giữ.
- Giao diện chọn nhiều nhóm, checkbox một phần, tìm kiếm giữ lựa chọn, đổi chế độ bỏ phương án cũ, tạo thêm đủ trang và hủy/Cập nhật đạt.
- PDF cũ gồm tổng hợp, chú thích và ảnh dùng chung giữ cùng toàn bộ điểm ảnh; bố cục mới và trang một view được đối chiếu chiều cao hình theo tỷ lệ giấy.
- 18 kiểm tra Ruby lõi, 7 hàng đợi xem trước và kiểm tra giao thức/cache xuất hàng loạt đạt. Không đổi công thức camera, kích thước ảnh native, cách khôi phục trạng thái model hoặc xuất CAD.
- Ảnh về cập nhật riêng trong ô; giữ trường đang gõ, quay lại trang dùng cache, lướt nhanh ưu tiên trang cuối, Cập nhật loại kết quả cũ đạt.

PDF minh họa kèm bản phát hành là 4 Scene từ 2 cấu kiện giả lập, mỗi trang một view. Không chứa model/ảnh của khách hàng. Việc đọc lại PDF không thay thế nghiệm thu in thực tế. Tốc độ toàn bộ vẫn phụ thuộc độ phức tạp model, GPU, số view, DPI và phần cứng; không suy ra thời gian Windows từ các phép đo này.
