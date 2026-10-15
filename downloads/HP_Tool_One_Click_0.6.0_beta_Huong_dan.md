# HP Tool One Click 0.6.0 beta

Plugin SketchUp độc lập, chạy ngoại tuyến. Đọc chi tiết, liên kết One Click đã lưu và layer ngoài trong model; xếp tấm, chỉnh sơ đồ, in tem, lập BOM và xuất G-code TAM AN. Không cần tài khoản để dùng HP Tool.

Bản beta đã kiểm thử bằng dữ liệu hình học thật, API SketchUp mô phỏng và Chromium. Chưa chạy trong SketchUp Desktop hoặc máy CNC thực tế; cần đối chiếu gốc phôi, dao, phép lật hai mặt và chạy thử không cắt trước sản xuất.

## Sửa theo TES và các file One Click trong 0.6.0

- **Bảng Xuất G-code gom cùng số dao**: dao ít dùng trước, dao cắt biên sau; ưu tiên chỉ so trong cùng dao. Mô phỏng ghi chuỗi dao thực tế cho từng file NC. Số dao không nhất thiết tăng dần: ví dụ T8 ít lỗ chạy trước T2 dùng nhiều và cắt biên. Gia công hai mặt vẫn xuất bottom trước/top sau theo thao tác lật và đăng ký phôi.
- **Kéo chuyển tấm**: giữ chuột trên chi tiết rồi thả vào hình tấm đích ở cột trái, hoặc lên **+ Tấm** để tạo tấm mới và chuyển. Tự tìm vị trí đủ kích thước/khe hở, giữ hướng và mặt của chi tiết. Nếu tấm đích hết chỗ, báo rõ và giữ bố trí cũ. Có thể dùng **Thuộc tính → Chuyển sang tấm**. Sau khi chuyển tự tính lại số cắt/điểm vào dao của cả hai tấm; Hoàn tác/Làm lại hoạt động cho việc chuyển này.
- **Xếp/Xuất riêng mã**: trong Xếp tấm, chọn mã ở **Phạm vi** rồi bấm **Xếp lại mã đã chọn** hoặc **Xuất lại mã đã chọn**. Mỗi nhóm cũng có hai nút riêng. Trong Xuất G-code có ô **Xuất mã vật liệu**. Xếp riêng giữ vị trí, hướng, số cắt, điểm chọn và gióng ở các mã khác. Bộ xuất chỉ có NC, tem PDF, sơ đồ và BOM của mã đã chọn; `.data` vẫn giữ toàn bộ công trình cùng phạm vi NC của lần xuất để mở kiểm tra hoặc xuất mã khác. Vật tư nhập tay chưa gắn mã vật liệu chỉ có trong BOM khi xuất tất cả.
- **Khóa xoay vân thực sự theo từng mã/độ dày**: bật giữ hướng nguồn; tắt cho phép xoay 90° cả chi tiết có vân khi ô “Cho phép xoay khi mở khóa vật liệu” bật. Việc mở khóa có thể đổi hướng vân, không sửa thông tin vân gốc của model. Bấm xếp lại riêng mã đó để áp dụng. Có thể cho phép đổi vân riêng một chi tiết trong Tối ưu.
- **Khoảng cách xuống dao 100 mm**: chọn cạnh đủ dài và đo trên cạnh chi tiết từ góc, không đo quanh cung bù dao. Khi tự động chọn cạnh vẫn giữ khoảng cách đã nhập; không tự dời sang điểm giữa vì quãng chạy ngắn hơn. Cạnh quá ngắn được giới hạn vào đoạn thẳng còn dùng được và ghi khoảng cách thực tế/lý do trong Thuộc tính và Mô phỏng. Điểm ghim thủ công là lựa chọn riêng; bỏ ghim bằng nút Tự chọn hoặc Tối ưu thứ tự / vào dao để dùng quy tắc 100 mm.
- **Vào dao chéo một chiều theo mẫu NC One Click**: mặc định 50 mm, hạ chéo trên biên đã bù dao rồi đi hết biên ở độ sâu yêu cầu; vét lại đoạn vào dao ở feed cuối. Kết thúc ở cuối đoạn vét, không quay đầu hạ Z nhiều lần. Tránh tab; mọi khoan/rãnh/hốc/khử góc trước, biên ngoài sau. Chiều lấy gốc chọn phía đo từ góc; hướng cắt chọn chiều chạy biên. Tốc độ Z vẫn bị giới hạn theo post.
- ⚙ → Post TAM AN có ba chế độ. **Một chiều** dùng chiều dài đoạn chéo và số lượt; góc hạ dao thực tế tùy độ sâu mỗi lượt. **Qua lại** giữ góc tối đa đã nhập; **Ramp theo biên** để đối chiếu cách cũ. Cài đặt đã lưu từ bản cũ được giữ: muốn dùng cách mới, chọn “Hạ chéo một chiều theo mẫu One Click”, khoảng cách 100 và đoạn vào dao 50 mm. Không thay đổi G54/gốc phôi.
- Đã đọc đủ sáu `nesting.data` One Click 4.2 mới: 603/239/498/1.058/528/160 chi tiết, phân tích các góc bắt đầu được lưu trong SVG. TES mới: 87 chi tiết, 0 lỗi liên kết, 17 tấm, 21 NC; 87 điểm tự động đạt 100 mm. Kiểm tra GEOS 7.604 chuyển động cắt, 44 vùng hốc; khoảng hở dao với chi tiết bên cạnh tối thiểu 0,5 mm. Mở khóa AC021T-17.5 theo file HP cũ: xoay 47 chi tiết, vẫn đủ 87 chi tiết/17 tấm, kiểm tra NC độc lập đạt. Không khẳng định giảm được số tấm trong mọi công trình.

