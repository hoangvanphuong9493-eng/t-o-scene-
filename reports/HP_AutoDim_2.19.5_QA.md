# HP Auto Dim 2.19.5 — sửa vòng đời liên kết và kiểm tra hồi quy

## Lỗi đã tái hiện

File SKP mới có một bộ Cánh + tim lỗ còn bản ghi nguồn, và một nhóm DIM cắt
vẫn hiện nhưng không còn bản ghi trong `HP_AutoDim/sets`. Nhóm DIM cắt có độ
dịch 205 mm. Đường xử lý cũ coi mọi transformation khác identity là sửa tay,
rồi loại cả nhóm đã xóa lẫn nhóm sửa tay khỏi danh sách theo dõi. Bài kiểm tra
mới chạy trên 2.19.4 thất bại ở `moving obj deleted its tracking record`;
cùng bài kiểm tra chạy đạt trên 2.19.5 cho cả bốn loại DIM.

Một nguyên nhân độc lập: các công cụ điểm lưu cờ đang tương tác đến khi
deactivate. Esc/Enter chỉ reset công cụ về bước đầu, nên việc sửa tham số từ
công cụ khác/hộp thoại có thể bị chặn cập nhật mãi khi công cụ DIM còn được
chọn. Bản sửa kiểm tra pha thực tế: bước đầu được cập nhật; đang chọn điểm,
đang đặt DIM hoặc đang nối chuỗi vẫn được bảo vệ.

## Phạm vi thay đổi

- `main.rb`: giữ liên kết của nhóm chỉnh sửa; cho phép dịch chuyển thuần túy;
  giữ độ dịch khi thay nhóm DIM; đăng ký lệnh khôi phục chủ động.
- `interaction.rb`: phân biệt công cụ đang chờ điểm đầu với đang đặt DIM.
- `recovery.rb`: lệnh khôi phục riêng cho DIM cắt mất bản ghi ở ngoài cùng
  model. Chỉ dùng nguồn rõ ràng, tấm biên duy nhất, scene và phương đo hợp lệ.
  Dựng phạm vi toàn bộ tủ bằng vertex/cạnh thật và cài đặt hiện tại. Không đoán
  lại ý định đường cắt cục bộ đã mất, không tự chạy khi mở file.
- Loader và tài liệu: số phiên bản 2.19.5.

Đã đối chiếu từng byte với 2.19.4: anchors, live_geometry, rendering,
scheduler, tracking, tagging, verification, spacing và icons giữ nguyên.
Các hàm tính DIM, định dạng số, bắt điểm, chân DIM và đặt hàng trong main.rb
giữ nguyên. Không sửa/xóa DIM tay hoặc tag của nguồn. Nhóm Scale/xoay hoặc
có nội dung sửa tay được giữ lại cùng bản ghi; chưa tự động ghi đè nhóm đó.

## Kết quả kiểm tra ngoài SketchUp

Tất cả các bộ dưới đây đạt trên **Ruby 2.7.8 và Ruby 3.2.6**, dùng API thay thế.

