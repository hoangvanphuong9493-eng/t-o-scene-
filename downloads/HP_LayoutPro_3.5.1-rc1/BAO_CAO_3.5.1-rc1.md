# Kiểm tra HP Layout Pro 3.5.1-rc1

Ngày kiểm tra: 15/10/2026. Môi trường Linux, Node/Chromium và API SketchUp mô phỏng. Chưa chạy trực tiếp SketchUp 2023 Windows.

## Kết quả sửa bố cục

Thay bố cục khung rời của 3.5.0 bằng các cột phủ chiều cao hoặc hàng phủ chiều rộng vùng bản vẽ. Các cụm có cùng số ô dùng chung đường chia. Chia phần dư cân đều khi đủ chỗ, giữ kích thước tối thiểu cho hình + DIM và tiêu đề. Viền ô bật mặc định, kể cả khi dự án cũ đang tắt viền toàn cục. Tọa độ khung dùng chung giữa giao diện và PDF.

Đối chiếu ảnh PDF mô phỏng: đã tạo bố cục một cột hai ô cạnh hai cột một ô cao; các mép ngoài thẳng và các ô nằm kín vùng vẽ. Không xoay/kéo méo hình, không bỏ Scene để tạo đối xứng.

## Chức năng ghép cùng trang

Có nút riêng để chọn cả cấu kiện hoặc Scene lẻ từ nhiều nhóm. Có tìm kiếm, chọn một phần, lấy các Scene của trang đang mở, đặt tên, xem trước tỷ lệ. Tạo thêm đúng một trang với đủ Scene đã chọn; không thay các trang/chú thích đang có. Tiêu đề có tên cấu kiện khi ghép nhiều nhóm.

Tối đa 24 Scene trên một trang. Không đủ chỗ cho khung/tiêu đề thì báo lỗi và giữ nút tạo ở trạng thái chờ. Khi hình/DIM có thể nhỏ thì hiển thị nhắc trước khi tạo. Không tự tách trang trong chế độ ghép cố định này. Đây là lựa chọn nhóm Scene/cấu kiện mà plugin đang liệt kê, không tự tạo Scene cho vật thể chưa có Scene.

## Các kiểm tra đạt

- **15 nhóm kiểm tra bộ xếp**: mép khung không rời rạc, không chồng ô, khoảng cách theo Template, hình + DIM lọt ô, căn Top/Front/Side, phóng chi tiết, ảnh phối cảnh, A3 ngang/dọc/A2 và khung tên bên phải, tỷ lệ linh hoạt/quy ước, giữ Scene/lọc/thứ tự, lưu và Khít không trôi tỷ lệ.
- Chọn Scene từ nhiều cấu kiện → đúng một trang; loại trùng lựa chọn; tiêu đề phân biệt nhóm; không thay dự án khi mới xem phương án. 16 Scene trên một trang, 24 Scene trên A2, nhóm lớn 64 Scene, dữ liệu đo lỗi và giới hạn lựa chọn đều được kiểm tra.
- **13 kiểm tra JS lõi và hồi quy bố cục** đạt. Bố cục mới vẫn tận dụng giấy tốt hơn lưới bằng nhau trong các bộ khung đo cao/hẹp và dài/thấp.
- **Giao diện Chromium**: Quick Layout có ảnh/khung, đổi ưu tiên tính lại phương án, tạo trang, hoán đổi, bật/tắt viền ở trang có cấu hình riêng. Hộp Ghép cùng trang đạt chọn cả nhóm/chọn lẻ, trạng thái một phần, tìm kiếm giữ lựa chọn, xem trước, tạo thêm trang và giữ nội dung trang cũ, bỏ phương án cũ khi thay lựa chọn/Cập nhật, Hủy/Escape. Không có lỗi JavaScript.
- **PDF bố cục mới và trang ghép**: đi qua render.html thật của plugin, 14 lượt view trên 4 trang được đối chiếu chiều cao ảnh theo tỷ lệ giấy, sai số trong ngưỡng kiểm tra 1.25 mm ở 4 px/mm. Đây là kiểm tra mô phỏng luồng xuất, không phải sai số máy in hay nghiệm thu SketchUp thực.
- File minh họa phát hành gồm 2 trang A3 được ghi bằng PdfWriter của plugin và đọc lại đúng khổ/số trang. Trang 1 là 5 view tủ cao; trang 2 ghép 4 Scene từ 2 nhóm, với khung một cột chia hai ô cạnh hai ô cao. Dữ liệu tự tạo, không chứa ảnh/model khách hàng.
- **Hồi quy xuất trang cũ**: 5 trang gồm bảng tổng hợp, chú thích và ảnh dùng chung giữ toàn bộ điểm ảnh như bản đối chiếu. Ảnh dùng chung chỉ giải phóng sau lượt dùng cuối.
- **18 kiểm tra Ruby lõi + 7 hàng đợi** đạt. Mã Ruby dựng Scene/ảnh xem trước/ghi PDF/xuất CAD không đổi so với 3.5.0; chỉ cập nhật phiên bản bộ nạp.
- **Hồi quy tải ảnh** đạt: 6 ảnh về không dựng lại cả trang; giữ trường đang gõ, dùng cache khi quay lại, lướt nhanh chỉ dựng trang cuối và bỏ kết quả cũ sau Cập nhật.

Không dùng mô phỏng để cam kết cỡ chữ DIM thực, hiệu năng GPU hay tốc độ xuất trên Windows. Cần xem PDF ở kích thước in thực; tỷ lệ view không tự bảo đảm phông DIM 2.5–3.5 mm.

## Áp dụng

Cài RBZ và khởi động lại SketchUp. Dùng Quick Layout → Khung cân đối để tạo lại bố cục có khung; thao tác này thay các trang/chú thích trong nhóm được chọn, vì vậy lưu bản SKP riêng nếu cần giữ phương án cũ. Dùng Ghép cùng trang để tạo thêm trang từ các Scene tự chọn; chức năng này giữ nguyên trang cũ. Bản cập nhật không tự chuyển bố cục của các trang đã lưu.
