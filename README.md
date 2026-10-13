# NahtKey

Bộ gõ tiếng Việt cho macOS, hỗ trợ VNI, Telex và thư viện sửa lỗi cá nhân.

## Hướng dẫn

Yêu cầu **Mac Apple Silicon (M1 trở lên), macOS 14 trở lên**.

1. Tải `NahtKey-0.4.0-macos-arm64.zip` tại [GitHub Releases](https://github.com/VN-Levie/NahtKey/releases/latest), giải nén và kéo **NahtKey.app** vào **Applications**.
2. Mở NahtKey và cấp **quyền Trợ năng** khi được yêu cầu.
3. Chọn nguồn nhập **ABC**, tắt bộ gõ tiếng Việt khác, rồi chọn **VNI** hoặc **Telex** trong NahtKey.

Bản phát hành chưa có notarization. Nếu macOS chặn lần mở đầu, vào **System Settings → Privacy & Security → Open Anyway** theo [hướng dẫn của Apple](https://support.apple.com/en-us/102445).

Khi cập nhật, chọn **Thoát hoàn toàn NahtKey** trong menu bar trước khi thay ứng dụng.

## Sử dụng

- **Ctrl+Shift:** bật/tắt tiếng Việt. Icon có nét gạch khi tắt.
- Nhấn icon menu bar → **Mở NahtKey…** để quản lý từ và cài đặt.
- **X** hoặc **Cmd+Q:** ẩn cửa sổ, bộ gõ tiếp tục chạy nền. App không hiện trong Dock.
- Bật **Khởi động cùng macOS** để chạy ở menu bar khi đăng nhập, không tự mở cửa sổ.
- Quay lại sửa từ: `go` + Space + Backspace + `4` → `gõ`; `nhận` + Space + Backspace + `4` → `nhẫn`. Telex dùng `x` thay `4`.

## Thư viện cá nhân

Thêm các cặp sửa lỗi như `abn5 → bạn`, `ab5n → bạn` hoặc `càu → của`. Quy tắc được áp dụng khi kết thúc từ bằng Space, dấu câu, Tab hoặc Enter.

- Thêm, sửa, xóa và tìm kiếm từ. Các mục mẫu có thể sửa hoặc xóa.
- Cả hai ô thêm/sửa đều gõ VNI/Telex trực tiếp; nội dung dán được giữ nguyên.
- Chuỗi cần sửa dài 1–64 chữ cái/chữ số, có thể có dấu; từ thay thế dài 1–128 ký tự. Không chứa khoảng trắng, có phân biệt hoa/thường.
- **Xuất…** lưu thư viện thành file JSON; **Nhập…** gộp file vào thư viện đang dùng. Để chuyển sang máy khác, xuất file rồi nhập trên máy đó.
- Mục trùng tự gộp. Nếu khác từ thay thế, **giá trị trong file nhập được ưu tiên**; nếu trùng ngay trong file, dòng cuối thắng.
- File nhập tối đa **4 MiB**. File lỗi không làm thay đổi thư viện.

## Kiểu gõ và lưu ý

| Kiểu gõ | Phím |
|---|---|
| VNI | Dấu thanh `1–5`, mũ `6`, móc `7`, trăng `8`, đ `9`, bỏ dấu `0` |
| Telex | `aa/aw/ee/oo/ow/uw/dd`, dấu thanh `s/f/r/x/j`, bỏ dấu `z` |

Ví dụ: `ban5 → bạn`, `uu7 → ưu`, `chu7a → chưa`, `d9c → đc`, `dt9 → đt`.

- VNI giữ nguyên các chuỗi như `matkhau123`, `model123`. Telex chưa có tính năng nhận diện mã tương đương.
- Chuỗi như `a4`, `ban5` vẫn được hiểu là tiếng Việt. Tắt bộ gõ khi muốn nhập nguyên văn.
- Cách đặt dấu hiện dùng `hòa`, `khỏe`, `thủy`. Khả năng sửa từ khi di chuyển con trỏ phụ thuộc ứng dụng đang dùng.
- Khi macOS bật Secure Event Input, NahtKey không xử lý phím. Một số trình soạn thảo hoặc game có thể chưa tương thích.

NahtKey xử lý cục bộ, không ghi nhật ký phím hoặc gửi nội dung gõ lên mạng.

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
