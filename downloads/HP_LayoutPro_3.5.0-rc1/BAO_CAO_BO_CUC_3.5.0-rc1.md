# Kiểm tra HP Layout Pro 3.5.0-rc1

Ngày kiểm tra: 15/10/2026. Môi trường: Linux, Node 24, Chromium; API SketchUp mô phỏng. Chưa chạy trực tiếp SketchUp 2023 Windows.

## Phạm vi thay đổi

Thêm `ui/planner.js`; sửa tích hợp `common.js`, `design.js`, `design.html`, cập nhật phiên bản và tài liệu. Toàn bộ mã Ruby dựng Scene, hàng đợi, ghi PDF và xuất CAD giữ nguyên so với 3.4.2-rc1. FIT_VERSION vẫn là 5; không tự xếp lại trang đã có khi mở dự án.

Bộ xếp sử dụng khung bao hình + DIM, không hiểu cấu tạo sản phẩm hay tự sinh kích thước kỹ thuật. Căn Top/Front là căn giữa khung view; không suy luận gốc tọa độ chiếu hay chứng nhận tiêu chuẩn hình chiếu. Tỷ lệ của từng view được giữ và ghi riêng.

## Kết quả

- **11 nhóm kiểm tra bộ xếp mới đạt**: view cao/hẹp và dài/thấp, căn Top/Front/Side, phóng chi tiết nhỏ, phối cảnh, A3 ngang/dọc/A2, khung tên bên phải, tỷ lệ linh hoạt/quy ước, lọc/thứ tự/nhóm Scene, lưu và Khít không làm trôi tỷ lệ, không đổi trang/chú thích cũ khi tạo phương án, viền theo trang, dữ liệu đo lỗi, kích thước ngẫu nhiên, nhóm 64 Scene.
- Các vùng view không chồng nhau, giữ khoảng cách Template, nằm trong vùng bản vẽ. Khung hình + DIM lọt trong ô với khoảng chừa. Không mất/trùng Scene.
- **13 kiểm tra JS lõi và hồi quy bố cục đạt.** Các phương án có kết quả thực sự khác nhau; một Scene/tờ vẫn khít theo chiều giới hạn của giấy.
- **Giao diện Chromium đạt**: thẻ có ảnh, đổi ưu tiên độ lớn tính lại bố cục, xem phương án không thay trang đang có, tạo trang mới, hoán đổi view vừa ô, không lỗi JavaScript.
- **Xuất bố cục mới đạt**: đi qua render.html thật và PdfWriter thật, đọc lại thành PDF A3 3 tờ; 10 lượt xuất view (5 view trước/sau) đối chiếu chiều cao trên ảnh trang theo tỷ lệ yêu cầu, sai số dưới 1.25 mm ở độ phân giải kiểm tra 4 px/mm. Đây là kiểm tra mô phỏng luồng xuất, không phải đo sai số của máy in hay SketchUp thực.
- **Xuất bố cục cũ đạt**: 5 trang gồm bảng tổng hợp, chú thích và ảnh dùng chung có cùng toàn bộ điểm ảnh với bản đối chiếu 3.4.0-rc1; ảnh dùng chung chỉ giải phóng sau lượt dùng cuối.
- **18 kiểm tra Ruby lõi + 7 hàng đợi đạt.** Các kiểm tra in/đọc PDF xác nhận đúng khổ A3 và đủ trang.
- **Hồi quy sửa lag đạt**: 6 ảnh về → 0 lần dựng lại trang, giữ trường đang gõ; quay lại trang dùng ảnh cache; lướt nhanh chỉ dựng trang cuối; bỏ ảnh/callback cũ sau Cập nhật.

## So sánh bằng khung đo mô phỏng

| Bộ khung đo | Lưới 2×2 cũ | Bố cục kỹ thuật mới |
| --- | --- | --- |
| 5 view cao 2400 mm, rộng 600–1000 mm | 2 tờ; 4 view trang đầu ở 1:22.5, cao ~107 mm | 1 tờ ở 1:11.6, cao ~207 mm |
| 5 view dài/thấp khác kích thước | 2 tờ; tỷ lệ 1:7.6–1:16.5 | 2 tờ; tỷ lệ 1:6.1–1:10.1 |

PDF `MINH_HOA_BO_CUC_3.5.0-rc1.pdf` dùng các hình tủ đơn giản do bài kiểm tra tạo. Hai trang đầu là lưới cũ, trang cuối là bố cục mới. Ảnh thăm dò và nét biên làm tỷ lệ trong PDF này hơi khác bảng khung đo lý tưởng. Không dùng ảnh/model của khách hàng trong file minh họa.

64 Scene mô phỏng được bảo toàn trong mọi chính sách; mỗi chính sách mất khoảng 0.02–0.4 giây tính toán trong Node ở máy kiểm tra. Không tính thời gian SketchUp dựng/đo Scene; không suy ra tốc độ trên máy Windows của người dùng.

## Sử dụng

Cài RBZ, khởi động lại SketchUp, mở Quick Layout → Tự sắp theo nội dung → Bố cục kỹ thuật → Tạo trang. Tạo trang thay các trang của nhóm đã chọn cùng chú thích trên chúng; giữ bản SKP riêng nếu muốn lưu phương án cũ. Xem hướng dẫn kèm gói để chọn ưu tiên độ lớn và tỷ lệ quy ước.
