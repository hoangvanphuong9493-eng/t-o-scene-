# HP Tool One Click 0.13.0 beta

Cài RBZ bằng **Extension Manager → Install Extension**, sau đó khởi động lại SketchUp. Plugin chạy ngoại tuyến. Mở công trình cũ, bấm **Tối ưu thứ tự / vào dao** để áp dụng quy tắc mới rồi **Tạo G-code và mô phỏng** để tạo lại NC. NC cũ không tự thay đổi.

## Thuộc tính cắt và màn hình Tối ưu mới

Trong **Thuộc tính cắt → Cắt**, có **Cắt ngoài trước (ưu tiên biên)**. Tích rồi bấm **Áp dụng thuộc tính**: chi tiết này đi trước trong nhóm biên ngoài của tấm, kể cả khi là chi tiết lớn. **Khoan/rãnh/hốc/cắt trong vẫn chạy trước mọi biên cắt rời.** Các chi tiết khác tiếp tục theo quy tắc nhỏ/vừa ngoài vào trong, lớn cắt cuối. Ưu tiên trước và Giữ cắt cuối loại trừ nhau. Có Hoàn tác; chỉ định được lưu cùng .data và giữ khi xếp lại. Nếu đặt số thủ công bằng # Cắt, thứ tự thủ công được giữ đến khi bấm tối ưu hoặc đổi bố trí.

Màn hình dùng danh sách xổ xuống để chọn vật liệu, dành cột trái cho các tấm. Bảng lỗi thu gọn thành thanh trạng thái; **Xem danh sách lỗi** mở bảng nổi, không thu nhỏ tấm. Thu gọn lỗi vẫn chặn xuất NC khi chưa xử lý. Mặc định hiện số cắt và điểm vào dao; có thể bật Tên/ID khi cần. Có thanh phóng to, phím **F** vừa tấm, **+/−** phóng/thu; các công cụ gióng/đo nằm trong **Khác**.

Thuộc tính chia thành **Cắt / Gia công trong / Vị trí**, không cần cuộn qua toàn bộ biểu mẫu để sửa điểm vào. Điểm chọn cạnh vẫn đo theo khoảng cách cài đặt, thường 100 mm. Có nút **⚙** ngay trên trang Tối ưu để mở post/dao/layer/tem. Ô chờ vẫn giữ chi tiết khi chuyển tấm, xoay và kéo thả; bấm chi tiết ở danh sách chờ hoặc **Tấm + chờ** để xem cả vùng chờ.

## Thêm, nhân bản và xóa post, dao, layer

Vào **⚙ → Post / Máy CNC**, chọn **Thêm post / Nhân bản post / Xóa post**. Post mới bắt đầu từ cấu hình đang chọn để giữ đủ thư viện dao và mã chương trình; đặt tên và chỉnh thông số phù hợp trước khi dùng. Mỗi post giữ riêng dao, layer, khổ ván, feed và mã đầu/cuối. Bấm **Lưu cài đặt** sẽ chọn post đang sửa làm post sử dụng; cũng có thể chọn post ở bảng Bộ xuất mã của trang Công trình.

**Thư viện dao** và **Layer ngoài** dùng danh sách bên trái, biểu mẫu bên phải; có Thêm/Nhân bản/Xóa. Dao có số, tên, loại phay ngón/V, góc, đường kính, feed, vòng quay, lệnh đổi/mở/tắt, cờ khoan và lựa chọn dao cắt biên. Dao V được lưu trong thư viện; CAM chưa hỗ trợ gia công theo góc V. Layer có loại đối tượng, dao và đường kính tối đa, công thức độ sâu `pt`, lượt cắt và kiểu cắt. Layer ở đây là **khai báo gia công**, không xóa hình học trong model.

Giữ ít nhất một post. Muốn xóa dao cắt biên, chọn dao cắt biên khác trước; muốn xóa dao đang gán cho layer, đổi dao của layer trước. Tên/số trùng, dao thiếu và công thức không hợp lệ được báo trong cửa sổ cài đặt; cấu hình đã lưu không bị thay bằng bản lỗi. Nhập một bộ cài đặt có lỗi cũng giữ nguyên phương án đang chỉnh. Đóng cửa sổ khi chưa Lưu sẽ bỏ bản nháp.

