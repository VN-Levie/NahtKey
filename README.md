# NahtKey

Bộ gõ VNI/Telex cho macOS, viết mới bằng Swift và SwiftUI. Bản 0.2.1 bổ sung sửa lại từ trước con trỏ và chốt dấu cách cùng giao dịch trên trình duyệt, bên cạnh Telex, logo và chế độ chạy nền của 0.2.

## Dùng bản đầu

Ứng dụng đã build nằm tại `dist/NahtKey.app`. Bản cài trên máy nằm tại `/Applications/NahtKey.app`.

1. Mở NahtKey.
2. Bấm **Cấp quyền Trợ năng…**, cho phép **NahtKey** trong System Settings → Privacy & Security → Accessibility (tên mục có thể khác theo phiên bản macOS).
3. Chọn nguồn nhập **ABC**, tắt chế độ tiếng Việt của bộ gõ khác, chọn **VNI** hoặc **Telex** rồi bật **Bật bộ gõ** trong NahtKey.
4. Gõ ở ứng dụng cần dùng. `ban5` → `bạn`. `abn5` hoặc `ab5n` + Space → `bạn `.
5. Dùng icon NahtKey trên menu bar để bật/tắt bộ gõ, đổi VNI/Telex hoặc mở bảng từ cá nhân.
6. Bấm **X** hoặc **Cmd+Q** để ẩn cửa sổ và icon Dock, vẫn giữ bộ gõ chạy. Chọn **Thoát hoàn toàn NahtKey** trong menu bar để thoát thật.

NahtKey khởi động với bộ gõ tắt. Bảng từ và ô thử VNI hoạt động trước khi cấp quyền. Ô thử dùng cùng lõi xử lý, nhưng không thay thế việc kiểm tra bắt phím trong ứng dụng khác.

## Bảng sửa lỗi cá nhân

- Thêm, sửa, đổi chuỗi gõ nhầm, xóa có xác nhận và tìm kiếm.
- Chuỗi gõ nhầm gồm chữ cái ASCII/chữ số, dài 1–64 ký tự, phân biệt hoa/thường.
- Từ thay thế dài 1–128 ký tự, không có khoảng trắng hoặc ký tự điều khiển.
- So khớp đúng chuỗi phím gốc, sửa khi gặp Space, dấu câu, Tab hoặc Enter; không đoán từ gần giống.
- 13 quy tắc ban đầu, gồm `abn5/ab5n → bạn`, `haoc85/haoc75 → hoặc`, `torng → trong`; xem [ghi nhận lỗi gõ](docs/typing-findings.md). Khi nâng cấp từ 0.1, bổ sung một lần và bảo toàn các mục người dùng đã sửa; không tự thêm lại mục đã xóa.
- Dữ liệu: `~/Library/Application Support/NahtKey/corrections.json`.
- Ghi tệp nguyên tử trước khi cập nhật giao diện. Nếu tệp không đọc được, ứng dụng báo lỗi và giữ nguyên tệp thay vì ghi đè.

## Kiểu gõ và giới hạn của bản 0.2

Lõi hỗ trợ dấu thanh `1–5`, mũ `6`, móc `7`, trăng `8`, đ `9`, bỏ dấu/hình dấu `0`, thứ tự dấu linh hoạt, chuyển vị trí dấu khi thêm chữ, chữ hoa và Backspace theo ký tự hiển thị.

Telex hỗ trợ `aa/aw/ee/oo/ow/uw/dd`, dấu `s/f/r/x/j`, bỏ dấu `z`, chữ hoa và gõ dấu linh hoạt. Các nhóm như `uu7/uuw → ưu`, `huou7/huouw → hươu`, `luoi74/luoiwx → lưỡi` có kiểm thử hồi quy.

- Chưa có tự nhận biết tiếng Anh hoặc kiểm tra chính tả. Tắt VNI khi nhập mã/tên chứa chữ và số nếu cần giữ nguyên.
- Cách đặt dấu `hòa`, `khỏe`, `thủy` hiện cố định.
- Sau Backspace, vẫn tiếp tục ghép dấu nhưng tạm bỏ so khớp chuỗi phím gốc cho tới từ kế tiếp, vì lịch sử phím đã không còn tương ứng trực tiếp với chữ hiển thị.
- Bộ đệm giới hạn 128 ký tự đầu vào mỗi từ; chuỗi dài hơn được chuyển tiếp nguyên trạng tới ranh giới từ kế tiếp.
- Không xử lý trường mật khẩu khi macOS bật Secure Event Input. Chuyển ứng dụng, điều hướng con trỏ, click chuột và các tổ hợp Command/Control/Option hủy từ đang theo dõi.
- Giao diện quản lý từ của NahtKey nhận chuỗi phím nguyên văn; ô thử VNI là nơi thử chuyển đổi trong chính ứng dụng.
- Trên các browser được nhận diện và Codex/ChatGPT desktop, thay phần đuôi bằng selection có ký tự tạm bảo vệ autocomplete, thay vì xóa trống chữ đầu tiên. Native editor giữ cách Backspace. Ký tự tạm được chọn và thay ngay trong cùng giao dịch.
- Tắt suppression phím thật khi phát phím tổng hợp, và theo dõi thay đổi focus. Lõi xử lý từng phím tăng dần thay vì phát lại toàn bộ chuỗi.
- Vẫn cần kiểm tra thực tế từng ứng dụng. Không cam kết mọi trình soạn thảo, ô tự hoàn thành hay game đều tương thích.
- Chưa có tự chạy khi đăng nhập, nhập/xuất qua giao diện hoặc phím tắt bật/tắt toàn hệ thống. Cmd+Q là ẩn ứng dụng, không phải phím đổi chế độ.