**Cài cập nhật:** Extension Manager → Install Extension → chọn RBZ 0.6.0, khởi động lại SketchUp. Với file TES đang lưu từ HP 0.4, đọc lại model và xếp lại để áp dụng trừ nẹp cùng cách xếp mới. Mở khóa theo vật liệu khi cần xoay. Muốn hạ chéo một chiều, chọn rõ chế độ trong ⚙ nếu cài đặt cũ đang giữ chế độ qua lại. Chưa chạy SketchUp Desktop/CNC thực tế.

## Sửa cập nhật sau tối ưu thủ công trong 0.5.1

- Sau khi kéo/thay tọa độ, xoay, lật hoặc chuyển chi tiết sang tấm khác, plugin tự chuyển sang tính số cắt theo quy tắc hiện tại, bỏ điểm vào dao cũ trên các tấm bị ảnh hưởng và tính lại từ bố trí mới. Giữ nguyên vị trí bạn vừa chỉnh, không xếp lại toàn bộ chi tiết.
- Điểm xuống dao được tính ngay sau khi Ruby kiểm tra/chấp nhận sơ đồ, dùng cùng bộ CAM với NC. Không cần bấm Tạo G-code mới thấy cập nhật. Chấm đỏ là xuống dao, vòng xanh là kết thúc; khi cùng vị trí vẫn thấy cả hai. Có trạng thái đang tính/đã cập nhật/lỗi, không giữ dấu dao cũ khi đang kéo hoặc khi phép tính không hợp lệ.
- Khi dùng **# Cắt** hoặc sửa số cắt mà không đổi hình học, thứ tự thủ công được giữ. Khi tiếp tục thay bố trí, số cắt được tính tự động lại. Chọn điểm vào dao mới sau khi bố trí xong vẫn được áp dụng và kiểm tra. Nút **Tối ưu thứ tự / vào dao** xóa các điểm ghim cũ để tính lại tự động.
- Hoàn tác/Làm lại khôi phục đúng bố trí, số cắt và điểm chọn trước đó, rồi tính lại dấu dao tương ứng. Đổi tấm cập nhật cả tấm nguồn và tấm đích.
- Kết quả tính chậm của sơ đồ cũ bị bỏ; chỉnh sơ đồ vô hiệu hóa bộ NC cũ. Xem trước điểm dao không tự cho phép xuất NC: vẫn bấm **Tạo G-code** để tạo/kiểm tra bộ mới trước khi xuất.
- Đã kiểm thử trình duyệt với `.at()` bị tắt: kéo/xoay/lật/chuyển tấm, đánh số thủ công rồi chỉnh bố trí, undo/redo, đổi điểm vào dao, lỗi/xem trước cũ, NC khớp dấu dao và lưu/mở lại `.data`. Cũng chạy hồi quy model thật 136 chi tiết, 29 NC và PDF 136 tem. Chưa chạy trong SketchUp Desktop/CNC thực tế.