**Xuất/Nhập cài đặt** và công trình .data lưu cả thư viện post. Chỉ đổi feed/vòng quay/mã chương trình sẽ giữ bố trí và yêu cầu tạo lại NC. Đổi dao, khai báo layer hoặc khổ xếp có thể cần đọc lại model và xếp lại; giao diện báo rõ. Quy ước NC hiện được hỗ trợ là X âm từ dưới phải, Y dương, Z0 bàn máy; thêm post không tự thay đổi quy ước tọa độ.

## Độ dày nẹp ở ngoài hình chi tiết trên tem

Nhãn nẹp được đặt **ngoài đường bao**, ví dụ `1 mm`, để tránh đè lên hình. SVG xem trước và PDF dùng chung bố trí; hình có thể xoay 0/90/180/270°. Trong **Thiết lập tem**, chọn trường **Hình chi tiết / nẹp → Nhãn nẹp ở ngoài chi tiết** để chọn **Độ dày / Mã nẹp / Mã và độ dày**. Kích thước ô hình quyết định khoảng trống dành cho chữ; tăng ô nếu cần chữ/hình lớn hơn.

Đã kiểm tra trên dữ liệu thật: ưu tiên biên/Hoàn tác, 136 chi tiết/21 NC, thư viện 2 post lưu và nhập lại, bảo vệ dao đang dùng, lỗi công thức không ghi đè cài đặt, chữ nẹp PDF nằm ngoài hình. Hồi quy 138 chi tiết kiểm tra ô chờ/chuyển tấm và 87 chi tiết kiểm tra tem, QR/mã vạch, cắt trong. Chưa chạy trên SketchUp Desktop/CNC thực tế.

## Sửa nhận dữ liệu One Click và ID báo lỗi

- Báo lỗi hiện **ID chi tiết, tên, cụm tủ, tên liên kết và nguyên nhân** ngay trên dòng chính. Nếu đã xếp, có số/ID tấm và nút **Tìm chi tiết trên tấm**. Đường dẫn kỹ thuật của liên kết vẫn nằm trong mục mở rộng và báo cáo.
- Nhận dao có tên “0” của dấu bản lề tự động theo đường kính đã khai báo, chỉ khi thư viện có đúng một dao phù hợp. Không tự thay thế một tên dao thực bị thiếu và không bỏ qua đường gia công lỗi.
- Chọn mặt phẳng lớn đúng độ dày thay vì lấy mặt gắn nhãn origin/copy đầu tiên. Với nhãn mặt lỗi thời ở chi tiết góc, chỉ khôi phục khi xác định được mặt tấm, mặt đối diện và dấu hướng vân; trường hợp chưa xác định vẫn bị chặn.
- Bổ sung chốt đợt `chot_dot`. Giữ cả các nhánh nét của dấu bản lề; không nối tắt qua vùng không có cạnh.
- Nhóm độ dày đến **0,1 mm** theo dữ liệu One Click; vẫn lưu độ dày đo được trong `hp_measured_thickness` để kiểm tra, ví dụ 17,465 mm thuộc nhóm 17,5 mm.
- Khi hai cạnh có mức tiếp giáp tương đương, chọn đoạn chốt cạnh vùng phôi chưa cắt lớn hơn. Giữ khoảng cách vào dao đã cài, chiều cắt và điểm chọn thủ công. Chuyển/xoay chi tiết vẫn tính lại theo tấm đích.

Đối chiếu bộ dữ liệu mới: bản cũ đọc được 132/136 chi tiết, chia 7 nhóm; bản sửa đọc đủ **136/136, 6 nhóm**, nhận đủ 234 lỗ và các đường rãnh/dấu/mộng liên quan. Kiểm tra bằng API mô phỏng SketchUp với hình học thật và trình duyệt; 136 biên ngoài, 21 tệp NC trên cả sơ đồ HP và sơ đồ tham chiếu. Số tấm còn phụ thuộc khóa vân và cấu hình xếp; chưa xác nhận chạy máy hoặc SketchUp Desktop thực tế. Sau khi cài, **đọc lại model hoặc nhập lại nesting.data** rồi xếp và tạo lại G-code; file công trình cũ vẫn chứa kết quả nhập cũ.