Ứng dụng không ghi nhật ký phím, không dùng clipboard để thay chữ và không gọi dịch vụ mạng. Chỉ từ điển do người dùng quản lý được lưu xuống đĩa.

## Phát triển

Yêu cầu macOS 14 trở lên và Xcode/Swift toolchain. Không có package ngoài.

```sh
swift test
./scripts/build-app.sh
open dist/NahtKey.app
```

`build-app.sh` tạo app bundle và ký bằng identity được cấu hình. Bản cài 0.2.1 trên máy này dùng chứng chỉ nội bộ cố định; đã kiểm tra cập nhật sang bundle có hash khác vẫn giữ quyền Trợ năng. Đây chưa phải bản phân phối được notarize. Không mở đồng thời bản trong `dist` và bản trong `/Applications`.

Build ưu tiên `NAHTKEY_SIGN_IDENTITY`, rồi identity được lưu trong Git config local của repo; chỉ ký ad-hoc nếu cả hai chưa có. Trên máy phát triển này đã thiết lập certificate **NahtKey Local Development** theo chấp thuận người dùng. Xem [hướng dẫn ký code](docs/code-signing.md).

- `Sources/NahtKeyCore`: lõi VNI và sửa lỗi, độc lập với giao diện/macOS.
- `Sources/NahtKeyApp`: SwiftUI, lưu thư viện, lớp event tap macOS.
- `Tests`: kiểm tra thuật toán, sửa lỗi, thao tác lưu và bảo vệ tệp thư viện lỗi.
- `assets`: logo ứng dụng và icon menu bar tạo bằng built-in imagegen; prompt được lưu cùng asset. Icon menu bar dùng template một màu theo nền macOS.
- `docs/keyboard-test.html`: trang local thử input, textarea và contenteditable, không lưu/gửi dữ liệu.
- `Reference/OpenKey`: bản mã nguồn OpenKey được giữ riêng để tham khảo, không nằm trong target build hay Git của NahtKey. Nguồn: https://github.com/tuyenvm/OpenKey, commit `89c2fd3bf258562f2349f89b49d81e2f140c3fc3`. Giữ nguyên giấy phép và lịch sử của nguồn tham khảo trong thư mục này.

NahtKey không liên kết hay đóng gói mã C++/Objective-C của OpenKey.

## Quay lại sửa từ và giữ dấu cách trong 0.2.1

- Gõ `go `, xóa Space, gõ `4` → `gõ`; `nhận `, xóa Space, gõ `4` → `nhẫn`. Telex dùng `x` thay `4`.
- Khi quay lại bằng chuột/phím điều hướng, chỉ khôi phục một từ hoàn chỉnh ngay bên trái con trỏ và không có vùng bôi đen. Cần ứng dụng cung cấp thông tin Accessibility phù hợp; không đoán khi thiếu thông tin.
- Nhớ tối đa 256 ký tự hiển thị trong phiên để xử lý Backspace. Khi cần nhận lại từ ở vị trí khác, đọc vùng nhỏ trước con trỏ, không log/lưu nội dung. Trường bảo vệ/mật khẩu không được đọc hoặc chuyển đổi.
- Không sửa phần chữ nằm trong mã có số hoặc dấu gạch dưới. Từ được nhận lại không chạy các alias phím gốc vì không biết lịch sử phím ban đầu.
- Trên browser, dấu cách sau từ đang theo dõi đi cùng một giao dịch chữ; Space không bị phát lần thứ hai. Return/Tab vẫn giữ chức năng gửi/chuyển ô và hủy ngữ cảnh cũ.

## Kiểm tra bản 0.1 trên máy phát triển

Đây là lịch sử kiểm tra có phạm vi hẹp. Sau đó người dùng báo thêm lỗi đầu ô nhập và gõ nhanh; bản 0.2 xử lý các lỗi đó, không suy diễn từ kết quả 0.1 thành bảo đảm ổn định trên mọi ứng dụng.

- Ngày 13/10/2026: build arm64, kiểm tra chữ ký bundle và 14 kiểm thử lõi/thư viện đều đạt.
- Giao diện đã được kiểm tra trực tiếp: thêm, sửa, xóa mục thử; hai alias mẫu và ví dụ `tiếng Việt` hiển thị đúng trong ô thử; thư viện được giữ sau khi mở lại ứng dụng.
- Quyền macOS đã được cấp lại cho bản cuối trong `/Applications/NahtKey.app`; event tap được xác nhận đang bật.
- Người dùng đã xác nhận bằng bàn phím thật: `abn5 `, `ab5n `, `tie6ng1 ` cho kết quả `bạn bạn tiếng`. Đây là xác nhận trực tiếp từ người dùng; công cụ điều khiển tự động chưa tái hiện được phép thử bắt phím toàn hệ thống.
- Chưa kiểm tra rộng trên các ứng dụng khác. Sau khi thay binary bằng bản build mới, chữ ký ad-hoc có thể đổi; nếu công tắc quyền vẫn bật nhưng app báo chưa có quyền, bỏ mục NahtKey cũ rồi thêm lại đúng `/Applications/NahtKey.app`.