**Cập nhật từ 0.5:** cài RBZ rồi khởi động lại SketchUp, mở lại công trình hoặc đọc model. Những phương án đã có số cắt thủ công sẽ tự tính lại khi bạn thay bố trí. Cập nhật từ trước 0.5 vẫn cần đọc lại model/xếp lại để áp dụng trừ nẹp.

## Những thay đổi trong 0.5

- Sửa lỗi `lo.at is not a function` trên trình duyệt nhúng SketchUp: trong TES, 30 lỗi thuộc 30 mộng đực trên 11 chi tiết, không phải 30 tấm hỏng. Bản này không dùng `Array.at`. Thông báo hiện nguyên nhân, cách xử lý, số đối tượng bị ảnh hưởng; các lỗi lặp được gom và vẫn giữ mã kỹ thuật/ID để tra cứu.
- Trừ độ dày nẹp dán cạnh có metadata trước khi xếp/cắt. Tem/BOM giữ kích thước danh nghĩa. Cạnh nẹp phải khớp cạnh thẳng và có độ dày hợp lệ; trường hợp chưa xác định được sẽ báo, chặn NC. Với TES, 71 chi tiết có nẹp; đối chiếu cả biên của 87 chi tiết với snapshot One Click sai lệch tối đa 0,000034 mm sau khi đưa về cùng gốc/hướng mặt.
- Xếp tấm → **Cài đặt riêng theo vật liệu / độ dày**: khóa xoay 90°, bật ván tận dụng, nhập mã/khổ thực tế/số lượng. Ván tận dụng của mã nào chỉ dùng cho mã đó, ưu tiên trước tấm mới; không dùng quá số lượng nhập. Sơ đồ, bắt dính, gióng, mô phỏng, gốc X NC, BOM và `.data` đều dùng khổ thực tế từng tấm. Từ 0.6, mở khóa vật liệu cho phép xoay 90° cả chi tiết có vân; có quyền cho phép xoay riêng trong Tối ưu.
- Trong 0.5, vào dao biên ngoài mặc định **hạ chéo trên một đoạn thẳng đã bù dao**, hoàn tất hạ Z rồi mới chạy hết biên. Khi đoạn thẳng ngắn hơn chiều dài cần để giữ góc xuống tối đa, dao đi qua lại trên cùng đoạn đó, không hạ chéo quanh góc/mộng. Tránh tab giữ phôi. ⚙ → Post TAM AN có chế độ vào dao, **chiều đường cắt lấy gốc** và **vị trí xuống dao từ góc gốc (mm)**. Điểm tự động cân nhắc phôi còn lại và quãng chạy; điểm chọn thủ công vẫn phải đủ đoạn thẳng. Giá trị lấy gốc ảnh hưởng điểm đề xuất, không thay gốc G54. Cách ramp theo biên cũ còn trong cài đặt để đối chiếu.
- Gom gia công theo dao, ưu tiên dao ít dùng trước, giữ dao cắt biên cuối để tránh quay lại đổi dao. Ưu tiên trong bảng áp dụng trong nhóm dao; biên ngoài luôn sau mọi khoan/hốc/rãnh/khử góc. Đường khoan chọn điểm gần và cải thiện 2-opt, đường mở chọn đầu gần, các vùng khác chọn gần trong cùng nhóm. Mô phỏng hiện chuỗi dao, số lần đổi và tổng G00 XY; không khẳng định quãng đường tối ưu toàn cục.
- Không coi chi tiết chỉ có gia công mặt dưới là chi tiết hai mặt. Khi không bật “Giữ mặt nguồn”, xếp mặt gia công lên trên bằng cách phản chiếu cả hình học, phép biến đổi và ánh xạ lỗ/rãnh. Các chi tiết thực sự hai mặt vẫn được gom khi vừa. Trong TES, giữ 17 tấm và giảm 25 → 21 NC so với cách xếp mặt nguồn trước đây.
- Tối ưu hiện **ID tấm**, ID chi tiết, cờ ván tận dụng, khổ thực tế trong hình thu nhỏ; có bật/tắt ID trên sơ đồ. Mô phỏng và danh mục bộ xuất cũng hiện ID/khổ tấm.
- Đọc thêm snapshot One Click V5 `sheetsByMaterial/configs/binsByMaterial`, gồm biên đã trừ nẹp và hợp mộng, lỗ, hốc, đường tùy chỉnh và nẹp. Chưa hỗ trợ khoan cạnh, lockdowel, Pocket 2 offset khác 0: báo rõ và chặn thay vì bỏ qua.