## Nhỏ/vừa trước, chi tiết lớn cắt cuối

Mặc định **Nhỏ/vừa ngoài → trong; chi tiết lớn cắt cuối**. Plugin tách nhóm lớn/giữ lại ra sau. Trong nhóm nhỏ/vừa, bóc lớp ngoài vào trong; kích thước chỉ dùng trong cùng lớp. Chi tiết lớn ở mép không còn chạy trước các thanh nhỏ ở phía trong.

⚙ → Post TAM AN có **Chi tiết lớn từ (m²)**, mặc định 0,5 m². Ngưỡng thực tế không vượt 20% diện tích phôi đang dùng, kể cả ván tận dụng. Chi tiết nhỏ/hẹp vẫn theo tiêu chí nhỏ trong cài đặt. Trong thuộc tính có thể tích **Đặt chi tiết này vào nhóm cắt cuối** để giữ thêm một chi tiết cụ thể.

Khoan, rãnh, hốc, cắt trong và khử góc chạy trước mọi biên cắt rời. Gom dao ít dùng trước, dao cắt biên cuối; ưu tiên một đường cụ thể có thể tăng lần đổi dao. **# Cắt** vẫn cho bấm lần lượt để đặt số thủ công. Đổi bố trí/tối ưu sẽ tính lại; mở file cũ giữ số đã lưu cho đến khi bấm **Tối ưu thứ tự / vào dao**.

## Giao diện tập trung vào tấm

Chế độ **Tập trung** bật mặc định ở trang Tối ưu: thu gọn đầu trang, tăng chiều cao sơ đồ; thuộc tính nằm cạnh vùng vẽ. Có nút tắt nếu muốn giao diện cũ.

- **Vừa tấm**: xem riêng tấm hiện tại, không gộp ô chờ làm nhỏ hình.
- **Chi tiết** hoặc bấm đúp chi tiết: xem gần chi tiết được chọn.
- **Xem đường** trong danh sách gia công: xem gần đúng lỗ/rãnh/biên đang kiểm tra.
- **Tấm + chờ**: xem cả tấm và các chi tiết đang chờ xếp để kéo sang tấm khác.
- Lăn chuột phóng tại con trỏ; chữ số giữ kích thước theo pixel. Có Toàn màn hình và công cụ kéo khung nhìn.

## Điểm xuống dao và mũi tên

- Điểm hạ dao và cạnh chốt được tính từ **bố trí hiện tại và thứ tự cắt hiện tại**, xét các chi tiết chưa cắt. Kéo, xoay, lật hoặc chuyển tấm sẽ bỏ điểm ghim cũ trên các tấm bị ảnh hưởng và tính lại; không dùng tọa độ từ tấm nguồn để chạy trên tấm đích.
- Mặc định xuống dao cách góc **100 mm** trên đoạn thẳng phù hợp, đi chéo một chiều theo chiều dài ramp đã cài rồi cắt toàn biên và vét lại đoạn vào dao. Với cạnh ngắn, giao diện báo khoảng cách thực tế thay vì kéo đường dao qua góc để giả đủ 100 mm.
- Tám nút chọn cạnh thể hiện cạnh và góc đo. Có thể đổi hướng cùng/ngược kim đồng hồ hoặc chọn **Tự chọn vào dao / giữ phôi**. Chiều lấy gốc và chiều cắt là hai cài đặt riêng.
- Bật **Vào dao**: cam là chuyển động XY có hạ Z; một mũi tên ở điểm bắt đầu chỉ chiều chạy. Không rải mũi tên dọc toàn bộ biên. Chấm đỏ là bắt đầu, vòng xanh là kết thúc, đoạn đỏ là cạnh chốt. Mũi tên lấy từ chuyển động NC, vẽ nổi trên các chi tiết và không phụ thuộc marker SVG. Có ở sơ đồ xem/in; sơ đồ SVG xuất cùng NC cũng lấy từ đường NC thực tế.
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

