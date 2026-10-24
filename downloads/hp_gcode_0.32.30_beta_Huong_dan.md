# hp gcode 0.32.30 beta

## Sửa lỗi mất sơ đồ và điểm xuống dao

- Sửa lỗi `Cannot read property 'set' of undefined` khi mã vật liệu có 0 tấm. Vùng chọn được khởi tạo trước khi vẽ; nút tối ưu tấm chọn tự tắt khi không có tấm.
- Chi tiết quá khổ/chưa xếp trong cùng mã vẫn được báo và chặn xuất NC đầy đủ, nhưng không xóa đường dao của tấm đã xếp hợp lệ.
- Điểm đỏ xuống dao, vòng xanh kết thúc và mũi tên chữ L hai cạnh lấy từ đường dao đã tính. Giữ trạng thái khi chuyển mã, tấm và trang Bố cục.

## Thứ tự cắt và cạnh chốt

Mặc định giữ chế độ ngoài vào trong, tấm lớn cuối. Trước mỗi lượt, xét nhóm chi tiết chưa cắt còn nối với tấm lớn hoặc vùng phôi dư hay không; giữ lại chi tiết làm cạnh đỡ khi việc cắt nó sẽ cô lập nhóm bên cạnh. Vì vậy một chi tiết trong có thể chạy trước chi tiết đỡ cuối cùng của nó. Không mặc định phải sang trái.

Điểm tự động so sánh các cạnh thẳng hợp lệ: đoạn hạ dao có chỗ bám, chiều dài cạnh còn nối phôi liên tục, rồi lượng phôi bên cạnh. Tính cả đường đã cắt và bề rộng dao; ưu tiên hướng tâm hoặc cách góc chỉ dùng khi các phương án giữ phôi tương đương. Chọn tay 8 vị trí và hướng CW/CCW vẫn được giữ; yêu cầu 100 mm giữ được khi cạnh đủ dài. Cạnh ngắn có thể phải rút ngắn đoạn hạ dao và báo vị trí thực tế.

Kiểm tra 4 mẫu: 708 chi tiết / 100 tấm đều tạo được xem trước cắt biên; dữ liệu hình học và gia công nguồn không đổi, nhóm lớn vẫn cuối. Tổng chiều dài cạnh chốt còn nối phôi liên tục tăng khoảng 11,3% theo phép đo hình học của bộ kiểm tra. Đây không phải số đo lực hút hoặc chứng nhận chạy CNC thực tế. Một số chi tiết lớn cuối tấm không còn nhiều phôi quanh nó: xem thông số cạnh chốt và khả năng giữ phôi thực tế.

## Máy chỉ có dao đứng: khoan cạnh làm riêng

Theo cấu hình máy đã xác nhận, Post mặc định **Khoan cạnh → Máy dao đứng · khoan cạnh làm riêng**. Các lỗ này không sinh lệnh khoan ngang hoặc đổi thành khoan đứng. Khi xuất bộ công trình, thư mục `nesting` có `KHOAN_CANH_LAM_RIENG.csv` và `.json`: ID chi tiết, ID tấm, ID lỗ, đường kính, độ sâu, khoảng cách và dữ liệu nguồn được giữ để gia công riêng. Tâm gốc trong bảng không phải tọa độ NC.

Có thể chọn **Chặn NC khi có khoan cạnh chưa hỗ trợ** nếu công việc yêu cầu dừng để kiểm tra. Các loại gia công khác chưa chuyển được vẫn báo đúng ID và chặn xuất đầy đủ; không tự bỏ chúng để làm bộ NC trông hoàn thành.

## Cài và kiểm tra

1. Cài `hp_gcode_0.32.30_beta.rbz` trong Extension Manager; thoát hẳn SketchUp rồi mở lại.
2. Nhập `.data` và xếp lại. Với phương án đang lưu, bấm **Tối ưu thứ tự / vào dao** để tính theo quy tắc mới.
3. Trong **Tối ưu**, bật **Vào dao**, chọn tấm và kiểm tra điểm đỏ/mũi tên L. Thuộc tính chi tiết hiển thị chiều dài cạnh còn nối phôi ước tính.
4. Xử lý các lỗi có ID trước khi xuất đầy đủ. Chọn khoan cạnh làm riêng sẽ kèm bảng riêng khi xuất bộ công trình.

Giữ tên hp gcode, cấu hình/post/dao/layer/mẫu tem cũ, chức năng Gọn tem One Click và các sửa khởi động nhẹ, dừng tác vụ, chuyển model của bản trước. Chưa chạy thử trên SketchUp Desktop hoặc CNC trong môi trường kiểm tra này.
