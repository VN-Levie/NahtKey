# NahtKey

Bộ gõ tiếng Việt cho macOS, hỗ trợ VNI, Telex và thư viện sửa lỗi cá nhân.

## Hướng dẫn

Yêu cầu **Mac Apple Silicon (M1 trở lên), macOS 14 trở lên**.

1. Tải `NahtKey-0.5.1-macos-arm64.zip` tại [GitHub Releases](https://github.com/VN-Levie/NahtKey/releases/latest), giải nén và kéo **NahtKey.app** vào **Applications**.
2. Mở NahtKey và cấp **quyền Trợ năng** khi được yêu cầu.
3. Chọn nguồn nhập **ABC**, tắt bộ gõ tiếng Việt khác, rồi chọn **VNI** hoặc **Telex** trong NahtKey.

Bản phát hành chưa có notarization. Nếu macOS chặn lần mở đầu, vào **System Settings → Privacy & Security → Open Anyway** theo [hướng dẫn của Apple](https://support.apple.com/en-us/102445).

Khi cập nhật, chọn **Thoát hoàn toàn NahtKey** trong menu bar trước khi thay ứng dụng.

## Sử dụng

- **Ctrl+Shift:** bật/tắt tiếng Việt. Icon có nét gạch khi tắt.
- Nhấn icon menu bar → **Mở NahtKey…** để quản lý từ và cài đặt.
- Chọn **Thêm từ…** ngay trong menu bar để mở nhanh biểu mẫu. Biểu mẫu đang nhập dở được giữ lại.
- **X** hoặc **Cmd+Q:** ẩn cửa sổ, bộ gõ tiếp tục chạy nền. App không hiện trong Dock.
- NahtKey chỉ chạy một phiên. Mở lại ứng dụng sẽ hiện cửa sổ của phiên đang chạy, giữ nguyên nội dung đang nhập dở.
- Bật **Khởi động cùng macOS** để chạy ở menu bar khi đăng nhập, không tự mở cửa sổ.
- Quay lại sửa từ: `go` + Space + Backspace + `4` → `gõ`; `nhận` + Space + Backspace + `4` → `nhẫn`. Telex dùng `x` thay `4`.

## Thư viện cá nhân

Thêm các cặp sửa lỗi như `abn5 → bạn`, `ab5n → bạn` hoặc `càu → của`. Quy tắc được áp dụng khi kết thúc từ bằng Space, dấu câu, Tab hoặc Enter.

- Thêm, sửa, xóa và tìm kiếm từ. Các mục mẫu có thể sửa hoặc xóa.
- Cả hai ô thêm/sửa đều gõ VNI/Telex trực tiếp; nội dung dán được giữ nguyên.
- Chuỗi cần sửa dài 1–64 chữ cái/chữ số, có thể có dấu, không chứa khoảng trắng.
- Quy tắc viết thường cũng áp dụng cho từ viết hoa chữ đầu hoặc viết hoa toàn bộ, giữ đúng kiểu hoa: `Abn5` → `Bạn`, `ABN5` → `BẠN`. Từ viết hoa lẫn lộn (`aBn5`) không bị sửa. Muốn giữ nguyên một từ viết hoa, ví dụ tên riêng, thêm quy tắc đúng kiểu đó: `Kai → Kai`.
- Ưu tiên quy tắc khớp chuỗi phím gốc, sau đó đến từ đã ghép dấu, rồi mới khôi phục tiếng Anh. Xóa hết từ rồi gõ lại sẽ áp dụng quy tắc như một từ mới.
- Để giữ một từ tiếng Anh mơ hồ, có thể thêm quy tắc `test → test`. Khi đó vẫn gõ được `tét` bằng `tets`.
- Nội dung thay thế dài 1–128 ký tự, có thể là cụm từ hoặc câu; không xuống dòng, không có khoảng trắng đầu/cuối. Bật **Gõ tắt thành cụm từ hoặc câu** trong **Tùy chọn** để áp dụng các mục có khoảng trắng. Các mục thay một từ vẫn hoạt động khi tắt tùy chọn này.
- **Xuất…** lưu thư viện thành file JSON; **Nhập…** gộp file vào thư viện đang dùng. Để chuyển sang máy khác, xuất file rồi nhập trên máy đó.
- Mục trùng tự gộp. Nếu khác từ thay thế, **giá trị trong file nhập được ưu tiên**; nếu trùng ngay trong file, dòng cuối thắng.
- File nhập tối đa **4 MiB**. File lỗi không làm thay đổi thư viện.

## Kiểu gõ và lưu ý

| Kiểu gõ | Phím |
|---|---|
| VNI | Dấu thanh `1–5`, mũ `6`, móc `7`, trăng `8`, đ `9`, bỏ dấu `0` |
| Telex | `aa/aw/ee/oo/ow/uw/dd`, dấu thanh `s/f/r/x/j`, bỏ dấu `z` |

Ví dụ: `ban5 → bạn`, `uu7 → ưu`, `chu7a → chưa`, `d9c → đc`, `dt9 → đt`.

- VNI giữ nguyên các chuỗi như `matkhau123`, `model123`.
- Chuỗi như `a4`, `ban5` vẫn được hiểu là tiếng Việt. Tắt bộ gõ khi muốn nhập nguyên văn.
- Mặc định đặt dấu `hòa`, `khỏe`, `thủy`, và chỉnh lại vị trí dấu sau Backspace, như `hoàn` xóa `n` thành `hòa`. Có thể đổi cách đặt dấu hoặc tắt việc chỉnh dấu trong **Tùy chọn**. Khả năng sửa từ khi di chuyển con trỏ phụ thuộc ứng dụng đang dùng.
- Khi macOS bật Secure Event Input, NahtKey không xử lý phím. Một số trình soạn thảo hoặc game có thể chưa tương thích.

NahtKey xử lý cục bộ, không ghi nhật ký phím hoặc gửi nội dung gõ lên mạng.

## Tùy chọn

Các tiện ích sau mặc định tắt:

- **Khôi phục tiếng Anh và mã khi gõ Telex:** bật để khôi phục các chuỗi không hợp lệ trong tiếng Việt khi kết thúc từ, như `push`, `fix`, `release`, `text`, `next`, `class`, `user`, `useEffect`. Không tác động VNI; chuỗi mơ hồ như `test → tét` vẫn giữ dấu nếu chưa có quy tắc cá nhân.
- **Esc khôi phục chuỗi phím:** nhấn trước khi kết thúc từ để lấy lại phím gốc trong cả VNI và Telex. Không khôi phục sau khi đã xóa hoặc quay lại sửa từ cũ. Khi không có chuỗi cần khôi phục, Esc hoạt động bình thường.
- **Nhớ bật/tắt theo ứng dụng:** lưu trạng thái riêng khi bạn chủ động bật/tắt. Tắt tùy chọn để trở lại trạng thái chung; kiểu gõ VNI/Telex luôn dùng chung.
- **Gõ tắt thành cụm từ hoặc câu:** dùng các mục nhiều từ trong thư viện cá nhân.

Phím chuyển mặc định **Ctrl+Shift**; có thể chọn **Cmd+Shift**, **Ctrl+Option** hoặc tắt phím chuyển. Tổ hợp đang dùng cho lệnh khác không làm đổi chế độ gõ.

## Phát triển

Mã nguồn dùng Swift và SwiftUI, không có package ngoài. Cần Xcode 26 trở lên để biên dịch icon.

```sh
swift test
./scripts/build-app.sh
# Thoát hoàn toàn NahtKey trước khi cài:
./scripts/install-local.sh
open /Applications/NahtKey.app
```

App được tạo tại `dist/NahtKey.app`. Dùng `./scripts/package-release.sh` để tạo ZIP Apple Silicon và checksum. Xem [cấu hình ký mã](docs/code-signing.md) và [các trường hợp kiểm thử](docs/typing-findings.md).

## Credit và các dự án tham khảo

Cảm ơn các dự án đã chia sẻ mã nguồn và kinh nghiệm xử lý bộ gõ:

| Dự án | Nội dung tham khảo | Giấy phép gốc |
|---|---|---|
| [OpenKey — Mai Vũ Tuyên](https://github.com/tuyenvm/OpenKey) | Tương thích trình soạn thảo, tự hoàn thành và sửa từ | [GPL-3.0](https://github.com/tuyenvm/OpenKey/blob/master/LICENSE) |
| [GoNhanh — khaphanspace](https://github.com/khaphanspace/gonhanh.org) | Giữ dấu cách và dấu phân cách khi sửa từ | [BSD-3-Clause](https://github.com/khaphanspace/gonhanh.org/blob/main/LICENSE) |
| [XKey — xmannv](https://github.com/xmannv/xkey) | Giữ thứ tự giữa thay chữ và phím tiếp theo | [MIT](https://github.com/xmannv/xkey/blob/main/LICENSE) |
| [VietTelex — Phil Trinh](https://github.com/ptrinh/viettelex) | Kiểm tra âm tiết và giữ chuỗi mã nguyên văn | [MIT](https://github.com/ptrinh/viettelex/blob/main/LICENSE) |

NahtKey triển khai bằng Swift riêng, không nhập trực tiếp engine hoặc từ điển từ các dự án trên. EVKey được tham khảo qua tài liệu và issue công khai.

## Giấy phép

[MIT License](LICENSE). Các dự án tham khảo giữ nguyên giấy phép của từng dự án.
