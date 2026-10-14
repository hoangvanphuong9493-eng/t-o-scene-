# HP Layout Pro 3.4.0-rc1 — Khít giấy và nhiều phương án chia Scene

Bản thử nghiệm sửa lỗi được phản ánh sau 3.3.0-rc1 trên SketchUp 2023 Windows.

## Đã xác định

Ảnh người dùng cho thấy hình + DIM còn nhỏ giữa một ô lớn và các phương án Quick Layout gần như trùng nhau. Dữ liệu bố cục đọc từ TES.skp xác nhận 8 trang BẾP, mỗi trang 1 Scene: bốn trang 1:20, hai trang 1:25, hai trang 1:50; chế độ tỷ lệ đang là `standard`.

Lỗi tái hiện được trong phép đo: khi nền giấy trắng có cả vùng trong suốt và vùng đục, bản cũ tính nền đục thành nội dung. Nền trời/đất và các thành phần hiển thị phụ cũng có thể làm hộp bao ảnh lớn. Điều kiện phạt khi nhiều view không đạt mục tiêu 1:10 khiến các chiến lược chia trang cùng rơi về một Scene/trang. Làm tròn lên tỷ lệ quy ước tiếp tục giảm độ lớn hình.

## Thay đổi

- Khi đo/dựng ảnh, tạm dùng nền trắng, tắt nền đất/chân trời, sương, bóng, watermark, trục, mặt phẳng cắt hiển thị và tên view. Hình cắt và màu/vật liệu của mô hình được giữ. Khôi phục các giá trị hiển thị đã lưu sau mỗi lần chụp, kể cả khi chụp thất bại; không cập nhật Scene bằng lệnh Page.update.
- Phép đo loại nền trắng dù vùng nền còn đục; giữ hộp bao hình + DIM + ghi chú. Không tự bỏ ghi chú ở xa.
- Mặc định Khít giấy, tính tỷ lệ riêng cho mỗi ô; vẫn có lựa chọn tỷ lệ quy ước. Dữ liệu dự án cũ được chuyển mặc định sang Khít giấy một lần, rồi giữ lựa chọn mới của người dùng.
- Thêm 8 chiến lược: Tự xếp theo hình dạng; Hai cột; Hai hàng; Một lớn + hai nhỏ; Bốn ô; Sáu ô; Top / Front / Side; Một Scene khít trang.
- Phương án theo số ô giữ đúng chính sách chia trang. Mục tiêu tỷ lệ dùng để tham khảo, không âm thầm ép mọi phương án về một Scene/trang. Xếp theo hình dạng cân đối số trang và độ lớn tương đối của view.
- Thẻ phương án có ảnh xem trước Scene và tỷ lệ. Ẩn các phương án có bố cục thực sự trùng nhau; không tạo nhiều tên cho cùng một cách chia.
- Tính lại phép khít cho các trang tự động cũ khi được xem. Trang cũ có chú thích vẽ tay được giữ để người dùng chủ động bấm Khít và kiểm tra vị trí chú thích.

## Cách dùng

1. Giữ RBZ cũ và sao lưu model. Cài `HP_LayoutPro_v3.4.0-rc1.rbz` qua Extension Manager, rồi khởi động lại SketchUp.
2. Mở TES.skp hoặc bản sao model; thoát chế độ sửa group/component.
3. Bấm Cập nhật. Trong Quick Layout chọn **Khít giấy — hình lớn nhất trong ô**.
4. So sánh các thẻ có ảnh: Hai cột thường phù hợp view cao; Hai hàng phù hợp view dài/thấp; Một lớn + hai nhỏ dành cho view chính và view phụ; Bốn/Sáu ô giảm số trang; Một Scene khít trang ưu tiên hình lớn.
5. Chọn phương án rồi bấm Tạo trang. Thao tác này thay các trang của cấu kiện đang chọn như luồng Quick Layout cũ. Nếu giữ các trang cũ, bấm Khít trang hoặc Khít tất cả để tính lại; kiểm tra lại chú thích đã vẽ tay.
6. Khít giấy phóng đều, không kéo méo hình để phủ kín hai chiều. Một view dài/hẹp có thể còn khoảng trắng ở chiều kia. Hình + DIM chừa khoảng an toàn 3 mm quanh ô và không chiếm vùng khung tên.
7. Muốn tỷ lệ như 1:5 / 1:10 / 1:20, chọn Mức quy ước; việc làm tròn lên có thể để lại khoảng trắng. Nếu cần hình lớn hơn mà giữ mức quy ước, dùng khổ giấy lớn hơn hoặc tạo Scene chi tiết.
8. Xuất PDF, kiểm tra DIM không chồng/cắt; in đúng khổ giấy ở 100% / Actual size.

## Kiểm tra đã thực hiện

- 11 kiểm tra JavaScript nền tảng và 16 kiểm tra Ruby đạt, gồm bảo vệ xuất PDF/CAD và các kiểm tra mới về nền giấy, khôi phục trạng thái, chuyển dữ liệu bố cục TES.
- Ca hồi quy nền đục thất bại trên bản cũ, đạt trên bản mới: vùng hình chỉ khoảng 25% chiều rộng ảnh không còn bị đo thành gần 100% ảnh.
- Ca hồi quy 8 Scene hỗn hợp: có các phương án 2/3/4/8 trang với bố cục khác nhau, không mất hoặc trùng Scene; một Scene/trang khít chiều giới hạn của ô.
- Kiểm tra giao diện HTML/JS bằng Chromium thật với tên/cấu hình bố cục đọc từ TES.skp và ảnh Scene mô phỏng: 8 thẻ bố cục khác nhau, mỗi thẻ hiển thị đủ 8 ảnh Scene; chọn/tạo trang và dựng ảnh hoàn tất, không có lỗi JavaScript. View mặt cắt trong ca mô phỏng đạt gần 100% chiều hữu dụng giới hạn.
- Kiểm tra cú pháp Ruby/JS và đọc lại PDF thử bằng PyMuPDF.

## Giới hạn nghiệm thu

Đã đọc dữ liệu bố cục, tên Scene và phiên bản lưu 23.0.419 trong TES.skp; chưa mở/dựng hình học của file đó bằng SketchUp trên Linux. Các phép gọi API SketchUp trong kiểm tra dùng mô hình giả, và ảnh kiểm tra trình duyệt là ảnh mô phỏng. Cần thử bản RC trong SketchUp 2023 Windows để xác nhận kết quả thực của model, GPU, chữ DIM và trạng thái model sau xuất. Không coi đây là kết quả dựng thực của TES.skp hoặc một bản phát hành đã nghiệm thu.

PDF vẫn là ảnh; CAD vẫn dùng bộ xuất DWG/DXF 3D; bản này chưa bổ sung xuất hình chiếu CAD 2D hay tự tạo hồ sơ LayOut. Mã đo/bố trí không sửa số DIM hoặc tách các DIM chồng nhau đã có trong Scene.
