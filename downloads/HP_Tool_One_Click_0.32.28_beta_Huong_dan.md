# HP Tool One Click 0.32.28 beta — sửa tình trạng nặng model và tác vụ nền

## Cài bản sửa

1. Đóng hoàn toàn SketchUp. Nếu phiên đang treo, chờ hoặc đóng phiên đó; mở SketchUp với một model trống để cài.
2. Trong **Extension Manager → Install Extension**, chọn `HP_Tool_One_Click_0.32.28_beta.rbz` để cập nhật HP Tool.
3. Thoát rồi mở lại SketchUp để Ruby và giao diện cùng chạy bản 0.32.28. Cài đè khi SketchUp đang mở chưa thay được Ruby đã nạp.
4. Mở lại file và kiểm tra. Nếu trước đó đã dùng đánh dấu lỗi trên model, làm bước dọn dưới đây rồi **Lưu thành một file mới**.

## Dọn dấu lỗi cũ đang nằm trong file SketchUp

Bản 0.32.27 có thể tự tạo các vòng đánh dấu lỗi/cảnh báo thành hình học thật: tối đa 200 mục × 20 vòng, mỗi vòng dùng hai đường 48 cạnh và ghi chú. Khi lưu model, hình học này theo vào `.skp`; nhiều dấu có thể tăng chi phí dựng hình và mở file. Đây là một điểm rủi ro được xác nhận trong mã; chưa khẳng định là nguyên nhân duy nhất của mọi trường hợp treo.

Khi model đã mở, chọn **Extensions → HP Tool: xóa dấu lỗi cũ làm nặng model**, hoặc nút **Xóa dấu lỗi cũ** trong cửa sổ HP Tool. Lệnh chỉ xóa các nhóm mà HP Tool đã gắn thuộc tính `issue_marker`; không tự dọn component, vật liệu hoặc nhóm của công trình. Có thể Hoàn tác. Plugin không tự lưu đè model; dùng **Save As / Lưu thành** để so sánh file đã dọn với file gốc.

Khi bạn chủ động bật, bản mới vẽ dấu lỗi bằng **SketchUp Overlay** trên SketchUp 2023 trở lên: chỉ hiển thị tạm trong viewport, không tạo entity, vật liệu, tag hoặc thao tác Undo khi đánh dấu. Hiển thị giới hạn 256 vòng và 80 nhãn để tránh quá tải; danh sách lỗi, ID và vị trí trên sơ đồ/mô phỏng vẫn giữ đầy đủ. Đóng cửa sổ, bỏ tích Hiện dấu tạm trong SketchUp hoặc chuyển model sẽ xóa lớp tạm. Với bản SketchUp không có API Overlay, dùng dấu trên sơ đồ và mô phỏng.

## Khởi động nhẹ khi dùng SketchUp bình thường

Bản sửa tách bộ nạp nhỏ khỏi bộ xử lý. Khi SketchUp khởi động hoặc mở `.skp`, HP Tool chỉ đăng ký menu/thanh công cụ. Bộ đọc model, CAM, cài đặt, cửa sổ HTML, worker và observer quản lý tác vụ chỉ nạp sau khi bạn bấm mở HP Tool hoặc lệnh dọn dấu. Không có tác vụ nền của HP Tool chạy khi bạn chưa dùng plugin trong phiên đó.

**Hiện dấu tạm trong SketchUp** mặc định tắt; bật khi cần kiểm tra vị trí lỗi. Dấu trên sơ đồ và mô phỏng vẫn dùng như trước. Đây là cấu hình giảm tải viewport, phù hợp trường hợp máy đơ khi thao tác SketchUp thông thường.

## Tác vụ nền và việc chuyển model

- Xếp lại, ghép khít tấm và tối ưu các tấm chọn dùng tác vụ có nút **Dừng xếp tấm**. Không còn nhánh buộc chạy toàn bộ lượt xếp trong một callback khi cấu hình cũ tắt chạy nền.
- Bộ hẹn giờ chờ worker trong từng khoảng 20 ms, nhường giao diện khoảng 50 ms giữa các lượt. Có kiểm tra hủy và giới hạn thời gian xử lý cho lượt quá dài. Tốc độ thực tế vẫn tùy cấu hình máy và độ phức tạp model.
- Đóng cửa sổ plugin, chuyển/mở model khác, đọc dữ liệu khác hoặc thay dữ liệu đang tính sẽ hủy worker và bộ hẹn giờ cũ. Kết quả muộn không ghi đè công trình mới.
- Callback mở model chỉ hủy trạng thái cũ; không quét model, không tạo dấu và không mở cửa sổ HP Tool tự động.
- Đọc liên kết ưu tiên kiểm tra tấm cha và cặp liên kết đã khai báo trước khi quét toàn bộ các tấm. Mọi ứng viên vẫn phải qua kiểm tra hình học; không tự gán tấm khi kết quả mơ hồ.

## Đã kiểm chứng và giới hạn

Kiểm thử tự động đã xác nhận đánh dấu không tạo hình học, giới hạn lượng vẽ, dừng worker khi đóng/chuyển model, bỏ callback cũ, dọn đúng nhóm sở hữu và giữ thao tác Hoàn tác. Bộ đọc trên dữ liệu model thật cho cùng 143 chi tiết và đầy đủ liên kết như bản gốc; thử xếp 30 chi tiết giữ nguyên vị trí; bộ NC 136 chi tiết/21 tệp có nội dung và trace trùng bản gốc. Giao diện Chromium khởi động, nút Dừng và chuyển model không phát sinh lỗi JavaScript trong kiểm thử.

Chưa chạy trực tiếp trên SketchUp Desktop 2023/2024/2025/2026 hoặc file hiện đang treo trên máy bạn. Nếu file vẫn không mở được, cần đối chiếu chính file `.skp` đó và thông tin thời điểm treo để phân biệt hình học lưu trong file, tài nguyên máy và xung đột extension. Bản sửa không cam kết loại bỏ mọi nguyên nhân ngoài plugin.

