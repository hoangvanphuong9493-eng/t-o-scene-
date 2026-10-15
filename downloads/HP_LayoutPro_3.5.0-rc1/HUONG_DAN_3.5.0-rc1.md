# HP Layout Pro 3.5.0-rc1 — Bố cục theo nội dung Scene

Bản này thay bộ tự sắp Scene để giảm khoảng trắng do chia ô bằng nhau, giữ view đủ lớn và trình bày gọn hơn. Khung xếp lấy theo phần hình + DIM đã đo của từng Scene. Không xoay hay kéo méo hình để lấp giấy.

## Cách dùng trên SketchUp 2023 Windows

1. Window → Extension Manager → Install Extension → chọn **HP_LayoutPro_v3.5.0-rc1.rbz**.
2. Đóng và mở lại SketchUp; góc cửa sổ plugin phải hiện **v3.5.0-rc1**.
3. Chọn khổ giấy, khung tên rồi mở **Quick Layout**. Bật **Tự sắp theo nội dung**.
4. Bắt đầu với **Bố cục kỹ thuật**, **Ưu tiên độ lớn 1:10**, **Khít hình (tỷ lệ linh hoạt)**. So sánh ảnh xem trước rồi bấm **Tạo trang**.
5. Nếu cần tỷ lệ quy ước để in, đổi sang **Tỷ lệ quy ước** và xem lại phương án. In PDF ở **100% / Actual size**.

Trang đã có không tự đổi bố cục khi cài bản này. **Tạo trang thay các trang thuộc nhóm đang chọn**, gồm chú thích vẽ tay trên những trang bị thay; lưu một bản SKP riêng trước nếu muốn giữ phương án cũ. Các nhóm ngoài phạm vi chọn giữ nguyên. Khi đổi khổ giấy/khung tên và muốn xếp lại vị trí, chạy Quick Layout lại.

## Các phương án

| Phương án | Mục đích |
| --- | --- |
| Bố cục kỹ thuật | Xếp khung view theo hình + DIM, cân bằng độ lớn và số tờ; tối đa 5 view khi còn đủ lớn. |
| Ưu tiên hình / DIM lớn | Tối đa 2 view/tờ; ưu tiên giữ hình lớn, chấp nhận thêm tờ. |
| Nhóm hình chiếu | Ưu tiên Top trên Front và view bên ở cạnh khi đủ chỗ; giữ tỷ lệ các hình chiếu chính trên cùng tờ. |
| Gọn số tờ | Tìm chỗ trống để ghép, tối đa 6 view/tờ; có giới hạn thu nhỏ. |
| Một Scene / tờ | Mỗi Scene dùng toàn vùng vẽ, dành cho hình/DIM cần xem lớn. |

- Ô view có chiều rộng/cao riêng, không ép bằng nhau. Chừa khoảng an toàn 3 mm quanh khung đo, 7 mm cho tiêu đề; khoảng cách giữa view lấy theo Template.
- View nhỏ thuộc nhóm mặt cắt/chi tiết có thể được phóng lớn riêng; phối cảnh được dành diện tích vừa phải. Mỗi hình chiếu ghi tỷ lệ của chính nó.
- Nhận dạng vai trò theo đuôi tên Scene: Top, Front, Left/Right/Back, Plan…, Sec…, 3D/Iso/Persp. Tên khác vẫn xếp theo kích thước. Có thể bật giữ thứ tự Scene nếu muốn theo thứ tự trong model.
- Mặc định bỏ viền ô ở các trang mới để bản in gọn hơn; bật lại **Viền ô** cho trang đó nếu cần. Khung tên vẫn theo Template.
- Chỉ giữ các phương án thực sự khác nhau. Chỉ số “Bao hình” là diện tích hộp bao hình + DIM so với vùng vẽ, không phải diện tích nét/màu thực.
- Mục ưu tiên độ lớn tác động đến cách ghép; không bảo đảm mọi view đều đạt 1:10. Nếu hình quá lớn, dùng phương án ít view hơn hoặc giấy lớn hơn.
- View dài/hẹp hay hình chữ L vẫn có khoảng trắng bên trong hộp bao. Không cắt DIM hay kéo giãn hình để lấp chỗ đó.

## Hiệu năng và xuất bản vẽ

Giữ sửa lag của 3.4.2: dùng ảnh đã đo ngay, cập nhật riêng ảnh trong ô, cache ảnh đã giải mã, ưu tiên trang đang xem và bỏ yêu cầu cũ. Các phương án được tính lần lượt, trả quyền xử lý cho giao diện giữa các phương án. Giữ nguyên Ruby dựng Scene, xuất CAD, chất lượng và bộ ghi PDF.

PDF hiện là ảnh; DWG/DXF vẫn dùng luồng CAD của bản trước. Chưa bổ sung bản vẽ vector 2D hay tự tạo DIM mới. Cỡ chữ DIM phụ thuộc Scene và mục cỡ chữ/DIM khi xuất; cần xem PDF ở kích thước in thực, thường kiểm tra chữ khoảng 2.5–3.5 mm tùy tiêu chuẩn áp dụng. Chọn tỷ lệ hình phù hợp không tự bảo đảm cỡ chữ này.

## Kiểm tra trước khi phát hành

Đã kiểm tra bằng Linux/Chromium và mô phỏng API: khoảng cách/không chồng view, không cắt khung hình + DIM, khổ ngang/dọc/A2 và khung tên bên phải, tỷ lệ linh hoạt/quy ước, thứ tự/lọc Scene, chi tiết phóng lớn, lưu/tính lại tỷ lệ, hoán đổi view, không đổi trang cũ khi xem phương án, giao diện và hồi quy tải ảnh. Luồng xuất bố cục cũ cho cùng điểm ảnh; bố cục mới qua bộ dựng PDF thật của plugin được đối chiếu kích thước hình trên giấy.

Chưa chạy trực tiếp bản này trong SketchUp 2023 Windows tại môi trường kiểm tra. File minh họa là dữ liệu mô phỏng, không phải kết quả dựng lại TES.skp.
