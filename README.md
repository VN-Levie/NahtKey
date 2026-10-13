# NahtKey

Bộ gõ VNI/Telex cho macOS, viết mới bằng Swift và SwiftUI. Bản 0.3.6 mở rộng kiểm tra chồng phím và sửa ghép cặp nhấn/thả khi phím lặp. Cả ô **Chuỗi gõ hoặc từ cần sửa** và **Thay bằng** đều gõ VNI/Telex trực tiếp, không cần chuyển chế độ riêng cho từ có dấu hay chuỗi gõ nhầm.

## Dùng bản đầu

Ứng dụng đã build nằm tại `dist/NahtKey.app`. Bản cài trên máy nằm tại `/Applications/NahtKey.app`.

1. Mở NahtKey.
2. Bấm **Cấp quyền Trợ năng…**, cho phép **NahtKey** trong System Settings → Privacy & Security → Accessibility (tên mục có thể khác theo phiên bản macOS).
3. Chọn nguồn nhập **ABC**, tắt chế độ tiếng Việt của bộ gõ khác, chọn **VNI** hoặc **Telex** rồi bật **Bật bộ gõ** trong NahtKey.
4. Gõ ở ứng dụng cần dùng. `ban5` → `bạn`. `abn5` hoặc `ab5n` + Space → `bạn `.
5. Nhấn và nhả riêng **Ctrl+Shift** để bật/tắt bộ gõ (không phải Cmd). Tổ hợp có phím khác như Ctrl+Shift+C vẫn được giữ nguyên. Shortcut hoạt động cả khi bộ gõ đang tắt, nếu NahtKey có quyền Trợ năng.
6. Icon NahtKey bình thường khi bật, có nét gạch mảnh phía thân N khi tắt. Nhấn một lần hoặc chuột phải để mở menu ngay; chọn **Mở NahtKey…** để mở cửa sổ.
7. NahtKey chỉ hiện ở menu bar, kể cả khi mở cửa sổ; không thêm icon vào Dock. Bấm **X** hoặc **Cmd+Q** để ẩn cửa sổ, vẫn giữ bộ gõ chạy. Chọn **Thoát hoàn toàn NahtKey** trong menu bar để thoát thật.

NahtKey mặc định bật bộ gõ và nhớ lựa chọn bật/tắt của bạn khi mở lại. Nếu chưa có quyền, bộ gõ chờ quyền; khi quyền được cấp sẽ tự bật nếu trạng thái mong muốn là bật. Bảng từ và ô thử VNI hoạt động trước khi cấp quyền. Ô thử dùng cùng lõi xử lý, nhưng không thay thế việc kiểm tra bắt phím trong ứng dụng khác.

## Bảng sửa lỗi cá nhân

- Thêm, sửa, đổi chuỗi gõ nhầm, xóa có xác nhận và tìm kiếm.
- Cả hai ô đều gõ trực tiếp theo VNI/Telex đang chọn, kể cả khi chưa cấp quyền toàn hệ thống. Một ô **Chuỗi gõ hoặc từ cần sửa** nhận `abn5`, `ab5n` và các từ có dấu như `cau2 → càu`; không có chế độ riêng. Nội dung dán được giữ nguyên. Các ô này không tự chạy quy tắc sửa cá nhân khi đang nhập.
- Chuỗi gõ hoặc từ cần sửa gồm chữ cái/chữ số Unicode, dài 1–64 ký tự, phân biệt hoa/thường. Có thể lưu `abn5 → bạn` hoặc `càu → của`; dữ liệu được chuẩn hóa NFC để tránh hai mục nhìn giống nhau nhưng khác mã Unicode.
- Từ thay thế dài 1–128 ký tự, không có khoảng trắng hoặc ký tự điều khiển.
- So khớp phím gốc trước; nếu không có thì xét đúng từ đã ghép dấu cho các mục có chữ Unicode. Sửa khi gặp Space, dấu câu, Tab hoặc Enter; không đoán từ gần giống.
- 13 quy tắc ban đầu, gồm `abn5/ab5n → bạn`, `haoc85/haoc75 → hoặc`, `torng → trong`; xem [ghi nhận lỗi gõ](docs/typing-findings.md). Khi nâng cấp từ 0.1, bổ sung một lần và bảo toàn các mục người dùng đã sửa; không tự thêm lại mục đã xóa.
- Dữ liệu: `~/Library/Application Support/NahtKey/corrections.json`.
- Ghi tệp nguyên tử trước khi cập nhật giao diện. Nếu tệp không đọc được, ứng dụng báo lỗi và giữ nguyên tệp thay vì ghi đè.

