# Các trường hợp hồi quy

Các ví dụ dưới đây dùng để kiểm tra bộ gõ khi cập nhật.

## Ghép dấu và sửa từ

| Cách gõ VNI | Kết quả |
|---|---|
| `d9a4` | đã |
| `bao3` | bảo |
| `dau962` | đầu |
| `chu7a`, `chua7` | chưa |
| `cu7a`, `cua7` | cưa |
| `mu7a`, `mua7` | mưa |
| `uu7` | ưu |
| `huou7` | hươu |
| `luoi74` | lưỡi |
| `d9c`, `dc9` | đc |
| `dt9`, `d9t` | đt |
| `matkhau123`, `model123` | Giữ nguyên |
| `abn5`, `ab5n` rồi Space | bạn + Space, khi có quy tắc tương ứng |
| `go` + Space + Backspace + `4` | gõ |
| `nhận` + Space + Backspace + `4` | nhẫn |

Thử thêm Telex, chữ hoa, dấu lặp, Backspace và nhập ở đầu ô trống hoặc sau khi chọn hết/xóa.

Ở ô tìm kiếm có danh sách kết quả, thử `bao3 bao3 bao3` và `dau962 dau962` ngay từ đầu ô. Kết quả gợi ý xuất hiện hoặc đổi mục đang chọn không được làm mất phần từ đang gõ. Chuyển sang ô khác, chọn hết/xóa rồi gõ lại vẫn phải bỏ ngữ cảnh cũ.

## Tùy chọn và gõ xen kẽ

- VNI `hoa2n` / Telex `hoafn` rồi Backspace → `hòa`; `tuy2a` / `tuyfa` rồi Backspace → `tùy`. Tắt chỉnh dấu sau xóa phải giữ vị trí dấu cũ. Thử cả hai cách đặt dấu.
- Khi bật khôi phục Telex: `user`, `office`, `useEffect`, `JavaScript` + Space phải trở lại phím gốc; `tieengs Vieetj`, `chuwa`, `muwa`, `uuw` vẫn thành tiếng Việt.
- `test` là chuỗi mơ hồ và vẫn thành `tét`; bật khôi phục bằng Esc để lấy lại `test`. Không khôi phục phím sau Backspace hoặc khi sửa lại từ cũ. Esc khi không cần khôi phục vẫn đi tới ứng dụng.
- Bật/tắt khôi phục Telex không được thay đổi kết quả VNI. Kiểm tra dấu lặp, chữ hoa, giới hạn token và ưu tiên từ cá nhân.
- Backspace ở ô trống hoặc xóa hết từ rồi gõ `cau3` (VNI) / `caur` (Telex) phải áp dụng `cảu → của` khi kết thúc từ. Kiểm tra cả khi gõ tắt cụm từ bật/tắt. Khi chỉ xóa một phần hoặc quay lại từ cũ, không đoán lại chuỗi phím gốc.
- Khi bật khôi phục Telex, `push`, `fix`, `release`, `text`, `next`, `sort`, `port`, `class`, `press` phải giữ nguyên sau Space hoặc dấu câu, kể cả sau khi xóa hết từ cũ. `tets → tét`, `boojt → bột`, `hojc → học`, `ass → as`, `aaa → aa` vẫn giữ cách gõ hiện có.
- Với `abn5 → bạn` và `cảu → của`: `Abn5`/`ABN5` → `Bạn`/`BẠN`, `Cau3`/`CAU3` → `Của`/`CỦA`; `aBn5` và `cAu3` giữ nguyên. Thêm `Kai → Kai` thì `Kai` giữ nguyên còn `kai`/`KAI` vẫn theo `kai → kia`.
- Quy tắc phím gốc ưu tiên hơn quy tắc Unicode; cả hai ưu tiên hơn khôi phục tiếng Anh. Khi tắt gõ tắt cụm từ, chỉ bỏ các mục có khoảng trắng trong nội dung thay thế, không bỏ quy tắc một từ.
- Gõ nhanh `push fix release text next sort` trong ô tìm kiếm có gợi ý. Sau Space/dấu câu đã biết, không đọc lại từ cũ từ Accessibility có thể trễ; các phím `f/r/s` đầu từ mới không được nối vào từ trước. Di chuyển con trỏ về từ cũ vẫn cho phép đọc lại ngữ cảnh đã xác minh.
- Gõ tắt cụm câu chỉ hoạt động khi bật tùy chọn; các sửa lỗi một từ vẫn hoạt động. Nhập/xuất phải giữ cả mục cụm câu khi tùy chọn tắt; từ chối tab, xuống dòng, điều khiển và khoảng trắng đầu/cuối.
- Ghi nhớ ứng dụng mặc định tắt. Khi bật, đổi qua lại hai ứng dụng phải giữ trạng thái riêng; mở NahtKey không tạo profile mới. Tắt tùy chọn phải khôi phục trạng thái chung.
- Kiểm tra Ctrl+Shift, Cmd+Shift, Ctrl+Option và tắt phím chuyển; tổ hợp có thêm phím/kéo chuột không được đổi chế độ.
- Menu bar **Thêm từ…** phải mở thẳng biểu mẫu, kể cả khi cửa sổ đang ẩn; gọi lại không xóa nội dung đang nhập dở.

## Gõ nhanh và chồng phím

- Gõ `chu`, giữ `a`, nhấn `7` trước khi thả `a`: kết quả phải là `chưa`. Thử tương tự với `mưa`, `cưa` và các tổ hợp giữ `a/e` với dấu VNI `0–9`.
- Gõ nhiều từ liên tiếp, kiểm tra không mất phụ âm đầu hoặc dấu cách giữa các từ.
- Giữ phím để lặp rồi thả: không được để ứng dụng tiếp tục nhận phím lặp sau khi đã thả.

