# HP Tool One Click 0.10.0 beta

Cài RBZ bằng **Extension Manager → Install Extension**, sau đó khởi động lại SketchUp. Plugin chạy ngoại tuyến. Mở công trình cũ, bấm **Tối ưu thứ tự / vào dao** để áp dụng quy tắc mới rồi **Tạo G-code và mô phỏng** để tạo lại NC. NC cũ không tự thay đổi.

## Thứ tự cắt ngoài vào trong

Mặc định **Bóc lớp ngoài → trong; cùng lớp mới xét kích thước**. Plugin tìm các chi tiết còn lộ ra phía ngoài, bóc các góc ngoài của bố trí rồi tiếp tục lớp kế tiếp. Nếu không có góc lộ thì xét các mép lộ. Diện tích chỉ dùng trong cùng lớp; thanh nhỏ nằm sau chi tiết ngoài không được nhảy lên trước vì nhỏ hơn. Có thể xem các chế độ khác ở ⚙ → Post TAM AN → Thứ tự biên ngoài.

Khoan, rãnh, hốc và khử góc luôn chạy trước mọi biên cắt rời. Tùy chọn gom dao giữ các dao ít dùng trước và dao cắt biên cuối. Chọn công cụ **# Cắt**, bấm lần lượt vào chi tiết để đặt số thủ công. Số thủ công được giữ cho tới khi tối ưu lại hoặc đổi bố trí. Mở dữ liệu đã lưu giữ nguyên thứ tự để đối chiếu; việc nâng phiên bản không tự viết lại dữ liệu nguồn.

## Điểm xuống dao và mũi tên

- Điểm hạ dao và cạnh chốt được tính từ **bố trí hiện tại và thứ tự cắt hiện tại**, xét các chi tiết chưa cắt. Kéo, xoay, lật hoặc chuyển tấm sẽ bỏ điểm ghim cũ trên các tấm bị ảnh hưởng và tính lại; không dùng tọa độ từ tấm nguồn để chạy trên tấm đích.
- Mặc định xuống dao cách góc **100 mm** trên đoạn thẳng phù hợp, đi chéo một chiều theo chiều dài ramp đã cài rồi cắt toàn biên và vét lại đoạn vào dao. Với cạnh ngắn, giao diện báo khoảng cách thực tế thay vì kéo đường dao qua góc để giả đủ 100 mm.
- Tám nút chọn cạnh thể hiện cạnh và góc đo. Có thể đổi hướng cùng/ngược kim đồng hồ hoặc chọn **Tự chọn vào dao / giữ phôi**. Chiều lấy gốc và chiều cắt là hai cài đặt riêng.
- Bật **Vào dao**: cam là chuyển động XY có hạ Z; mũi tên xanh chỉ chiều cắt, mũi tên cam chỉ chiều hạ chéo. Chấm đỏ là bắt đầu, vòng xanh là kết thúc, đoạn đỏ là cạnh chốt. Mũi tên lấy từ chuyển động NC, vẽ nổi trên các chi tiết và không phụ thuộc marker SVG. Có ở sơ đồ xem/in; sơ đồ SVG xuất cùng NC cũng lấy từ đường NC thực tế.
- Xem đúng mặt trên/dưới. Xem trước chỉ tính tấm và mặt đang chọn; xuất NC kiểm tra đầy đủ phạm vi được chọn. Bố trí còn chi tiết chờ không được xuất NC hoặc tem; vẫn có thể xem đường dao của các chi tiết đã đặt.

Việc chọn cạnh giữ phôi là đánh giá hình học. Chưa đo lực hút, đồ gá hoặc độ ổn định của từng chi tiết trên máy thực tế.

## Ô chờ chung để xoay và kéo sang tấm khác

1. Kéo hẳn chi tiết ra ngoài tấm rồi thả. Chi tiết được đưa sang **ô chờ màu vàng**, giữ nguyên ID, hình học và dữ liệu gia công; chưa có số cắt/số tem.
2. Bấm tấm đích ở cột hình thu nhỏ. Chi tiết chờ của cùng mã vật liệu vẫn hiện trên sơ đồ, không cần quay lại tấm nguồn.
3. Chọn chi tiết chờ rồi **Xoay**, hoặc bấm **Xoay 90°** trong danh sách chờ. Khóa vân vẫn được tôn trọng; muốn đổi hướng thì mở khóa theo mã hoặc bật Cho phép đổi hướng vân cho chi tiết.
4. Kéo trực tiếp từ ô chờ vào vị trí muốn đặt trên tấm đang chọn. Bắt điểm giúp giữ khe hở. Có thể kéo tiếp trong ô chờ. Nút **Đưa vào Tấm…** là cách tự tìm chỗ nếu cần.
5. Có thể kéo lên hình tấm khác hoặc **+ Tấm** để chuyển và tự tìm vị trí. Chỉ chuyển cùng mã vật liệu/độ dày. Vị trí không đủ khổ hoặc khe hở sẽ được báo rõ; ID không bị mất hay nhân đôi.

Thao tác được Ruby kiểm tra trước khi chấp nhận; có Hoàn tác/Làm lại. Đường dao và số cắt được tính lại sau khi thả. Không xóa tấm vẫn còn chi tiết, kể cả chi tiết chờ.

## Xếp tấm và tìm phương án tiếp theo