## Kiểu gõ và giới hạn hiện tại

Lõi hỗ trợ dấu thanh `1–5`, mũ `6`, móc `7`, trăng `8`, đ `9`, bỏ dấu/hình dấu `0`, thứ tự dấu linh hoạt, chuyển vị trí dấu khi thêm chữ, chữ hoa và Backspace theo ký tự hiển thị.

Telex hỗ trợ `aa/aw/ee/oo/ow/uw/dd`, dấu `s/f/r/x/j`, bỏ dấu `z`, chữ hoa và gõ dấu linh hoạt. Các nhóm như `uu7/uuw → ưu`, `huou7/huouw → hươu`, `luoi74/luoiwx → lưỡi` có kiểm thử hồi quy.

- VNI kiểm tra cấu trúc tiền tố âm tiết: `matkhau123`, `model123`, `abc123` giữ nguyên. Đây chưa phải bộ nhận diện tiếng Anh/từ điển chính tả hoàn chỉnh; Telex chưa có lớp tự nhận diện English/code tương đương.
- Ngoại lệ viết tắt có giới hạn: `d9c/dc9 → đc`, `dt9/d9t → đt`, tương tự `đk/đg/đh/đv/đb/đs`. Không nới lỏng mọi chuỗi phụ âm hoặc mã như `cmd9`.
- Chuỗi trùng VNI hợp lệ như `a4` hoặc `ban5` vẫn được hiểu là cách gõ tiếng Việt. Tắt bộ gõ nếu muốn giữ nguyên những mã mơ hồ này.
- Cách đặt dấu `hòa`, `khỏe`, `thủy` hiện cố định.
- Sau Backspace, vẫn tiếp tục ghép dấu nhưng tạm bỏ so khớp chuỗi phím gốc cho tới từ kế tiếp, vì lịch sử phím đã không còn tương ứng trực tiếp với chữ hiển thị.
- Bộ đệm giới hạn 128 ký tự đầu vào mỗi từ; chuỗi dài hơn được chuyển tiếp nguyên trạng tới ranh giới từ kế tiếp.
- Không xử lý trường mật khẩu khi macOS bật Secure Event Input. Chuyển ứng dụng, điều hướng con trỏ, click chuột và các tổ hợp Command/Control/Option hủy từ đang theo dõi.
- Ô tìm kiếm dùng nhập văn bản thông thường; hai ô trong form thêm/sửa từ có bộ ghép dấu cục bộ, không dùng phím xóa tổng hợp.
- Khi gõ ngoài ứng dụng, thay suffix bằng Backspace và Unicode, không dùng selection hoặc ký tự tạm. Mã phím mang Unicode được chọn để tránh các phím đang giữ; toàn bộ burst được chuẩn bị trước khi xóa. Theo dõi nhấn/thả theo cả lần giữ phím, kể cả khi có autorepeat.
- Tắt suppression phím thật khi phát phím tổng hợp, và theo dõi thay đổi focus. Lõi xử lý từng phím tăng dần thay vì phát lại toàn bộ chuỗi.
- Vẫn cần kiểm tra thực tế từng ứng dụng. Không cam kết mọi trình soạn thảo, ô tự hoàn thành hay game đều tương thích.
- Chưa có tự chạy khi đăng nhập hoặc nhập/xuất qua giao diện. Ctrl+Shift là phím đổi chế độ; Cmd+Q chỉ ẩn ứng dụng.