**Cập nhật từ bản cũ:** cài RBZ rồi đóng/mở lại SketchUp, chọn cụm cần gia công và **đọc lại model, xếp lại**. Phương án HP Tool cũ chưa trừ nẹp vẫn có thể xem lại, nhưng bị chặn tạo NC mới nếu dữ liệu nguồn chưa qua bước trừ nẹp. Không dùng lại NC cũ để đánh giá bản sửa này.

## Các chức năng đã có

- Mặc định neo **dưới phải**, xếp **theo trục Y trước**: đi dọc cột, rồi chuyển sang cột bên trái. Đổi điểm neo chỉ tịnh tiến vị trí xếp, không phản chiếu chi tiết hoặc đổi gốc NC TAM AN.
- **Ưu tiên gom chi tiết hai mặt** trên cùng tấm vật liệu/độ dày khi còn vừa; nếu không vừa một tấm thì tiếp tục trên tấm khác. **Phân bổ chi tiết nhỏ** qua các tấm còn chỗ, có bước xếp lại từng cặp tấm để giảm dồn vào tấm cuối. Không tự thêm tấm chỉ để dàn đều. Các tấm gần kín bởi chi tiết lớn có thể không nhận thêm chi tiết nhỏ; chỉ đổi hướng vân khi người dùng mở khóa vật liệu hoặc cho phép riêng. Trên hình thu nhỏ có số chi tiết nhỏ/tổng số và dấu tấm hai mặt. Hai ưu tiên có thể bật/tắt ở ⚙ → Post TAM AN.
- **Khoan, rãnh, hốc, khử góc chạy trước; mọi đường cắt ngoài ở cuối** cả trong bảng và NC. Tùy chọn cắt ngoài trước của bản cũ không còn được áp dụng. Thứ tự mặc định: chi tiết nhỏ/hẹp trước, tăng dần theo diện tích; cùng cỡ ưu tiên từ mép tấm vào trong. Có thêm lựa chọn ưu tiên ngoài → trong trước kích thước.
- **Tối ưu thứ tự / vào dao** tính lại thứ tự trên sơ đồ hiện tại. Điểm tự động xét phần phôi chưa cắt và độ dài đoạn đầu, rồi chọn điểm vào/kết thúc về phía còn phôi. Dấu đỏ là vào dao, xanh là kết thúc khi đã tạo NC. Đây là đánh giá hình học, không tính được lực hút giữ thực tế. Chọn một trong tám điểm thủ công hoặc bấm **Tự chọn vào dao / giữ phôi** để quay lại tự động.
- Kéo chi tiết bắt dính vào mép chi tiết lân cận với **khe 5.5 hoặc 10 mm** đúng theo loại chi tiết, cùng đường gióng và biên ván. Cài khoảng bắt dính theo pixel. Thuộc tính hiện khoảng trống bốn phía. Đường gióng lấy mốc tuyệt đối, từ điểm neo, mép hoặc tâm chi tiết; có nút gióng bốn mép.
- Mô phỏng tính thời gian từ chiều dài đoạn NC và feed. Mặc định **0.25×**, có 0.05×/0.1× và các mức khác; chuyển động nội suy giữa hai đầu đoạn. ⚙ lưu tốc độ mặc định và tốc độ G00 dùng để xem; thay đổi này không sửa feed gia công.
- BOM có ID, tên, nhóm, vật liệu, độ dày, rộng, cao, tấm, số cắt, trạng thái; liệt kê cả chi tiết quá khổ chưa xếp. Có tìm kiếm, in bảng và CSV. Kích thước danh nghĩa được giữ trước khi hợp mộng vào biên. Nếu không có prefix nhóm thì dùng tên nhóm/component cha.
- Cài đặt post, điểm neo, trục Y, thư viện dao và thông số mô phỏng được lưu qua lần mở SketchUp sau. Bổ sung đầu/cuối chương trình cho cả hai mặt, cờ dao khoan/chỉ khoan và lệnh đổi/tắt dao.
- Giao diện có hình thu nhỏ ngay ở Xếp tấm, chữ tự vừa chi tiết, bảng cắt ngoài được đánh dấu cuối, và ngăn Thuộc tính/Gióng đóng mở được ở cửa sổ nhỏ.

