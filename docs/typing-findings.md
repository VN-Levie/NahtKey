# Các trường hợp hồi quy

Các ví dụ dưới đây dùng để kiểm tra bộ gõ khi cập nhật.

## Ghép dấu và sửa từ

| Cách gõ VNI | Kết quả |
|---|---|
| `d9a4` | đã |
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

Các bài học về ghép dấu, giữ thứ tự phím và tương thích trình soạn thảo được tham khảo từ OpenKey, GoNhanh, XKey và VietTelex. Xem [credit và giấy phép](../README.md#credit-và-các-dự-án-tham-khảo). NahtKey triển khai bằng Swift riêng.
