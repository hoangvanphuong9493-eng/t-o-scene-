# HP Tool One Click 0.3.0 beta

Plugin SketchUp độc lập, chạy ngoại tuyến. Đọc chi tiết, liên kết One Click đã lưu và layer ngoài trong model; xếp tấm, chỉnh sơ đồ, in tem, lập BOM và xuất G-code TAM AN. Không cần tài khoản để dùng HP Tool.

Bản beta đã kiểm thử bằng dữ liệu hình học thật, API SketchUp mô phỏng và Chromium. Chưa chạy trong SketchUp Desktop hoặc máy CNC thực tế; cần đối chiếu gốc phôi, dao, phép lật hai mặt và chạy thử không cắt trước sản xuất.

## Cài và sử dụng

1. Trong SketchUp 2023 trở lên: Extension Manager → Install Extension → chọn `HP_Tool_One_Click_0.3.0_beta.rbz`. Khởi động lại SketchUp nếu đang dùng bản cũ.
2. Mở Extensions → HP Tool One Click hoặc nút trên thanh công cụ cùng tên.
3. Nhập **Tên công trình**, **Mã công trình**, chọn **Mẫu tem**. Bấm ⚙ để chỉnh cài đặt, post, thư viện dao, quy tắc layer và thiết kế tem. Post mặc định theo setting TAM AN đã cung cấp, dao cắt **T2 Ø5**, bàn hút chân không.
4. Chọn cụm tủ trong model rồi **Tải dữ liệu và xếp tấm**. Có thể đọc model trước rồi xếp, hoặc nhập `nesting.data` của One Click. Đổi quy tắc layer, thư viện dao hoặc khổ ván sẽ yêu cầu đọc/xếp lại.
5. Xem danh sách lỗi ở Công trình. Tấm quá khổ giữ nguyên để bạn xử lý; không tự chia. Những liên kết chưa nhận dạng hoặc dữ liệu không đủ được báo và chặn xuất bộ NC thiếu.
6. Trong **Tối ưu**, kéo chi tiết; xoay/lật mặt; sửa tên/nhóm; đặt số cắt, hướng cắt và một trong tám điểm vào dao; chọn tab giữ phôi trên/dưới/trái/phải. Có hoàn tác/làm lại, thêm tấm trống, chuyển chi tiết sang tấm khác, xóa tấm trống, đường gióng, thước đo, phóng to và các tùy chọn hiển thị. Chi tiết có vân chỉ xoay khi cho phép đổi vân. Lật mặt đổi cả hình học và các đường gia công hai mặt.
7. **Bố cục** hiển thị sơ đồ, số cắt và chi tiết để kiểm tra/in. **BOM** tổng hợp số tấm vật liệu, chi tiết, phụ kiện nhận dạng, nẹp dán cạnh và vùng gia công/rãnh LED/rãnh hậu; có nhập vật tư bổ sung và xuất CSV tiếng Việt. Chiều dài nẹp được đọc từ các mặt cạnh có metadata, không suy đoán từ toàn bộ chu vi.
8. **Tem nhãn** xem và in tem. Trong ⚙ → Thiết kế tem, sửa khổ tem, chữ/biến nội dung, vị trí, kích thước, cỡ chữ, đậm, góc xoay; kéo trường, thêm QR/mã vạch, nhân bản mẫu và hoàn tác/làm lại. Mặc định P1 60 × 40 mm; PDF dùng Noto Sans nhúng có dấu tiếng Việt. QR tạo ngoại tuyến; Code128 dùng ID/số ASCII. Tem có tên/mã công trình, vật liệu, tên/nhóm chi tiết, kích thước, số tấm và số cắt.
9. Trong **Xuất G-code**, sửa dao, ưu tiên, độ sâu, số lượt, lượt tùy chỉnh (ví dụ `6;12;17.7`), kiểu gia công và khử góc. Bấm **Tạo G-code và mô phỏng**; các ô đang chỉnh được áp dụng trước khi tạo mã. Biên ngoài theo số cắt ở Tối ưu; ưu tiên trong bảng áp dụng cho nhóm gia công bên trong. Mặc định lỗ/rãnh trước biên ngoài. Tùy chọn cắt ngoài trước được thực hiện khi bạn chủ động bật cho chi tiết.
10. **Mô phỏng** đọc trực tiếp NC đã tạo, có 2D/3D, chạy/dừng/từng bước, tốc độ, thanh tiến trình và dòng lệnh hiện tại. Bấm **Xuất NC + tem + .data**, chọn thư mục cha; phần mềm tự tạo thư mục con mới theo giờ Việt Nam và tên model (hoặc tên công trình nếu model chưa lưu).

