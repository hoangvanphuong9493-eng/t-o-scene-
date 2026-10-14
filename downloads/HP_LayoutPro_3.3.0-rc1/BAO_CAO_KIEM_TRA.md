# Đánh giá HP Layout Pro và bản vẽ E LOAN

Đầu vào: HP_LayoutPro_v3.2.1.rbz và E LOAN_banve.pdf. Mục tiêu: bản vẽ nội thất/tủ trên SketchUp 2023 Windows, PDF để in, CAD để chỉnh sửa.

PDF mẫu có 11 trang A3 ngang (420 × 297 mm), mỗi trang là một ảnh 6720 × 4752 px, tương đương 406,4 dpi. Không có lớp chữ/vector để chọn hoặc sửa riêng trong PDF. Chất lượng ảnh hiện tại đủ để thử in; không cần tăng dpi để xử lý bố cục hoặc DIM chồng nhau.

## Những điểm cần tối ưu trong PDF mẫu

| Vị trí | Quan sát | Điều chỉnh |
|---|---|---|
| Trang 3 | DIM 25 / 42,5 mm và các tuyến ngắn sát nhau; một số dấu gạch chạm chữ. | Nới tuyến DIM và dời chữ của kích thước nhỏ trong Scene gốc. Không tăng cỡ tất cả chữ DIM một cách đồng loạt. |
| Trang 3, 7 | Nhiều view cao/hẹp chia trên cùng trang; tỷ lệ khác nhau và có số lẻ, ví dụ 1:14,2 / 1:14. | Tủ cao: thử A3 dọc với khung tên dưới; 1 view/trang hoặc tối đa 2 view, rồi chọn tỷ lệ quy ước. |
| Trang 9 | View nằm giữa trang, khoảng trắng lớn phía trên/dưới. | Tối ưu theo hình dạng view, không theo lưới đều. Phần chiều ngang giới hạn độ phóng, nên khoảng trắng dọc không tự động cho phép phóng to hơn. Có thể ghép view ngang phù hợp. |
| Trang 10–11 | Một Scene chứa cả cụm trên và dưới, dài khoảng 3412 mm, nhiều tuyến kích thước. | A2 ngang khi cần tăng hình và giữ tỷ lệ quy ước; nếu chỉ in A3, tạo các Scene chi tiết riêng trong SketchUp. |
| Trang 2–4 và các nhóm khác | Các trang của cùng một cấu kiện dùng lại số bản vẽ. | Mỗi trang cần mã riêng hoặc hậu tố trang; bản sửa đã thêm hậu tố. |
| Khung tên | Nhãn nhỏ hơn phần nội dung, ghi chú dài; màu đỏ chiếm nhiều thông tin. | Kiểm tra bản in ở kích thước thật. Chữ thông tin nên khoảng 2,5–3,5 mm; có thể dùng đen cho hồ sơ thi công, giữ màu thương hiệu ở logo. |
| Trang tổng hợp | Diện tích được tính bằng tổng diện tích các mặt gán texture. | Ghi rõ là diện tích bề mặt. Đây chưa phải bảng cắt ván, khối lượng mua vật liệu hay bảng bóc tách có hao hụt. |

Chỉ từ PDF không thể xác nhận các số DIM đúng với hình học của model, đầy đủ khe hở lắp đặt, độ dày ván, phụ kiện, khoan/cắt hoặc yêu cầu sản xuất. DIM của các cánh có thể không cộng bằng kích thước phủ bì do khe hở; cần đối chiếu model, không tự ý sửa số từ PDF.

## Bản cập nhật 3.3.0-rc1

- Thêm A3 dọc cho tủ cao (khung tên dưới) và A2 ngang cho cụm rộng, giữ các template cũ.
- Quick Layout ưu tiên tối đa 2 view/trang; thêm 1 view/trang; mục tiêu mặc định 1:10. Cho chọn tỷ lệ quy ước hoặc khít nhất với tỷ lệ lẻ.
- Bổ sung scale_factor của View.write_image để chữ/DIM, mũi tên và nét vẽ tăng tương ứng độ phân giải; cho điều chỉnh riêng 75–200%, giữ tỷ lệ hình học.
- Giữ ghi chú khi đo nội dung; chặn thiếu Scene, ảnh trắng, lỗi dựng ảnh và cắt nội dung khỏi ô; cảnh báo khi không đạt mục tiêu tỷ lệ hoặc độ nét thực tế bị giảm.
- Ngăn hai tác vụ PDF dùng chung trạng thái; kiểm tra thứ tự/số trang; ghi trang tạm, ghi PDF theo luồng, giảm bộ nhớ canvas. Thay file PDF đích sau khi ghi hoàn tất.
- Khôi phục thêm trạng thái ẩn của hình học lồng nhau, folder tag, style, bóng và mặt cắt; ràng buộc cửa sổ với model; bộ đệm phân biệt model, độ nét và cỡ DIM.
- Giữ dữ liệu dự án khi GUID model đổi; bổ sung ghi dữ liệu đang chờ khi model được lưu.
- Mã trang riêng; bảng tổng hợp lặp lại tiêu đề/cột khi sang trang; tiêu đề view PDF màu đen.
- CAD có lựa chọn DWG/DXF, dùng acad_2013 trong danh sách tùy chọn API; tránh trùng tên và ghi đè file cũ; báo từng Scene xuất lỗi.

