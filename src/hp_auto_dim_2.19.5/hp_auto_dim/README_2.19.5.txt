HP Auto Dim 2.19.5 — SketchUp 2023+

Sửa hai nguyên nhân ngừng tự cập nhật:
1. Di chuyển nguyên nhóm DIM HP không còn làm mất bản ghi liên kết nguồn.
   Khi dựng lại theo hình học mới, giữ độ dịch của nhóm. Nhóm đã Scale/xoay,
   thêm DIM tay hoặc sửa số đoạn được tạm dừng, giữ dữ liệu để tránh ghi đè.
   Nhóm DIM do người dùng xóa vẫn không bị tự tạo trở lại.
2. Nhấn Esc/Enter về bước chọn điểm đầu không còn khóa cập nhật trong lúc
   công cụ DIM vẫn đang được chọn. Khi đang chọn điểm hoặc đặt DIM, tiếp tục
   chờ kết thúc thao tác để giữ an toàn cho bản xem trước.

Với nhóm DIM cắt đã bị bản trước làm mất bản ghi nguồn:
- Mở scene của nhóm, nhìn chính diện, chọn nhóm DIM cắt HP.
- Chuột phải > HP: Khôi phục tự cập nhật DIM cắt (toàn bộ tủ).
- Nếu model có nhiều tủ, chọn thêm đúng tủ nguồn rồi chạy lệnh từ menu
  Extensions > HP Auto Dim > Khôi phục tự cập nhật DIM cắt đã chọn (toàn bộ tủ).
- Lệnh dựng lại phạm vi toàn bộ tủ từ các cạnh/tấm biên hiện tại và cài đặt
  hiện tại; không khẳng định khôi phục được phạm vi đường cắt cục bộ đã mất.
  Muốn đo riêng một phần, tạo lại đường cắt đó bằng công cụ DIM cắt.
- Lệnh từ chối nhóm sửa tay, trùng mã, sai scene, hướng chéo hoặc nguồn không
  rõ ràng. Không tự khôi phục/chuyển đổi hàng loạt khi mở file.

Giữ nguyên định dạng số tròn bỏ .0 và khoảng cách giữa các hàng của 2.19.4.
Giữ nguyên từng byte: anchors.rb, live_geometry.rb, rendering.rb,
scheduler.rb, tracking.rb, tagging.rb, verification.rb, spacing.rb và icons.
Không thay hàm tính DIM, bắt điểm hoặc chân DIM. Không đổi tag nguồn.

Kiểm tra bằng API thay thế, đạt trên Ruby 2.7.8 và 3.2.6:
- 71 đối chiếu qua ModelObserver -> timer -> cập nhật nền, gồm thêm/bớt/di
  chuyển đợt, hồi, tim lỗ; đổi kích thước; dịch nhóm; Esc; Save; Undo/Redo;
  khôi phục có kiểm soát và giữ dữ liệu khi quá thời gian cập nhật nền.
- 62 đối chiếu hình học/render/cập nhật bốn loại DIM; 26 đối chiếu định dạng
  và đặt hàng; hồi quy Tags/scene và khoảng cách hàng.
- 17 đối chiếu trên dữ liệu hình học trích từ model mới, cùng hồi quy trên
  model trước. Model riêng không nằm trong gói hoặc kho công khai.

Chưa thao tác trực tiếp trong SketchUp thật: giao diện, native observer/timer,
Undo/Redo thật và tích hợp với OneClick/Fuji khi tái tạo tủ còn cần xác nhận
trong SketchUp. Kiểm tra ngoài ứng dụng không bảo đảm mọi model đều không lỗi.

Cài bằng Extension Manager, sau đó khởi động lại SketchUp để nạp đúng bản.
Đối với DIM đã mất liên kết, cần chạy lệnh khôi phục chủ động ở trên.