## Cấu trúc bộ xuất và mở lại

Ví dụ:

```text
15-10-2026-17-03-04-Tủ bếp/
  AC201_17.5/
    001-top.nc
    002-top.nc
    002-bottom.nc
  AC105_6.0/
    001-top.nc
  nesting/
    v5/
      AC201_17.5.pdf
      AC105_6.0.pdf
    labels-AC201_17.5.html
    layout-AC201_17.5.html
    svg-AC201_17.5.svg
    so-do/AC201_17.5/001.svg
    BOM.csv
    export-scope.json
    15-10-2026-17-03-04-Tủ bếp.data
  HUONG_DAN.txt
```

Mỗi thư mục vật liệu/độ dày chứa các NC đánh số theo tấm trên sơ đồ; không xuất tấm trống. Tấm hai mặt có thêm `bottom.nc`, nên số NC có thể lớn hơn số tấm ván. `export-scope.json` ghi số tấm, số thứ tự tấm và số NC theo vật liệu. Không ghi đè bộ xuất cũ khi trùng giờ/tên.

`nesting/v5/*.pdf` có một tem trên mỗi trang theo khổ mẫu, dùng cho máy in tem. `labels-*.html` dùng in tem trên A4, chọn tỷ lệ 100%. `layout-*.html` dùng xem/in sơ đồ; SVG có thể mở bằng trình duyệt. Không cần mạng để xem/in.

Ở **Xuất G-code** hoặc **Mô phỏng**, dùng **Mở .data** hay **Mở thư mục xuất**. Phần mềm phục hồi đúng vị trí, phép lật, đường gióng, số cắt, tab, thông tin công trình, mẫu tem, BOM bổ sung và bảng đường dao; không tự xếp lại. NC của lần xuất đó được lưu kèm trong `.data` để xem lại ngay. Nếu NC bên ngoài bị thay đổi, phần mềm báo và dùng bản trong `.data`. Muốn xuất bộ mới sau khi chỉnh, bấm **Tạo lại mã**.

Đây là định dạng lưu công trình riêng của HP Tool; không khẳng định One Click nhập được `.data` này. Nút **Lưu công trình / Xuất sơ đồ** vẫn lưu phương án JSON cùng CSV/SVG để kiểm tra riêng, và JSON này cũng mở lại được.

## Liên kết và layer được đọc

- Đọc đệ quy group/component, từng instance, phép biến đổi, `fuji_dict`, `sheet_id`, dấu mặt `origin_face`/`copy_face`, `outside_reverse`, vật liệu kế thừa và hướng vân. Đối chiếu cả mặt phẳng/vị trí vì một số persistent ID đã cũ.
- Nhận CAM, chân CAM, bản lề Ø35, khoan mồi, rãnh hậu, đánh dấu ray, tool_path có cấu hình, mộng âm và mộng đực dạng hộp. Mộng đực hợp vào biên trước khi xếp; mộng âm thành vùng phay hốc.
- Layer trực tiếp/kế thừa: `ABF_DOGBONE_R3-A12`, `ABF_Dogbone_Up_8.5`, `ABF_Ranh_BaoVe`, `ABF_RANH_UONCONG`, `MN_PhayLed`, `ABF_DOGBONE_R3_A12`; phân biệt dấu `-` và `_`. Độ sâu lần lượt 13.5; 10.5; 16.5; 16.5; 7; 13.5 mm theo setting đã cung cấp.
- Công thức độ sâu như `pt-4`, `pt` là độ dày tấm; hỗ trợ số, `+ - * / ()`, không thực thi mã. Vùng hốc giữ đảo; biên ABF tự giao chuẩn hóa theo vùng tô nonzero trước khi bù dao.
- Khoan cạnh đang bật, lỗ phụ D1/D2 đang bật, tấm uốn, mộng phức tạp, pocket2offset khác 0 hoặc dao V chưa hỗ trợ được báo. Không tự bỏ các mục này. Plugin đọc liên kết đã có, chưa thay thế chức năng dựng tủ/tạo liên kết mới.