## Giới hạn còn lại

CAD hiện dùng Model.export của SketchUp: đây là bộ xuất CAD **3D**, không phải DWG/DXF hình chiếu 2D của từng Scene. Chuyển Scene trước lệnh này không biến nó thành bộ xuất 2D. Bản cập nhật ghi rõ giới hạn này trong giao diện. Để có bản vẽ CAD 2D, hiện cần Export 2D Graphic của SketchUp hoặc xuất từ LayOut; tự động hóa bước đó bằng pipeline LayOut là phần phát triển tiếp theo.

PDF vẫn là ảnh ghép trang, chưa có viewport/vector hay chữ chỉnh sửa được. Lệnh LayOut chỉ mở model đã lưu, chưa tạo hồ sơ .layout có khung tên, Scene và tỷ lệ tự động. File template .layout chưa được đọc vào PDF.

Plugin bố trí/xuất không tự sửa va chạm giữa những DIM đã tạo trong Scene. Cần cải thiện thuật toán đặt DIM ở plugin tạo Scene hoặc chỉnh Scene gốc. Việc chọn tỷ lệ và tăng độ nét không thay thế việc kiểm tra cỡ chữ thật hoặc tính đúng của số đo.

## Cài và thử trên SketchUp 2023 Windows

1. Sao lưu model .skp và giữ RBZ 3.2.1 để có thể quay lại. Cài HP_LayoutPro_v3.3.0-rc1.rbz bằng Extension Manager, rồi khởi động lại SketchUp.
2. Dùng bản sao model. Thoát chế độ sửa group/component trước khi xem trước/xuất.
3. Chọn A3 Dọc - tủ cao hoặc A2 Ngang - cụm rộng. Quick Layout → View lớn - tối đa 2 ô hoặc Một view / trang → mục tiêu 1:10. Nếu một view không đạt, dùng khổ lớn hơn hoặc Scene chi tiết, không cắt DIM để ép vừa.
4. Bắt đầu với chữ/DIM 100% và nét Mảnh. PDF mẫu đang có DIM tương đối to; chỉ tăng 125% sau khi kiểm tra các tuyến nhỏ không chồng lên nhau.
5. Xuất PDF 400 dpi. In đúng khổ giấy, 100% / Actual size, không Fit to page. In A2 xuống A3 sẽ làm thay đổi tỷ lệ ghi trên bản vẽ.
6. Kiểm tra một đoạn 1000 mm ở tỷ lệ 1:10: chiều dài trên giấy phải gần 100 mm. Kiểm tra chữ DIM bằng thước trên bản in; 2,5–3,5 mm là mục tiêu thực dụng cho hồ sơ này, không phải chứng nhận theo một tiêu chuẩn cụ thể.
7. Kiểm tra ít nhất các Scene Top, Front, Side, Section và 3D; đối chiếu số đo với model. Kiểm tra DIM nhỏ, chú thích xa hình, khung tên và mã trang.
8. Thử hủy PDF, xuất lại, bấm xuất hai lần và tên Scene như A/B với A:B. Kiểm tra camera, style, tag, folder, đối tượng ẩn và mặt cắt trước/sau; Undo và đổi model khi cửa sổ còn mở.
9. Nếu dùng CAD 3D, mở DWG/DXF trong phần mềm đích và kiểm tra đơn vị, hình học, DIM, chữ. Bộ kiểm tra Linux chưa chạy bộ xuất CAD thực của SketchUp.

## Bằng chứng kiểm tra

- Kiểm tra toàn vẹn RBZ gốc và gói mới; giữ nguyên hai tệp người dùng gửi và kho t-o-scene-.
- 11 kiểm tra JavaScript đạt: tỷ lệ, không mất Scene, số ô, A3 dọc cho tủ cao, kiểm tra cắt hình, bảng qua trang, mã trang, bộ đệm và renderer/nén ảnh thực.
- 14 kiểm tra Ruby đạt: kiểm tra đầu vào, tên/lỗi CAD, giữ trạng thái khi gặp lỗi, toán tỷ lệ/scale_factor, lỗi chụp ảnh, lưu dữ liệu, ghi PDF, bảo vệ file đích, xuất đồng thời, hủy, thứ tự/số trang và nối dữ liệu từ JavaScript đến PDF.
- PDF tạo trong kiểm tra được đọc bằng PyMuPDF: đúng số trang, đúng khổ A3, tiêu đề tiếng Việt và ảnh Flate giải nén được.
- Cú pháp 10 tệp Ruby, 3 tệp JavaScript và 2 script HTML đạt.

Kiểm tra chạy trên Linux với Ruby 3.3 và Node. Các thao tác SketchUp dùng mô hình giả trong kiểm tra; bản RC chưa được chạy trong SketchUp 2023 Windows (Ruby 2.7), chưa kiểm tra GPU, CEF HtmlDialog, CAD thực hoặc bản in. Không gọi bản RC là đã nghiệm thu hoặc bảo đảm tuân thủ tiêu chuẩn bản vẽ.

Nguồn đối chiếu API: SketchUp/Model#export và SketchUp/View#write_image; danh sách Exporter Options của Trimble trong https://github.com/SketchUp/ruby-api-stubs/blob/main/pages/exporter_options.md. Tham số scale_factor có từ SketchUp 2019.2; danh sách CAD trong tài liệu là 3D Autocad (DWG/DXF).