## Cắt trong / lỗ xuyên và ưu tiên từng đường

Chọn chi tiết rồi mở **Cắt trong / Lỗ xuyên / Chạy trước** trong thuộc tính, hoặc dùng công cụ **Cắt trong / Lỗ rãnh** rồi bấm vào chi tiết.

- Đường kín/lỗ tròn có lựa chọn **Cắt trong · xuyên tấm**: dùng dao cắt của post, bù bán kính về phía trong, chiều sâu bằng chiều dày cộng phần cắt sâu thêm. Đây là cắt theo biên trong, không phay hết lòng. Chỉ đổi đường cần cắt xuyên; các đường khác cùng layer giữ nguyên.
- Biên lỗ xuyên đã có trong nguồn được hiển thị và chạy kiểu cắt trong tự động. Không tự tạo hình lỗ mới nếu dữ liệu chưa có biên.
- Tích **Chạy trước** cho lỗ/rãnh/hốc cụ thể. Đường này được ưu tiên trước các gia công khác trong cùng lần gá; mọi biên cắt rời vẫn sau.
- **Xem đường** phóng gần đúng đường chọn. Mũi tên ở điểm xuống dao lấy từ chuyển động NC; chọn mặt trên/dưới phù hợp.

Với biên trong ngắn, dao hạ dần qua nhiều vòng để giữ góc ramp trong cài đặt rồi vét đủ biên ở chiều sâu cuối. Biên dài dùng đoạn ramp theo chiều dài cần thiết. Không áp dụng thay đổi này cho cách vào dao biên ngoài.

Đường cắt trong phải kín và nằm hoàn toàn bên trong chi tiết. Biên mở, chạm/vượt biên ngoài, dao không lọt hoặc biên có đảo trong lòng chưa hỗ trợ cắt xuyên sẽ báo rõ và chặn xuất NC. Thiết lập riêng được Ruby kiểm tra, lưu/mở cùng `.data`, giữ khi chuyển tấm/xếp lại và hỗ trợ Hoàn tác/Làm lại.

## Tem ngang/dọc tự dàn ô

Vào ⚙ → **Thiết lập tem**, chọn một trong bốn khổ và bấm **Tạo mẫu tự dàn ô**:

- Ngang **60 × 40** hoặc **70 × 50 mm**.
- Dọc **40 × 60** hoặc **50 × 70 mm**.

Mẫu có khung, thông tin chi tiết, số tấm/số tem/số cắt, QR, Code128, hình chi tiết/nẹp và vị trí trên tấm. Khi bật **Tự dàn lại ô khi ẩn / xóa trường**, bỏ Hiển thị rồi Áp dụng, hoặc Xóa trường, sẽ chia lại ô và nét kẻ theo các trường còn lại. Có thể Hoàn tác và bấm **Dàn lại các ô**. Tên dài được co chữ theo ô trong cả SVG và PDF.

Mẫu tự do cũ được giữ nguyên. Tắt tự dàn để nhập tọa độ hoặc kéo từng trường; kéo tay một trường của mẫu ô sẽ chuyển sang chỉnh tự do để giữ vị trí vừa chỉnh. Có lưới 0,1/0,5/1 mm, phóng to 100–400%, thêm ô/kẻ ngang/kẻ dọc, nhân bản trường và chỉnh nét. Sau khi lưu, chọn đúng tên mẫu mới ở trang Tem nhãn.

Tem in theo **số tấm rồi theo Y từng cột**. Số tem độc lập số cắt. Phông tiếng Việt, QR và Code128 chạy ngoại tuyến; PDF mỗi tem một trang đúng khổ, HTML dùng để in trên A4. In ở tỷ lệ 100%.

## Chia hàng/cột, gộp ô và xoay hình tem

Ở **Thiết lập tem**, chọn mẫu đang sửa:

1. Nhập **Số hàng / Số cột** rồi bấm **Áp dụng chia ô**, hoặc dùng **＋ Hàng / ＋ Cột**. Nét kẻ cũ được thay bằng lưới mới; nội dung trường giữ nguyên, có Hoàn tác.
2. Chọn hàng/cột cần chỉnh và thay **Chiều cao / Chiều rộng tương đối**, bấm **Áp dụng rộng / cao ô**. Ví dụ tỷ lệ 2 cao/rộng gấp đôi tỷ lệ 1.
3. Chọn trường, nhập **Gộp số hàng / Gộp số cột**, bấm **Áp dụng trường**. Dùng **Trường trước / Trường sau** để thay thứ tự phân ô. Ô gộp không có nét kẻ xuyên giữa.
4. **Xoay khổ tem ngang / dọc** đổi khổ giấy và dàn lại nội dung. Riêng hai hình nhận dạng, chọn trường **Hình chi tiết / nẹp** hoặc **Vị trí trên tấm**, đặt **Hướng hình 90° / 270°** rồi Áp dụng; hình được xoay và vừa trong ô, không bị tràn khỏi tem.
5. Ẩn/xóa trường vẫn dàn lại phần còn hiển thị. Tắt tự dàn nếu muốn kéo từng trường tự do; bật lại để trở về lưới đã cấu hình. Chỉnh lưới và xoay hỗ trợ Hoàn tác/Làm lại.

Giới hạn 30 hàng/12 cột; các nét thẳng liên tiếp được gộp để giảm tải giao diện. Xem trước có thể giới hạn số tem với mẫu nhiều nét; bản in vẫn chứa toàn bộ phạm vi đã chọn. Khổ ô, QR và mã vạch cần đủ lớn cho máy in. Mẫu kiểm tra đã quét QR/Code128 ở 203 và 300 dpi; in đúng tỷ lệ 100%.

## Lỗi NC và dữ liệu xuất

Lỗi hiển thị tiếng Việt, kèm mã vật liệu, ID/số tấm, mặt, ID chi tiết và nguyên nhân khi dữ liệu xác định được. **Tìm / chọn đối tượng** mở đúng tấm, viền và tích đỏ trên sơ đồ 2D. Phân biệt thiếu độ dày, lẫn độ dày, sai dao, va chạm, quá khổ và còn chi tiết chờ.

NC nằm trong thư mục riêng từng mã vật liệu; tên theo số tấm và mặt. `nesting` chứa `.data`, tem PDF/HTML, sơ đồ, BOM và báo cáo. Mở lại `.data` giữ trạng thái đã xuất. Không ghi đè model SketchUp hoặc NC nguồn. Mặt dưới chạy trước, lật cả tấm quanh Y và đăng ký lại phôi trước mặt trên theo post TAM AN; kiểm tra gốc máy thực tế.

## Kiểm tra độ ổn định và giới hạn

Bản này giảm tính toán lặp: xem trước một mặt tấm, lập chỉ mục chuyển động một lần, giới hạn lịch sử chỉnh tem và gom cập nhật kéo theo nhịp vẽ. Khi tạo toàn bộ NC, trả quyền xử lý giao diện giữa từng mặt và dừng kết quả nếu bố trí đã đổi. Callback của cửa sổ đã đóng không tác động cửa sổ mới. Các thao tác xếp/đường dao không sửa, xóa hoặc lưu đè đối tượng trong model.

Đã kiểm tra bộ dữ liệu mới 87 chi tiết / 17 tấm / 21 NC, nhóm lớn chạy sau nhóm nhỏ/vừa, một lỗ thật được chuyển sang cắt trong xuyên tấm và kiểm tra bù dao/độ sâu/thứ tự bằng hình học độc lập. Có kiểm tra hồi quy bộ 138 chi tiết / 26 tấm / 34 NC, kéo/xoay chi tiết chờ và các mẫu tem. Không tuyên bố đã giảm số tấm trong bản này.

Chưa chạy SketchUp Desktop hoặc máy CNC thật trong môi trường này, nên chưa thể kết luận plugin không gây văng SketchUp. Kiểm tra mô phỏng, chạy thử không cắt và kiểm tra lực hút/đồ gá trước khi sản xuất. Không dùng kết quả thử trong trình duyệt để thay cho kiểm tra thực tế.