## Xếp tấm và post TAM AN

MaxRects thử tám phương án theo hộp bao bảo thủ, tách vật liệu/độ dày; chưa xếp vào lỗ rỗng, dùng ván thừa hay cắt cạnh chung. Không khẳng định tối ưu toàn cục. Khổ mặc định 1220 × 2440, biên 5, khe 5.5, chi tiết nhỏ cách 10 mm. Tấm quá khổ giữ nguyên và báo để xử lý.

Dao cắt T2 Ø5, bù bán kính 2.5 mm; X âm từ góc dưới phải, Y dương, Z0 bàn máy; Z nâng bằng độ dày + 40 mm, xuyên sâu thêm 0.2 mm. Post dùng G90/G54, đặt G21/G17/G40/G80; đổi dao/spindle theo setting. Feed 12000, xuống Z giới hạn 6000, đoạn cung ngắn 5000, giảm tốc cuối biên 3000/120 mm. Ramp điều chỉnh theo chiều dài và góc đề xuất; đường ngắn có thể dốc hơn, cần chọn lượt cắt phù hợp. Đường tròn/hốc dùng G01 với sai số dây cung lỗ tính toán khoảng 0.005 mm. Tab theo vị trí bạn chọn, không tự thêm.

Hai mặt: chạy `bottom` trước khi tách chi tiết, lật **cả tấm** quanh Y và đăng ký lại G54, sau đó `top`. Phép lật/gốc phôi phải đối chiếu trên máy. Mô phỏng hiển thị đường dao, không mô phỏng đầy đủ cơ cấu máy, G53 hoặc tín hiệu M-code; chưa có xác nhận bộ điều khiển cụ thể.

Chức năng tối ưu khoan NC cũ chỉ đổi thứ tự các khối khoan độc lập, giữ sơ đồ, dao, feed và toàn bộ lệnh gốc; không gán sơ đồ xếp mới vào NC cũ.

## Kiểm thử và mã nguồn

Mẫu 136 tấm/32 vùng layer ngoài được xếp trên 22 tấm vật liệu, sinh 34 NC; kiểm tra độc lập bằng GEOS 46,114 chuyển động cắt, 127 vùng hốc, không cắt tấm bên cạnh, khoảng hở dao đến tấm bên cạnh nhỏ nhất 0.5 mm. Mẫu nesting cũ giữ đủ 629 chi tiết, xếp 95 → 94 tấm theo setting; không đồng nghĩa toàn bộ dữ liệu cũ đều chuyển CAM được.

Đã kiểm tra chỉnh sơ đồ qua Ruby, thứ tự/lượt cắt, lật mặt, tab trong NC, BOM, mô phỏng, xuất thư mục, PDF 136 tem (giải mã QR/Code128 và trích chữ tiếng Việt độc lập), `.data` lưu/mở lại và mở thư mục. Chưa thử SketchUp Desktop/CNC thực tế.

Nguồn Ruby/HTML/JS ở `src/`. Kiểm thử: `tests/core_test.rb`, `formula_test.rb`, `job_export_test.rb`, `node tests/cam_test.js`, `node tests/workbench_engine_test.js`; tích hợp `app_smoke.rb`, `workbench_smoke.py` dùng bộ model riêng không đóng gói. `ui_smoke.py` chạy bài giao diện hiện tại. Ruby cloud ở `/workspace/cloud-setup/bin/ruby`; các phép kiểm tra hình học/PDF độc lập cần Shapely, PyMuPDF, Pillow, zxing-cpp; giao diện dùng Python Playwright và Chromium.

Bộ cài chứa nguồn độc lập và thư viện có giấy phép: Clipper (Boost), QR/JsBarcode/jsPDF (MIT), Noto Sans (OFL). Không chứa model khách hàng, RBZ/RBE gốc hay thông tin đăng nhập. Các gói One Click đã đọc có phần Ruby chính mã hóa RBE; HP Tool không giải mã hoặc thay đổi khóa tài khoản của phần mềm gốc.
