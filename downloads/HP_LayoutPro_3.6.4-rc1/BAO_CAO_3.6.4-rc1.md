# Kiểm tra HP Layout Pro 3.6.4-rc1

Ngày 16/10/2026. Mục tiêu: tối ưu riêng tốc độ xuất PDF sau khi người dùng xác nhận 3.6.3 ổn định. Giữ bố cục/tỷ lệ/DPI, giới hạn tài nguyên và cơ chế chụp/khôi phục model.

## Thay đổi

- Mã hóa RGB không mất dữ liệu theo mảnh: PNG prediction (Sub dòng đầu, Up các dòng sau), một worker dùng lại trong phiên. Tận dụng CompressionStream, có fflate 0.8.2/MIT đi kèm để dự phòng khi API/worker không dùng được. Không cần tải thư viện qua mạng lúc xuất.
- Một canvas tối đa 1536×1536 dùng lại trong từng trang; chỉ đọc đúng vùng ở mảnh biên. Reset transform/path và save/restore trạng thái để khung/nét/chú thích không bị ảnh hưởng. Gợi ý canvas CPU khi browser hỗ trợ, không đổi thiết lập GPU toàn cục SketchUp.
- Giữ descriptor đường dẫn ảnh của view còn dùng ở trang sau trong cùng phiên; chỉ dùng lại khi key Scene/khung/tỷ lệ/vị trí/cỡ DIM khớp. Cache ảnh giải mã vẫn thu hồi và giữ ngân sách 32/48 MP của 3.6.3. Không giữ mọi ảnh đã giải mã trong RAM hoặc dùng ảnh của phiên xuất trước.
- Bộ mẫu 11 lượt dùng view/7 key ảnh: yêu cầu dựng ảnh giảm từ 11 xuống 7. Số giải mã có thể vẫn là 11 vì cache giải phóng ảnh giữa trang. File nguồn riêng phiên được dọn khi xong/hủy.
- Trả ngay thông tin đo Scene đã cache; chỉ cache miss đi qua timer native. Trang có danh sách dựng native rỗng ghép tiếp ngay. Chờ ổn định ban đầu, một Scene mỗi timer, khóa và khôi phục của các lệnh chụp thật giữ nguyên.
- Nhật ký thêm elapsed_ms theo đồng hồ đơn điệu, cache hit/miss và thời gian vẽ/nén/truyền để đo bước chậm thực tế trên Windows.

## Tốc độ đối chiếu

Cùng bộ mẫu 3 trang A3/16 px/mm (406,4 dpi), 60 mảnh, hình chiếu/phối cảnh, nét đậm, chú thích và Scene lặp. Mỗi bản chạy 3 lần xen kẽ. Ảnh PNG nguồn dựng sẵn, API SketchUp mô phỏng; không bao gồm thời gian SketchUp dựng model thật.

| Browser thử | Trung vị 3.6.3 | Trung vị 3.6.4 | Giảm | Khoảng 3.6.3 / 3.6.4 |
|---|---:|---:|---:|---|
| Chromium 88.0.4298.0 | 12.07 s | 8.02 s | 33.5% | 7.98–13.14 / 6.60–8.40 s |
| Chromium hiện hành | 18.47 s | 7.50 s | 59.4% | 16.78–18.63 / 6.59–8.84 s |

Các lượt có dao động; đây không phải cam kết tốc độ trên mọi máy/model. Kích thước dữ liệu nén của bộ mẫu cũng giảm, không suy rộng cho mọi ảnh/chất liệu. Không hạ DPI hoặc đổi tỷ lệ để đạt số đo.

Đã thử Chromium 88 vì bảng HtmlDialog API chính thức ghi CEF 88 từ SketchUp 2021.1, CEF 112 từ 2024: https://github.com/SketchUp/ruby-api-stubs/blob/main/lib/sketchup-api-stubs/stubs/UI/HtmlDialog.rb . Thử trên Linux/headless, chưa phải SketchUp 2023 Windows/GPU thực.

