# HP Auto Dim 2.19.4 — bản vá định dạng và khoảng cách hàng

Nền: 2.19.3-rc1, đã được người dùng xác nhận cập nhật hình học hoạt động ổn.
Chỉ thay `set_clean_text` trong main.rb và xử lý đặt hàng trong spacing.rb;
loader đổi số phiên bản. Đã so sánh từng byte: anchors, live_geometry,
interaction, rendering, scheduler, tracking, tagging, verification và icons
không thay đổi; phần main.rb ngoài hàm định dạng không thay đổi.

## Hai thay đổi

- Số tròn của nhóm HP ngoài cùng bỏ `.0` theo số đã định dạng bởi Units;
  số lẻ và đơn vị giữ nguyên. Khi đo lại chuyển sang số lẻ, bỏ chữ số tròn cũ
  để native hiện giá trị mới. Nhóm lồng/chung definition giữ chữ native để
  tránh làm sai số khi group cha được Scale; không sửa cấu trúc nguồn.
- So hàng DIM trong cùng hướng nhìn thay vì bắt buộc cùng chiều sâu vật lý.
  Trường hợp mặt cánh lùi/nhô so với khung vẫn được xét. Kéo tự do giữ
  khoảng cách tối thiểu theo cài đặt, không ép khi kéo xa hơn; chiều dài nhập
  riêng bằng VCB giữ hành vi cũ. Độ dịch được lưu và dùng lại khi cập nhật.

## Đã kiểm tra

Chạy đạt trên cả Ruby 2.7.8 và 3.2.6:

- 26 đối chiếu riêng: số tròn/lẻ, thay số sau cập nhật, đơn vị, nhóm lồng,
  hai mặt lệch 17,5mm, các hàng 150/270/390mm với bước 120mm, kéo tự do,
  góc nhìn phối cảnh, phía đối diện, hàng ẩn/scene khác, độ dịch sau dựng lại.
- 62 đối chiếu hồi quy bốn loại DIM; chỉ điều chỉnh kỳ vọng nhãn từ native
  hoàn toàn sang cho phép số tròn đã làm gọn đúng giá trị đo hiện tại.
- Bộ hồi quy khoảng cách hàng trước đó; chỉ thay kỳ vọng kéo tự do theo yêu cầu mới.
- Bộ Tags/scene và đối chiếu hình học đọc từ model mẫu đã cung cấp.
- Cú pháp Ruby 2.7 và ZIP RBZ.

```sh
ruby tests/hp_autodim_2194/presentation_test.rb
ruby tests/hp_autodim_2194/regression_test.rb
ruby tests/hp_autodim_2194/spacing_regression_test.rb
HP_AUTODIM_TEST_VERSION=2.19.4 ruby tests/hp_autodim_219/tagging_test.rb
```

Các kiểm tra này dùng API thay thế. Hai thay đổi chưa được thao tác trực tiếp
trong SketchUp thật. Không thay thế xác nhận giao diện/native từ người dùng.

Sau cài đặt cần khởi động lại SketchUp. Với DIM đã tạo, dùng Cập nhật kích thước
ở scene đang mở để áp dụng định dạng. File/model riêng không đưa lên kho.
