# HP Layout Pro 3.5.1-rc1 — Khung cân đối và ghép Scene cùng trang

Bản này sửa trình bày của 3.5.0: các ô được xếp thành hàng/cột có mép chung và có viền mặc định, thay cho các khung rời. Thêm chọn nhiều cấu kiện hoặc Scene từ nhiều nhóm để đưa vào đúng một trang mới.

## Cài trên SketchUp 2023 Windows

1. Window → Extension Manager → Install Extension → chọn **HP_LayoutPro_v3.5.1-rc1.rbz**.
2. Đóng và mở lại SketchUp. Góc cửa sổ plugin cần hiện **v3.5.1-rc1**.

## Xếp tự động có khung

Mở **Quick Layout → Tự sắp theo nội dung → Khung cân đối → Tạo trang**.

- Các cột chung mép trên/dưới; các hàng chung mép trái/phải. Những cụm có cùng số ô dùng chung đường chia. Có thể tạo bố cục một cột hai ô cạnh các cột một ô cao như hình mẫu.
- Ưu tiên chia đều phần dư, điều chỉnh khi cần đủ chỗ cho hình + DIM. Không ép mọi ô bằng nhau, không kéo méo/xoay hình để lấp giấy.
- Chừa 3 mm quanh khung đo hình + DIM, 7 mm cho tiêu đề. Khoảng cách ô theo Template.
- Có các phương án ưu tiên hình/DIM lớn, nhóm hình chiếu, gọn số tờ và một Scene/tờ. Mỗi hình chiếu ghi tỷ lệ riêng; khung bật mặc định, có thể đổi Viền ô theo trang.
- Chọn tỷ lệ linh hoạt để tận dụng giấy, hoặc mức quy ước khi cần in theo tỷ lệ chuẩn. Hình dài/hẹp vẫn có khoảng trắng trong ô vì giữ đúng hình dạng.

Bản này không tự thay bố cục của trang đã có. **Tạo trang trong Quick Layout thay các trang và chú thích của nhóm được chọn**; lưu bản SKP riêng nếu cần giữ phương án cũ. Khi đổi khổ giấy/khung tên và muốn sắp vị trí mới, mở Quick Layout lại.

## Chọn cấu kiện/Scene để ghép vào đúng một trang

1. Bấm **▦ Ghép cùng trang** ở cột trái.
2. Tích tên cấu kiện để chọn tất cả Scene của nó; hoặc tích từng Scene từ nhiều cấu kiện. Có tìm kiếm, Bỏ chọn hết và Scene của trang đang mở.
3. Đặt tên trang, bấm **Xem bố cục** để xem khung, hình và tỷ lệ.
4. Bấm **Tạo trang ghép**. Plugin tạo thêm đúng một trang với đủ các Scene đã chọn; giữ các trang đang có.

Khi ghép nhiều cấu kiện, tiêu đề view có thêm tên cấu kiện để phân biệt. Thay lựa chọn hoặc Cập nhật model sẽ bỏ phương án xem trước cũ và yêu cầu xem lại trước khi tạo. Tìm kiếm giữ nguyên các Scene đã tích.

Giới hạn 24 Scene/trang. Giấy nhỏ hoặc tiêu đề dài có thể không đủ chỗ; plugin báo để giảm Scene hoặc tăng khổ giấy, không tự bỏ Scene. Chọn nhiều Scene trên một tờ có thể làm hình/DIM nhỏ: xem tỷ lệ được báo trước, giảm số view hoặc dùng giấy lớn hơn. Ngưỡng cảnh báo độ lớn không đo trực tiếp cỡ phông DIM. Cấu kiện ở đây là các nhóm Scene được plugin liệt kê; chức năng không tự tạo Scene mới từ vật thể chưa có Scene.

## Xuất và kiểm tra

Giữ mã Ruby dựng Scene, xuất PDF/CAD và các sửa lag của 3.4.2/3.5.0. Các khung dùng cùng tọa độ trong xem trước và PDF. In PDF ở **100% / Actual size**. PDF vẫn là ảnh, CAD vẫn theo luồng CAD 3D của bản trước; chưa thêm DWG 2D hay tự sinh DIM.

Đã kiểm tra bằng Linux/Chromium, mô phỏng API và bộ xuất thật của plugin: khung thẳng/không chồng, hình + DIM lọt ô, khổ giấy/tỷ lệ, chọn nhiều nhóm và tạo một trang, giữ trang/chú thích cũ khi ghép, đổi lựa chọn/Hủy/Cập nhật, xuất PDF đúng A3 và hồi quy tải ảnh. PDF minh họa gồm hai trang từ dữ liệu tạo trong bài kiểm tra, không dùng model hay ảnh của khách hàng.

Chưa chạy trực tiếp bản này trong SketchUp 2023 Windows ở môi trường kiểm tra.