## Chất lượng và hồi quy

- 36 trường hợp codec: có/không nén native, worker hoạt động/bị chặn/timeout, context GPU/CPU, vùng 1 pixel/lẻ/1536 pixel lấy từ canvas dùng lại. RGB giải mã bằng zlib/PNG predictor độc lập giống từng byte với RGB gốc. Canvas alpha/kích thước vượt giới hạn bị từ chối.
- Thông điệp Chromium thật qua Session/PdfWriter thật; PyMuPDF đọc đủ 3 trang A3/60 ảnh mới ở mỗi thế hệ browser. Chromium 88: cả 3 tờ có RGB giống từng byte với 3.6.3 sau giải mã. Browser hiện hành: khác biệt raster nhỏ tại rìa/nét, mean 0,06418 / 0,01487 / 0,06417 trên thang 255/kênh; bounds trong 1 pixel, không có vệt trắng ở đường ghép. Không tuyên bố mọi browser/model có pixel giống từng byte.
- 50 Scene ở 4 px/mm: 50 trang theo thứ tự, 100 mảnh, 50 yêu cầu ảnh và 50 lần giải mã, không hỏi tiếp tục tỷ lệ/DPI, không giữ ảnh/descriptor sau hoàn tất. Session/PdfWriter và PyMuPDF xác nhận 50 khổ A3/100 ảnh, 50 tờ raster khác nhau. Đây là bài kiểm tra hàng loạt/vòng đời, không phải bài chất lượng 400 dpi.
- PDF tổng hợp nhiều trang, phối cảnh crop/zoom, chú thích và dọn ảnh đạt. 7 trường hợp cache/LRU/lỗi file/kích thước/ảnh trắng/timeout đạt.
- 50 cache hit Scene trả đúng request ID, không tạo timer/native call. Mixed hit/miss chỉ đo phần thiếu, chờ đầu 1,2 s giữ nguyên; cỡ DIM khác/invalidation không dùng dữ liệu cũ. Trang không cần native đi tiếp ngay. Ngoài một hàm đọc cache thuần túy, mã chụp/khôi phục Scene giống từng byte với 3.6.3.
- 18 kiểm tra Ruby lõi và 8 nhóm ổn định: deferred capture, chống gọi chồng, hủy, dữ liệu/thứ tự sai, giữ file đích, ảnh lớn chặn trước write_image và dọn file tạm đang khóa đạt. Exporter.run thật trong mô phỏng bật đúng các cờ mới và giữ trang/tỷ lệ/chất lượng.
- Kiểm tra cú pháp Ruby/JavaScript/script nội tuyến và ZIP khi đóng gói; 30 file đối chiếu từng byte mã nguồn, SHA256SUMS.txt cho RBZ/tài liệu.

## Phạm vi

Không đổi thuật toán sắp Scene, điều khiển xem/khít hoặc xuất CAD. Giữ giới hạn ảnh native 32 MP trước write_image và ngân sách ảnh cache/đang dùng 32/48 MP; chúng không phải tổng RAM/GPU của SketchUp. Thời gian native thực tế còn phụ thuộc model/GPU. Model SKP mới vượt giới hạn tải 32 MiB nên chưa đọc trực tiếp. Không xuất bản model, ảnh hay dữ liệu crash của người dùng.

fflate 0.8.2 được đối chiếu SHA512 SRI từ npm với bản đã cài; giữ đầy đủ bản quyền/giấy phép MIT của Arjun Barrett trong ui/pdf_deflate.js. Các binary Chromium chỉ dùng kiểm tra, không nằm trong RBZ.

Cài RBZ, đóng hoàn toàn/mở lại SketchUp, kiểm tra v3.6.4-rc1. Có thể xuất các trang đã lưu. Nhật ký %APPDATA%\HP_LayoutPro\last_pdf_export.log / menu Nhật ký xuất PDF… có thời gian từng bước để chẩn đoán trên máy thực nếu cần.