Ứng dụng không ghi nhật ký phím, không dùng clipboard để thay chữ và không gọi dịch vụ mạng. Chỉ từ điển do người dùng quản lý được lưu xuống đĩa.

## Phát triển

App chạy trên macOS 14 trở lên. Đóng gói cần Xcode 26 trở lên (đã kiểm tra với Xcode 27) để biên dịch tài nguyên Icon Composer. Không có package ngoài.

```sh
swift test
./scripts/build-app.sh
# Thoát hoàn toàn NahtKey trong menu trước khi cài:
./scripts/install-local.sh
open /Applications/NahtKey.app
```

`build-app.sh` tạo app bundle và ký bằng identity được cấu hình. Từ bản 0.2.1, máy này dùng chứng chỉ nội bộ cố định; đã kiểm tra cập nhật sang bundle có hash khác vẫn giữ quyền Trợ năng. Đây chưa phải bản phân phối được notarize. Không mở đồng thời bản trong `dist` và bản trong `/Applications`.

Build ưu tiên `NAHTKEY_SIGN_IDENTITY`, rồi identity được lưu trong Git config local của repo; chỉ ký ad-hoc nếu cả hai chưa có. Trên máy phát triển này đã thiết lập certificate **NahtKey Local Development** theo chấp thuận người dùng. Xem [hướng dẫn ký code](docs/code-signing.md).

`install-local.sh` cập nhật timestamp của app bundle, đăng ký lại riêng NahtKey với LaunchServices và nhập lại metadata Spotlight. Cách này tránh giữ icon/phiên bản cũ khi cập nhật bằng cách chép đè; không xóa cache hệ thống hoặc khởi động lại Finder/Dock.

Icon ứng dụng được biên dịch từ `assets/NahtKey.icon` bằng `actool`, tạo `Assets.car`, bản dự phòng `.icns` và các khóa Info.plist tương ứng. Lớp `Assets/Logo.png` là bản sao nguyên vẹn của logo gốc `NahtKeyIcon.png`, đặt phủ kín khuôn icon của hệ thống để preview lớn trong Finder không lồng thêm nền trắng. Giữ hai ảnh này đồng bộ khi đổi logo. Tài liệu `.icon` có thể mở bằng [Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer).

Để kiểm tra đường bàn phím thật: chạy `./scripts/build-input-probe.sh`, mở `.build/InputProbe.app`, bật NahtKey rồi gõ vào ô thử. Log chỉ nằm trong bộ nhớ của cửa sổ này, không theo dõi ứng dụng khác. Trường hợp hồi quy: gõ `chu`, giữ `a`, nhấn `7` trước khi thả `a` — phải ra `chưa`, có sự kiện Unicode `ưa` trước key-up của `a`. Tự động hóa gửi phím thẳng tới app có thể bỏ qua event tap, nên không thay thế lượt thử bàn phím thật này.

- `Sources/NahtKeyCore`: lõi VNI và sửa lỗi, độc lập với giao diện/macOS.
- `Sources/NahtKeyApp`: SwiftUI, lưu thư viện, lớp event tap macOS.
- `Tests`: kiểm tra thuật toán, sửa lỗi, thao tác lưu và bảo vệ tệp thư viện lỗi.
- `assets`: logo ứng dụng và icon menu bar tạo bằng built-in imagegen; prompt được lưu cùng asset. Icon menu bar dùng template một màu theo nền macOS.
- `docs/keyboard-test.html`: trang local thử input, textarea và contenteditable, không lưu/gửi dữ liệu.
- `Reference/OpenKey`: bản mã nguồn OpenKey được giữ riêng để tham khảo, không nằm trong target build hay Git của NahtKey. Nguồn: https://github.com/tuyenvm/OpenKey, commit `89c2fd3bf258562f2349f89b49d81e2f140c3fc3`. Giữ nguyên giấy phép và lịch sử của nguồn tham khảo trong thư mục này.