Ưu tiên trục **Y**, sau đó sang cột bên theo góc neo. Khóa xoay và dùng ván tận dụng được cài riêng theo mã vật liệu. Ván tận dụng kiểm tra khổ thực tế, số lượng và mã; gom hai mặt và phân bổ chi tiết nhỏ được xét trong đánh giá phương án.

**Xếp lại riêng mã này** hoặc chạy lại toàn bộ sẽ thử thêm 24 phương án cho mỗi mã tối đa 250 chi tiết; nhóm lớn thử thêm 10. Giữ phương án tốt hơn hoặc phương án khác cùng mức đánh giá, không thay bằng phương án bị đánh giá kém hơn. Xếp riêng một mã giữ các mã khác. Không bảo đảm mỗi lần bấm đều giảm số tấm hoặc tìm tối ưu toàn cục.

**Xuất riêng mã này** chọn phạm vi NC/tem/sơ đồ. Tấm quá khổ được báo để xử lý; không tự chia chi tiết.

## Chọn một lỗ/rãnh/hốc chạy trước

Chọn chi tiết → **Gia công chạy trước**, tích đúng đường; hoặc dùng **Ưu tiên lỗ/rãnh** rồi bấm trực tiếp vào đường nguồn trên sơ đồ. Màu cam là đã ưu tiên. Chọn đúng mặt; thứ tự chọn được lưu theo đường nguồn của chi tiết.

Ưu tiên cụ thể chạy trước các gia công khác trong cùng lần gá, có thể tăng lần đổi dao. Mọi đường cắt rời vẫn cuối. Lựa chọn được giữ khi lưu/mở, chuyển tấm, xếp lại và Hoàn tác/Làm lại.

## Tem ngang/dọc tự dàn ô

Vào ⚙ → **Thiết lập tem**, chọn một trong bốn khổ và bấm **Tạo mẫu tự dàn ô**:

- Ngang **60 × 40** hoặc **70 × 50 mm**.
- Dọc **40 × 60** hoặc **50 × 70 mm**.

Mẫu có khung, thông tin chi tiết, số tấm/số tem/số cắt, QR, Code128, hình chi tiết/nẹp và vị trí trên tấm. Khi bật **Tự dàn lại ô khi ẩn / xóa trường**, bỏ Hiển thị rồi Áp dụng, hoặc Xóa trường, sẽ chia lại ô và nét kẻ theo các trường còn lại. Có thể Hoàn tác và bấm **Dàn lại các ô**. Tên dài được co chữ theo ô trong cả SVG và PDF.

Mẫu tự do cũ được giữ nguyên. Tắt tự dàn để nhập tọa độ hoặc kéo từng trường; kéo tay một trường của mẫu ô sẽ chuyển sang chỉnh tự do để giữ vị trí vừa chỉnh. Có lưới 0,1/0,5/1 mm, phóng to 100–400%, thêm ô/kẻ ngang/kẻ dọc, nhân bản trường và chỉnh nét. Sau khi lưu, chọn đúng tên mẫu mới ở trang Tem nhãn.

Tem in theo **số tấm rồi theo Y từng cột**. Số tem độc lập số cắt. Phông tiếng Việt, QR và Code128 chạy ngoại tuyến; PDF mỗi tem một trang đúng khổ, HTML dùng để in trên A4. In ở tỷ lệ 100%.

## Lỗi NC và dữ liệu xuất

Lỗi hiển thị tiếng Việt, kèm mã vật liệu, ID/số tấm, mặt, ID chi tiết và nguyên nhân khi dữ liệu xác định được. **Tìm / chọn đối tượng** mở đúng tấm, viền và tích đỏ trên sơ đồ 2D. Phân biệt thiếu độ dày, lẫn độ dày, sai dao, va chạm, quá khổ và còn chi tiết chờ.

NC nằm trong thư mục riêng từng mã vật liệu; tên theo số tấm và mặt. `nesting` chứa `.data`, tem PDF/HTML, sơ đồ, BOM và báo cáo. Mở lại `.data` giữ trạng thái đã xuất. Không ghi đè model SketchUp hoặc NC nguồn. Mặt dưới chạy trước, lật cả tấm quanh Y và đăng ký lại phôi trước mặt trên theo post TAM AN; kiểm tra gốc máy thực tế.

## Kiểm tra độ ổn định và giới hạn

Bản này giảm tính toán lặp: xem trước một mặt tấm, lập chỉ mục chuyển động một lần, giới hạn lịch sử chỉnh tem và gom cập nhật kéo theo nhịp vẽ. Khi tạo toàn bộ NC, trả quyền xử lý giao diện giữa từng mặt và dừng kết quả nếu bố trí đã đổi. Callback của cửa sổ đã đóng không tác động cửa sổ mới. Các thao tác xếp/đường dao không sửa, xóa hoặc lưu đè đối tượng trong model.

Đã kiểm tra tự động dữ liệu 138 chi tiết / 26 tấm / 34 NC, xoay và kéo chi tiết chờ sang tấm khác, tính lại cạnh vào dao theo phôi chưa cắt, bốn mẫu tem/PDF/mã quét và kiểm tra hình học NC độc lập. Dữ liệu kiểm tra vẫn dùng 26 tấm; không tuyên bố đã giảm tấm.

Chưa chạy SketchUp Desktop hoặc máy CNC thật trong môi trường này, nên chưa thể kết luận plugin không gây văng SketchUp. Kiểm tra mô phỏng, chạy thử không cắt và kiểm tra lực hút/đồ gá trước khi sản xuất. Không dùng kết quả thử trong trình duyệt để thay cho kiểm tra thực tế.
