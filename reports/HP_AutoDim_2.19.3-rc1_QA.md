# HP Auto Dim 2.19.3-rc1 — biên bản kiểm tra

**Trạng thái: ứng viên kiểm thử; chưa nghiệm thu trong SketchUp thật.**

Mục tiêu là cập nhật theo hình học hiện tại khi thay kích thước, thay definition,
thêm/xóa/di chuyển đợt, hồi, cánh và tâm lỗ. Không suy ra rằng một DIM còn hiển thị
hoặc có cùng số cũ nghĩa là đã cập nhật đúng.

## Những phần đã sửa

- Chuỗi có nguồn xác định quét lại giao cắt trong phạm vi đo; không chỉ nối danh
  sách điểm bắt cũ. Bộ DIM cũ được chuyển bằng lệnh riêng trên nhóm đã chọn.
- Nguồn Fuji được tìm lại theo sheet/node/door ID duy nhất trong đúng container;
  điểm dự phòng phải khớp đỉnh/cạnh thật. Mất nguồn hoặc mơ hồ không được đoán.
- Phạm vi và phương đo theo hệ tọa độ nguồn khi Scale/di chuyển/xoay. Lùi chiều
  sâu chỉ xét trong dung sai và đúng mặt phẳng đo, tránh mượn điểm khoang bên.
- Tính lại nguồn trước fingerprint; tách cache theo definition thật. Kích thước
  hình học không tính annotation/DIM nằm bên trong group nguồn.
- Xóa hết cánh hoặc nguồn có định danh ổn định có thể tạo trạng thái 0 DIM và
  vẫn theo dõi để dựng lại khi chi tiết tương ứng được thêm trở lại.
- Nhãn dùng số đo native, tránh số cố định sau khi group chứa nó bị Scale.
- Chuyển scene yêu cầu cập nhật trì hoãn và bỏ cache visibility cũ. Không thêm
  quét hình học khi mở model hoặc ở từng frame vẽ.
- Thất bại vẽ không được cache thành thành công; giữ DIM cũ và thử lại được.
- Nhóm có thêm DIM/hình học vẽ tay không bị dựng đè; xóa HP giữ phần vẽ tay.
- Sửa `raytrace` thành API `raytest`, áp dụng lọc nhìn thấy vào giao cắt thật,
  dùng phép biến đổi normal đúng với Scale không đều.
- Có lệnh **Kiểm tra DIM với hình học hiện tại**, so số đoạn, hai đầu, offset
  và chữ; thiếu nguồn/mơ hồ không được báo đạt. Dung sai tọa độ 0,05 mm.

## Đã chạy

| Kiểm tra | Kết quả | Giới hạn |
|---|---|---|
| 62 đối chiếu tổng hợp, đủ 4 loại DIM | Đạt | API SketchUp thay thế, không phải native |
| Hình học trích từ model mẫu được cung cấp | Tái hiện lỗi và đạt các ca cập nhật sau sửa | Model và hình học riêng không công khai |
| Thêm/xóa/di chuyển đợt và hồi | Đạt | Đo các giao cắt trong phạm vi nguồn đã xác định |
| Thêm/xóa/di chuyển tim lỗ; xóa hết cánh rồi thêm lại | Đạt | Nhận diện cánh theo tên/metadata; không suy đoán mọi group là cánh |
| Định danh mới, nguồn mất/mơ hồ, thay definition cùng tên | Đạt | Không đảm bảo phục hồi nguồn không có danh tính ổn định |
| Scale không đều, di chuyển, xoay | Đạt về hình học | Chưa kiểm chứng hiển thị/native context trong SketchUp |
| Render lỗi, khôi phục in-place, thử lại | Đạt với lỗi chèn chủ động | Chưa thử lỗi native thực tế |
| Tag folder, tag loại/scene, chuyển tag rõ ràng | Đạt kiểm tra hồi quy | Chưa chạy Page transition native |
| Khoảng cách hàng 120 mm, DIM tay, xem trước cache | Đạt kiểm tra hồi quy | Chưa nghiệm thu thao tác chuột native |
| Cú pháp Ruby và ZIP RBZ | Đạt | Runtime kiểm tra Ruby 3.2.6 |

Lệnh chạy với Ruby 3.2+:

```sh
ruby tests/hp_autodim_2193/regression_test.rb
HP_AUTODIM_TEST_VERSION=2.19.3-rc1 ruby tests/hp_autodim_219/tagging_test.rb
HP_AUTODIM_TEST_VERSION=2.19.3-rc1 ruby tests/hp_autodim_2191/spacing_test.rb
```

Hai lỗi `injected one-shot ...` trong log tổng hợp là tình huống cố ý tạo để kiểm
tra giữ DIM cũ/khôi phục/thử lại, không phải kết quả thất bại của bộ kiểm tra.

## Phần chưa xác nhận

Chưa có SketchUp để chạy cài RBZ, mouse/input points, observer/timer native,
Undo/Redo, lưu/mở lại, scene animation, plugin Fuji thật hoặc model lớn.
Chưa chạy runtime Ruby 2.7 của SketchUp 2023; bước tải runtime bị cơ chế duyệt tự
động từ chối thực hiện do hết hạn mức, không phải kết luận tải đó không an toàn.

Bài `tests/hp_autodim_2193/sketchup_native_smoke.rb` đã kiểm tra cú pháp nhưng
**chưa chạy**. Bài này chỉ cho chạy trong model mới hoàn toàn trống, để lại một
mẫu QA riêng và có thể lưu JSON kết quả. Nó không mở/đóng file hiện tại hoặc sửa
preferences toàn cục. Ngay cả bài native này đạt cũng chưa thay thế toàn bộ thử
Undo/Redo, lưu/mở lại, scene/timer và Fuji thực tế.

Không có cơ sở cam kết chính xác tuyệt đối hoặc không còn lỗi từ các kết quả
ngoài SketchUp. Chỉ nên đổi trạng thái từ ứng viên sang bản ổn định sau nghiệm
thu native trên các ca thay đổi hình học thực tế.