## Giao diện và thư viện

- Hai ô thêm/sửa từ đều nhận VNI/Telex; Tab chỉ chuyển ô, Hủy không lưu.
- Nhập/xuất giữ nguyên dữ liệu. Mục trùng được gộp; khi khác từ thay thế, ưu tiên giá trị trong file nhập. File lỗi không làm thay đổi thư viện.
- Ctrl+Shift bật/tắt; nhấn icon mở menu ngay. Đóng cửa sổ vẫn giữ bộ gõ chạy nền.
- Khi bật khởi động cùng macOS, đăng nhập chỉ mở menu bar, không tự mở cửa sổ hoặc thêm icon Dock.

Chạy `swift test` cho kiểm thử tự động. Dùng [trang thử bàn phím](keyboard-test.html) hoặc trình soạn thảo để kiểm tra phím thật; kết quả có thể khác giữa các ứng dụng.

## Tham khảo

### Thanh địa chỉ Safari và gợi ý được chọn

Kiểm tra riêng danh sách gợi ý và **hậu tố địa chỉ được Safari bôi chọn**. Hai trạng thái này không tương đương. Có thể dùng các trang loopback `chu.localhost` và `uu.localhost` để tạo hậu tố có thể kiểm soát; không dùng dữ liệu duyệt web cá nhân làm fixture.

- `chu` + hậu tố được chọn + Backspace + VNI `7a` / Telex `wa` phải thành `chưa`. Lặp thêm khi Backspace đến ngay sau chuỗi gõ nhanh.
- Gõ nhanh `uu7`, `chu7a`, `uuw`, `chuwa` không được thành `uưu`, `chuưa`.
- Kiểm tra lại từ đã ghép dấu, bỏ dấu, Backspace rồi thêm dấu; không giữ nhầm bộ đệm trước khi xóa.
- Thử con trỏ ở giữa nội dung, chọn một phần đuôi bằng bàn phím, và chọn tất cả rồi gõ lại. Phần bên phải con trỏ phải được giữ nguyên khi không nằm trong vùng thay thế.
- Đo khoảng cách thực giữa các phím; thời gian chờ đặt trong script không phải tốc độ thực đo. Xác minh có hậu tố được chọn trước khi tính một ca autocomplete là đã kiểm tra.

Đường sửa dùng **Forward Delete tại cuối thanh địa chỉ đã xác minh**, rồi thực hiện thay chữ thông thường. Thao tác native này bỏ hậu tố gợi ý nếu có và không xóa ký tự khi con trỏ đã ở cuối. Vị trí cuối ô được ghi nhận khi bắt đầu từ và bỏ khi di chuyển con trỏ, đổi focus, dùng phím điều khiển hoặc reset bộ gõ; không quyết định lại bằng ảnh chụp AX có thể trễ ở mỗi phím dấu. Không áp dụng cho giữa nội dung, ô nhập trang web hoặc ứng dụng khác.

Với từ chưa qua thay dấu, nếu đã xác minh hậu tố gợi ý đang được chọn thì giữ bộ đệm và để Backspace xóa gợi ý. Các trạng thái còn lại để Safari xử lý rồi đọc lại từ đang hiện ở phím kế tiếp, vì gợi ý có thể xuất hiện sau ảnh chụp AX. Nếu đọc chưa thành công, cho phím đi qua và tiếp tục phục hồi ở phím sau, không tạo bộ đệm chỉ chứa một phần từ. Từ đã ghép dấu giữ đường chỉnh dấu sau xóa và kiểm tra riêng selection gợi ý.

Safari có thể trả `kAXErrorCannotComplete` khi dựng gợi ý: hạn chờ đọc AX riêng cho Safari là 100 ms, phản hồi sớm thì đi tiếp ngay. Các ứng dụng khác giữ hạn chờ cũ. Không suy đoán số chữ đã bị xóa từ ảnh chụp cũ.

Các hướng đã đối chiếu:

| Hướng | Lý do cân nhắc |
|---|---|
| Thêm Backspace dựa trên ảnh chụp AX | Có thể bỏ sót gợi ý xuất hiện sau thời điểm đọc, gây lặp chữ. |
| Forward Delete có giới hạn ở cuối ô | Xử lý selection tại lúc Safari nhận sự kiện, không cần ký tự vô hình, clipboard hay thời gian chờ cố định. |
| Ký tự rỗng rồi xóa | [OpenKey](https://github.com/tuyenvm/OpenKey/issues/37) và [XKey](https://github.com/xmannv/xkey/releases/tag/v1.2.23-20260608) mô tả hướng này; phụ thuộc trình soạn thảo chấp nhận ký tự tạm và thứ tự xóa. |
| Chọn vùng bằng Shift+Left | [Gõ Nhanh](https://github.com/khaphanspace/gonhanh.org/blob/main/docs/system-architecture.md) dùng đường selection cho autocomplete; cần kiểm soát các ứng dụng xử lý phím chọn vùng khác nhau. |
| Ghi qua Accessibility hoặc thêm delay | Có thể thử nếu đường phím native không đáp ứng, nhưng cần kiểm tra tác động đến gợi ý, undo và độ trễ. |

NahtKey triển khai riêng theo các trạng thái đã đo; không đưa mã của các dự án tham khảo vào ứng dụng.

Các bài học về ghép dấu, giữ thứ tự phím và tương thích trình soạn thảo được tham khảo từ OpenKey, GoNhanh, XKey và VietTelex. Xem [credit và giấy phép](../README.md#credit-và-các-dự-án-tham-khảo). NahtKey triển khai bằng Swift riêng.