## Cài và sử dụng

1. Trong SketchUp 2023 trở lên: Extension Manager → Install Extension → chọn `HP_Tool_One_Click_0.6.0_beta.rbz`. Khởi động lại SketchUp nếu đang dùng bản cũ.
2. Mở Extensions → HP Tool One Click hoặc nút trên thanh công cụ cùng tên.
3. Nhập **Tên công trình**, **Mã công trình**, chọn **Mẫu tem**. Bấm ⚙ để chỉnh cài đặt, post, thư viện dao, quy tắc layer và thiết kế tem. Post mặc định theo setting TAM AN đã cung cấp, dao cắt **T2 Ø5**, bàn hút chân không.
4. Chọn cụm tủ trong model rồi **Tải dữ liệu và xếp tấm**. Có thể đọc model trước rồi xếp, hoặc nhập `nesting.data` của One Click. Đổi quy tắc layer, thư viện dao hoặc khổ ván sẽ yêu cầu đọc/xếp lại.
5. Xem danh sách lỗi ở Công trình. Tấm quá khổ giữ nguyên để bạn xử lý; không tự chia. Những liên kết chưa nhận dạng hoặc dữ liệu không đủ được báo và chặn xuất bộ NC thiếu.
6. Trong **Tối ưu**, kéo chi tiết; xoay/lật mặt; sửa tên/nhóm; đặt số cắt, hướng cắt và một trong tám điểm vào dao; chọn tab giữ phôi trên/dưới/trái/phải. Có hoàn tác/làm lại, thêm tấm trống, chuyển chi tiết sang tấm khác, xóa tấm trống, đường gióng, thước đo, phóng to và các tùy chọn hiển thị. Chi tiết có vân xoay khi mở khóa vật liệu hoặc cho phép đổi vân riêng. Lật mặt đổi cả hình học và các đường gia công hai mặt.
7. **Bố cục** hiển thị sơ đồ, số cắt và chi tiết để kiểm tra/in. **BOM** tổng hợp số tấm vật liệu, chi tiết, phụ kiện nhận dạng, nẹp dán cạnh và vùng gia công/rãnh LED/rãnh hậu; có nhập vật tư bổ sung và xuất CSV tiếng Việt. Chiều dài nẹp được đọc từ các mặt cạnh có metadata, không suy đoán từ toàn bộ chu vi.
8. **Tem nhãn** xem và in tem. Trong ⚙ → Thiết kế tem, sửa khổ tem, chữ/biến nội dung, vị trí, kích thước, cỡ chữ, đậm, góc xoay; kéo trường, thêm QR/mã vạch, nhân bản mẫu và hoàn tác/làm lại. Mặc định P1 60 × 40 mm; PDF dùng Noto Sans nhúng có dấu tiếng Việt. QR tạo ngoại tuyến; Code128 dùng ID/số ASCII. Tem có tên/mã công trình, vật liệu, tên/nhóm chi tiết, kích thước, số tấm và số cắt.
9. Trong **Xuất G-code**, sửa dao, ưu tiên, độ sâu, số lượt, lượt tùy chỉnh (ví dụ `6;12;17.7`), kiểu gia công và khử góc. Bấm **Tạo G-code và mô phỏng**; các ô đang chỉnh được áp dụng trước khi tạo mã. Biên ngoài theo số cắt ở Tối ưu; ưu tiên trong bảng áp dụng cho nhóm gia công bên trong. Toàn bộ lỗ/rãnh và khử góc chạy trước biên ngoài; cắt ngoài luôn ở cuối.
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

MaxRects thử nhiều thứ tự, cách ghép tấm dài/ngắn, dành chỗ cho chi tiết nhỏ và xếp lại từng cặp trong cùng số tấm; tách vật liệu/độ dày; có dùng ván tận dụng theo khổ/số lượng nhập; chưa xếp vào lỗ rỗng hay cắt cạnh chung. Không khẳng định tối ưu toàn cục. Khổ mặc định 1220 × 2440, biên 5, khe 5.5, chi tiết nhỏ cách 10 mm. Tấm quá khổ giữ nguyên và báo để xử lý.