NahtKey không liên kết hay đóng gói mã C++/Objective-C của OpenKey.

## Thứ tự xử lý và tránh xung đột

- Lưu riêng chuỗi phím gốc và chữ đang hiển thị. Quy tắc ghép dấu/giữ mã không sửa mất bản gốc.
- Trong lúc gõ, VNI chỉ tiếp tục ghép dấu khi chuỗi còn có thể là một âm tiết. Nếu đã rõ không thể hợp lệ, giữ/khôi phục phím gốc cho token đó.
- Khi gặp ranh giới từ, tra **đúng toàn bộ chuỗi phím gốc** trong thư viện cá nhân trước. Nếu không khớp, xét đúng từ có dấu đang hiển thị (cho alias Unicode). Nếu cả hai không khớp, giữ kết quả VNI hoặc kết quả nguyên văn. Ví dụ `cau2` khớp cả quy tắc raw `cau2` và quy tắc từ `càu` thì raw thắng.
- Mỗi từ chỉ chọn một kết quả cuối. Kết quả `a → b` không tiếp tục chạy qua quy tắc `b → c`; alias tiền tố không chạy khi người dùng còn gõ một token dài hơn.
- Từ được khôi phục khi quay lại sửa không áp alias phím gốc vì không biết chính xác các phím đã tạo ra nó. Trường mật khẩu, vùng bảo vệ, thao tác chọn/di chuyển và phím tắt vẫn là ranh giới xử lý riêng.

## Credit và các dự án tham khảo

Cảm ơn các tác giả đã công khai mã nguồn và kinh nghiệm xử lý bộ gõ:

| Dự án | Phần được tham khảo | Giấy phép của dự án gốc |
|---|---|---|
| [OpenKey — Mai Vũ Tuyên](https://github.com/tuyenvm/OpenKey) | Bảo vệ autocomplete, thay phần chữ được chọn, xử lý phím kết thúc sau macro | [GPL-3.0](https://github.com/tuyenvm/OpenKey/blob/master/LICENSE) |
| [GoNhanh — khaphanspace](https://github.com/khaphanspace/gonhanh.org) | Quyền sở hữu dấu cách/delimiter trong kết quả sửa từ | [BSD-3-Clause](https://github.com/khaphanspace/gonhanh.org/blob/main/LICENSE) |
| [XKey — xmannv](https://github.com/xmannv/xkey) | Giữ thứ tự giữa thay chữ và phím tiếp theo, giới hạn của editor khi gửi sự kiện | [MIT](https://github.com/xmannv/xkey/blob/main/LICENSE) |
| [VietTelex — Phil Trinh](https://github.com/ptrinh/viettelex) | Kiểm tra tiền tố âm tiết khi đang gõ, giữ chuỗi English/code và khôi phục phím gốc | [MIT](https://github.com/ptrinh/viettelex/blob/main/LICENSE) |

NahtKey triển khai các mô-đun Swift riêng dựa trên những bài học về hành vi này; hiện không nhập trực tiếp engine, bộ từ điển hay bảng sinh tự động từ các dự án trên. `Reference/OpenKey` là bản nguồn tham khảo riêng, giữ nguyên giấy phép gốc và không được đưa vào app/Git của NahtKey. Nếu về sau sử dụng trực tiếp một phần mã hoặc dữ liệu, phần đó phải được ghi nhận cụ thể cùng thông báo bản quyền và giấy phép tương ứng. EVKey được tham khảo qua tài liệu/issue công khai; không có engine macOS đầy đủ trong nguồn công khai đã kiểm tra.

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