| Bộ kiểm tra | Kết quả và phạm vi |
|---|---|
| Vòng đời tự cập nhật mới | 71 đối chiếu; gọi ModelObserver, timer, run_background và refresh thật của plugin. Dịch bốn nhóm; sửa rộng tủ; thêm/bớt đợt, hồi, tim lỗ; nhãn số tròn sau cập nhật; pha công cụ/Esc; Save; Undo/Redo; giữ liên kết khi nhóm Scale; khôi phục; từ chối 8 loại dữ liệu không an toàn; giữ DIM và bản ghi khi quá ngân sách thời gian; cập nhật đầy đủ để thử lại. |
| Hình học/render/hồi quy | 62 đối chiếu cho Đối tượng, Liên tiếp, Cắt, Cánh + tim lỗ; thay vertex/part/PID, Scale không đều, di chuyển/xoay nguồn, thêm/bớt cánh và tim lỗ, nguồn rỗng rồi thêm lại, lỗi native giả lập và thử lại, DIM tay, nhóm lồng, giới hạn vùng quét, scene và cache xem trước. |
| Định dạng/đặt hàng | 26 đối chiếu; bỏ .0 số tròn, đổi sang số lẻ sau cập nhật, đơn vị, nhóm lồng; hai mặt lệch chiều sâu; hàng 150/270/390 mm với bước 120 mm; kéo tự do, góc nhìn và độ dịch lưu lại. |
| Khoảng cách hàng | Hồi quy phía đặt, giao khoảng đo, hướng đảo, xem trước, chiều dài chân DIM, VCB riêng, lọc DIM tay/ẩn/scene khác và transformation của nhóm. |
| Tags/scene | Thư mục HP DIM, 8 tag của 2 scene x 4 loại, hiển thị khi chuyển scene, dùng lại tag, scene mới, chuyển cấu trúc cũ chủ động, không đổi tag nguồn/DIM tay. |
| Model mới, dữ liệu trích chỉ đọc | Khôi phục nhóm cắt mất bản ghi, giữ độ dịch 205 mm; 17 đối chiếu với tọa độ mặt tấm: đổi rộng/cao tủ, di chuyển/thêm/xóa đợt qua observer/timer. Thêm bộ Đối tượng và Liên tiếp trong bộ nhớ để kiểm tra đủ bốn loại. Kiểm tra cả đường ngang phía trước có cánh gần và cạnh sau; các cạnh nằm trong phạm vi/dung sai thực tế được xét. Tất cả bộ DIM khớp kiểm tra lại sau cập nhật. |
| Model trước, dữ liệu trích chỉ đọc | Kiểm tra bốn loại; sửa nguồn theo mặt thật; đợt/hồi/tim lỗ thêm, di chuyển, xóa; DIM lồng không làm tăng kích thước nguồn; phát hiện chữ DIM bị sửa sai và bảo vệ DIM tay. |

Các dữ liệu trích từ model chỉ dùng trong môi trường kiểm tra riêng, không
đưa vào GitHub hay RBZ. Không ghi lại hoặc sửa nhị phân SKP của người dùng.
Kiểm tra hàng sau không thay thế xác nhận bằng mắt trong giao diện SketchUp.

Lệnh chạy các bộ kiểm tra công khai:

```sh
ruby tests/hp_autodim_2195/lifecycle_test.rb
ruby tests/hp_autodim_2194/regression_test.rb src/hp_auto_dim_2.19.5/hp_auto_dim
ruby tests/hp_autodim_2194/presentation_test.rb src/hp_auto_dim_2.19.5/hp_auto_dim
ruby tests/hp_autodim_2195/spacing_regression_test.rb
HP_AUTODIM_TEST_VERSION=2.19.5 ruby tests/hp_autodim_219/tagging_test.rb
```

Đã kiểm tra cú pháp toàn bộ Ruby với 2.7/3.2, cấu trúc và CRC của ZIP/RBZ,
phiên bản loader, checksum và nội dung gói so với thư mục nguồn.

## Áp dụng cho file đã mất liên kết

Sau khi cài và khởi động lại SketchUp: mở scene đang có DIM, nhìn chính diện,
chọn nhóm DIM cắt, chuột phải **HP: Khôi phục tự cập nhật DIM cắt (toàn bộ tủ)**.
File mẫu có một tủ nguồn nên có thể xác định duy nhất. Nếu nhiều tủ, chọn thêm
đúng tủ và dùng lệnh **Khôi phục tự cập nhật DIM cắt đã chọn (toàn bộ tủ)**
trong menu HP Auto Dim. Đường cắt cục bộ cần tạo lại riêng; không thể khôi
phục chính xác ý định đó từ bản ghi đã bị xóa.

## Chưa kiểm thử trực tiếp

Môi trường này không có SketchUp thật. Chưa xác nhận cài RBZ và thao tác chuột,
native observer/timer, Undo/Redo, lưu/mở lại và việc OneClick/Fuji tái tạo tủ
trong SketchUp 2023+ thực tế. Các kiểm tra thay thế chứng minh những trường
hợp đã liệt kê; không đủ để cam kết mọi model và mọi tương tác đều không lỗi.