Dao cắt T2 Ø5, bù bán kính 2.5 mm; X âm từ góc dưới phải, Y dương, Z0 bàn máy; Z nâng bằng độ dày + 40 mm, xuyên sâu thêm 0.2 mm. Post dùng G90/G54, đặt G21/G17/G40/G80; đổi dao/spindle theo setting. Feed 12000, xuống Z giới hạn 6000, đoạn cung ngắn 5000, giảm tốc cuối biên 3000/120 mm. Biên ngoài mặc định hạ chéo một chiều; có chế độ qua lại để giữ góc tối đa. Đường không đủ khoảng vào dao được báo khoảng cách thực tế hoặc chặn nếu không tìm được đoạn thẳng hợp lệ. Các đường hốc/vector vẫn dùng ramp theo đường và cần chọn số lượt phù hợp. Đường tròn/hốc dùng G01 với sai số dây cung lỗ tính toán khoảng 0.005 mm. Tab theo vị trí bạn chọn, không tự thêm.

Hai mặt: chạy `bottom` trước khi tách chi tiết, lật **cả tấm** quanh Y và đăng ký lại G54, sau đó `top`. Phép lật/gốc phôi phải đối chiếu trên máy. Mô phỏng hiển thị đường dao, không mô phỏng đầy đủ cơ cấu máy, G53 hoặc tín hiệu M-code; chưa có xác nhận bộ điều khiển cụ thể.

Chức năng tối ưu khoan NC cũ chỉ đổi thứ tự các khối khoan độc lập, giữ sơ đồ, dao, feed và toàn bộ lệnh gốc; không gán sơ đồ xếp mới vào NC cũ.

## Kiểm thử và mã nguồn

Mẫu TES 87 chi tiết: 17 tấm, 21 NC, kiểm tra độc lập 7.604 chuyển động cắt trong chế độ một chiều và 44 vùng hốc; khoảng hở đến chi tiết bên cạnh tối thiểu 0,5 mm. Có ca ván tận dụng 200 × 2200 mm, kiểm tra gốc NC, gióng theo khổ thật và mở lại `.data`. Mẫu 136 chi tiết/32 vùng layer ngoài được xếp trên 21 tấm vật liệu và sinh 29 NC. Có kiểm tra độc lập bằng GEOS: bù dao, bao đủ biên ngoài/vùng hốc, khoảng hở đến chi tiết bên cạnh, XYZ/feed và nâng dao. Kết quả số chuyển động ở báo cáo kiểm thử riêng; không phải xác nhận máy thực tế. Mẫu nesting cũ giữ đủ 629 chi tiết, xếp 95 → 94 tấm theo setting; không đồng nghĩa toàn bộ dữ liệu cũ đều chuyển CAM được.

Đã kiểm tra chỉnh sơ đồ qua Ruby, thứ tự/lượt cắt, lật mặt, tab trong NC, BOM, mô phỏng, xuất thư mục, PDF 136 tem (giải mã QR/Code128 và trích chữ tiếng Việt độc lập), `.data` lưu/mở lại và mở thư mục. Chưa thử SketchUp Desktop/CNC thực tế.

Nguồn Ruby/HTML/JS ở `src/`. Kiểm thử: `tests/core_test.rb`, `formula_test.rb`, `job_export_test.rb`, `nesting_v4_test.rb`, `nesting_v5_test.rb`, `manual_edit_refresh_test.rb`, `node tests/cam_test.js`, `node tests/workbench_engine_test.js`, `node tests/retention_v4_test.js`, `node tests/cam_v5_test.js`; tích hợp `app_smoke.rb`, `workbench_smoke.py`, `workbench_v5_smoke.py`, `manual_edit_refresh_browser.py`, `tes_reference_check.py` dùng bộ model riêng không đóng gói. `ui_smoke.py` chạy bài giao diện hiện tại. Ruby cloud ở `/workspace/cloud-setup/bin/ruby`; các phép kiểm tra hình học/PDF độc lập cần Shapely, PyMuPDF, Pillow, zxing-cpp; giao diện dùng Python Playwright và Chromium.

Bộ cài chứa nguồn độc lập và thư viện có giấy phép: Clipper (Boost), QR/JsBarcode/jsPDF (MIT), Noto Sans (OFL). Không chứa model khách hàng, RBZ/RBE gốc hay thông tin đăng nhập. Các gói One Click đã đọc có phần Ruby chính mã hóa RBE; HP Tool không giải mã hoặc thay đổi khóa tài khoản của phần mềm gốc.
