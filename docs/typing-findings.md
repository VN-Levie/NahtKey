# Quan sát lỗi gõ và thay đổi trong 0.2

## Lỗi phải sửa ở bộ gõ

- Đầu ô nhập trình duyệt: gõ `đã` có thể thành `ddã` hoặc chỉ còn `ã`.
- Gõ nhanh: mất chữ hoặc mất ranh giới từ.
- `uu7` thành `uư` thay vì `ưu`: tái hiện trực tiếp trong lõi 0.1; đã sửa chọn nguyên âm trong nhóm `ưu`, `ươu`, `ươi`.

Không dùng quy tắc cá nhân để che các lỗi trên.

Phần xuất phím gửi các sự kiện liên tiếp trong callback. Bản 0.2 từng chèn ký tự tạm rồi chọn phần đuôi cũ cùng ký tự đó trên trình duyệt; bản 0.3.3 bỏ giả định này vì editor có thể không giữ ký tự tạm (xem bên dưới). Đường chọn/thay chữ áp dụng cho các browser nhận diện được và Codex/ChatGPT desktop; phần khác dùng Backspace thông thường.

Nguồn phím tổng hợp được cấu hình rõ để không suppress phím thật. Chuỗi Unicode được chia theo ranh giới grapheme; quan sát focus chỉ lấy danh tính điều khiển và vai trò, không đọc nội dung tài liệu.

Tham khảo lý do xử lý tương thích tại [OpenKey](https://github.com/tuyenvm/OpenKey/blob/master/Sources/OpenKey/macOS/ModernKey/OpenKey.mm), đặc biệt xử lý autocomplete và selection replacement. Mã triển khai NahtKey là Swift riêng. EVKey public repo chưa cung cấp đầy đủ engine macOS để đối chiếu; issue về trình duyệt chỉ là bằng chứng về loại lỗi, không phải bằng chứng NahtKey đã sửa được lỗi đó.

## Quy tắc cá nhân

Đã rà lời người dùng trong chat NahtKey và 7 chat gần đây. Computer History đang dừng; không bật lại ghi lịch sử. Memory registry không có mục trực tiếp về lỗi gõ này. Chỉ ghi các cặp từ ngắn, không đưa nội dung chat hay thông tin khách hàng vào repo.

| Chuỗi phím quan sát | Thay thế | Mức bằng chứng |
|---|---|---|
| abn5, ab5n | bạn | Người dùng yêu cầu trực tiếp |
| haoc85 | hoặc | Hai chat độc lập |
| haoc75 | hoặc | Một lần, rõ nghĩa |
| cna6n | cần | Một lần, rõ nghĩa |
| torng | trong | Một lần, đảo phím |
| modle | model | Một lần, đảo phím |
| vidoe | video | Một lần, đảo phím |
| resaerch | research | Một lần, đảo phím |
| imgagen | imagegen | Một lần, rõ công cụ được nhắc |
| lisecne | license | Một lần, đảo phím |
| swifui | SwiftUI | Một lần, rõ tên công nghệ |
| pricete | private | Một lần, rõ ngữ cảnh repo |

Chỉ so khớp cả token, phân biệt hoa/thường. Migration thêm một lần, giữ nguyên quy tắc người dùng đã sửa và không thêm lại mục đã xóa.

Chưa tự thêm `ngaòi`, `hặoc`, `luư`, `ngãhi`: chỉ thấy chữ đã qua bộ gõ, không biết chuỗi phím gốc. Không thay riêng `xung`, `thỏa`, `đính`, `đâu` vì đó còn là từ hợp lệ ở ngữ cảnh khác. Các quy tắc thiếu chắc chắn và dạng cụm cần quyết định riêng.

## Phạm vi kiểm tra

Test lõi bao gồm VNI/Telex, dấu và chữ hoa, `qu/gi`, nhóm `ưu/ươu/ươi`, sửa alias, Backspace và 100 cụm liên tiếp không chèn thời gian chờ. Test mô hình editor xác minh kết quả khi có inline completion, không mất tiền tố và không để lại ký tự tạm. Đây chưa thay thế kiểm tra bàn phím thật trên browser.

Kiểm tra thực tế cần gõ ở đầu input trống: VNI `d9a4 uu7 abn5 ab5n`, Telex `ddax uuw`, sau Select All/Delete, sau đổi ô bằng Tab và khi gõ nhanh cả câu. Dùng `keyboard-test.html` để thử input, textarea và contenteditable; không lưu hoặc gửi nội dung.

Ngày 13/10/2026, người dùng xác nhận bằng bàn phím thật trên bản 0.2: **“Đã ưu bạn bạn đúng, chưa thấy mất/gộp chữ”**. Đây là xác nhận người dùng trong phạm vi lượt thử, chưa phải kiểm chứng mọi editor. UI Telex được quan sát cho kết quả `đã ưu tiếng Việt bạn`. Sau X/Cmd+Q, kiểm tra hệ thống cho thấy tiến trình còn sống, activation policy accessory, không có cửa sổ onscreen và event tap vẫn bật. Browser tự động của Codex chặn file URL nên trang fixture chưa được tự động kiểm tra tại đó.

## Bổ sung 0.2.1

Người dùng tiếp tục báo `go ` + xóa Space + `4` thành `go4`, `nhận4` thay vì `nhẫn`, và thỉnh thoảng mất Space (`gõtừ`). Đã thêm nhận lại từ hoàn chỉnh bằng lịch sử hiển thị có giới hạn, hoặc vùng nhỏ gần con trỏ do Accessibility cung cấp. Đã thêm test giữ ranh giới từ và không sửa bên trong identifier/số.

Đối chiếu thêm [GoNhanh](https://github.com/khaphanspace/gonhanh.org/blob/main/platforms/macos/RustBridge.swift) và [XKey](https://github.com/xmannv/xkey/blob/main/XKey/EventHandling/CharacterInjector.swift): macro/restore tự chịu trách nhiệm phát delimiter; đường async phải không cho phím tiếp theo vượt transaction chưa hoàn tất. NahtKey vẫn giữ đường synchronous proxy, không sao chép queue/sleep. Trên browser, Space sau từ đang theo dõi được gộp với phần chữ chốt và nuốt phím Space gốc đúng một lần; native editor chỉ gộp khi có sửa từ. Chưa coi đây là bằng chứng đã loại bỏ mọi nguyên nhân mất Space ở mọi app; cần thử bàn phím thật trên bản 0.2.1.

Người dùng đã thử bản 0.2.1 và xác nhận **“Đã cấp lại, cả ba trường hợp đúng”** cho `go + Space + Backspace + 4`, `nhận + Space + Backspace + 4` và gõ nhanh `gõ từ` nhiều lần. Bộ kiểm thử hiện có 44 test; các guard sửa cuối được chạy lại ở suite liên quan. Lỗi gián đoạn vẫn cần theo dõi trong sử dụng thực tế, không suy diễn một lượt thử thành đảm bảo mọi ứng dụng.

## Chuỗi liền nhau và mã có số

Người dùng báo `matkhau123` bị thành `matkhảu`. Tham khảo [VietTelex tại commit 56861da](https://github.com/ptrinh/viettelex/tree/56861da1f13767ba6dca6008ddb604c91a44604c): `TelexEngine.feed` dùng tính hợp lệ của tiền tố âm tiết, ngừng các modifier sau khi chuỗi không còn có thể thành một âm tiết, rồi giữ/khôi phục raw. Cần kiểm tra tiền tố đang gõ, không dùng kiểm tra từ hoàn chỉnh quá sớm vì sẽ phá `ngh`, `qu`, `gi`, `tie`, `uo`.

NahtKey dùng bộ kiểm tra cấu trúc riêng, không nhập bảng vần, từ điển hay implementation của VietTelex. Alias cá nhân vẫn được xét tại ranh giới từ kể cả khi token không phải âm tiết hợp lệ. Các chuỗi trùng cách gõ VNI hợp lệ như `a4`, `ban5` không thể phân biệt ý định tuyệt đối; vẫn được xử lý như VNI, không áp dụng quy tắc chung “có chữ số thì giữ nguyên”.

## Viết tắt và quy tắc từ có dấu

Người dùng phát hiện guard âm tiết quá chặt làm mất `d9c → đc` và `dt9 → đt`. Bản 0.2.3 cho phép một nhóm viết tắt d/đ hai chữ rõ ràng, thay vì vô hiệu guard với mọi mã phụ âm. Bổ sung hồi quy cho 9 ở đầu/cuối, chữ hoa, và bảo toàn `cmd9`, `model123`, `matkhau123`.

Ảnh người dùng cho thấy không thêm được `càu → của` do giới hạn ASCII. Store/UI nay nhận chữ/số Unicode và chuẩn hóa NFC; loader không tự ghi đè tệp có alias xung đột sau chuẩn hóa. Tại ranh giới từ: raw exact trước, từ Unicode đã ghép sau, rồi kết quả thông thường. Quy tắc chỉ chạy một lần; nhận lại từ cũ chưa biết raw không tự chạy lại các alias.

Đã lưu `càu → của` qua giao diện thật vào thư viện của người dùng và quan sát ô thử trả `đc đc đt đt matkhau123 của bạn` cho `d9c dc9 dt9 d9t matkhau123 cau2 abn5 `. Sau nâng cấp 0.2.4, quy tắc vẫn còn; bộ gõ tự bật khi mở app với quyền có sẵn. Bản này ghi nhớ lựa chọn bật/tắt trong preferences; chờ quyền nếu chưa có. Toàn bộ 70 kiểm thử đạt trước khi đóng gói.

## Menu bar, shortcut và ô nhập của ứng dụng

Người dùng xác nhận Ctrl+Shift, hai trạng thái icon và nhấn đúp menu bar đều hoạt động. Icon tắt được tinh chỉnh thành nét gạch 1 pt, nghiêng thoải qua thân N, thấp hơn dấu sắc.

Ô Thay bằng trước đây đi qua cơ chế bỏ qua toàn bộ app nên không ghép dấu. Nay dùng NSTextField với bộ xử lý cục bộ, sửa range UTF-16 theo grapheme, không gửi phím hệ thống. Đã thử bằng sự kiện phím native `giua74 → giữa`, và Select All + `a11 → a1`. Phép thử không lưu mục giả vào từ điển. Tổng bộ test tại thời điểm này là 85 ca.

Icon app không thiếu: file ICNS hợp lệ và NSWorkspace trả logo đúng. Nhưng metadata Spotlight từng còn ghi 0.1.0 trong khi app đã 0.2.4. Đã làm mới riêng app và bổ sung bước touch/register/mdimport vào quá trình cài, không xóa cache toàn máy.

## Mất chữ trước ư và menu phản hồi chậm — 0.3.3

Người dùng báo `chu7a → cưa`, `cu7a → ưa`, gặp ở nhiều nơi. Lõi vẫn trả đúng edit xóa một `u`, chèn `ư`; không tái hiện được xung đột với quy tắc `ưu`. Adapter cũ chèn U+202F rồi chọn lùi `deleteCount + 1`. Khi mô phỏng editor bỏ U+202F trước khi chọn, chạy trên NSTextView cho đúng hai kết quả sai trên; với cả `chua7`/`cua7` cũng mất một phụ âm. Đây là tái hiện cơ chế lỗi có kiểm soát, chưa phải quan sát editor của người dùng đã loại U+202F.

Đường selection nay chọn đúng `deleteCount` rồi chèn suffix mới, không thêm ký tự tạm. Đầu input `d → đ` không đi qua trạng thái nội dung rỗng. Khi có phần gợi ý đang bôi chọn trong ô một dòng, chỉ xóa phần chọn nếu Accessibility xác nhận vùng chọn không rỗng nằm ngay sau toàn bộ từ đang được engine theo dõi. Mọi thao tác chọn bằng chuột, điều hướng/phím tắt vẫn reset engine; không suy đoán có autocomplete ở toàn bộ app. Đọc ngữ cảnh có giới hạn, loại trường bảo vệ và không lưu/log nội dung.

Tham khảo cách tách chiến lược trong [VietTelex TerminalTap](https://github.com/ptrinh/viettelex/blob/main/App/Sources/TerminalTap.swift), [GoNhanh RustBridge](https://github.com/khaphanspace/gonhanh.org/blob/main/platforms/macos/RustBridge.swift) và OpenKey: selection chọn số chữ cần thay; sentinel là cơ chế khác, không mặc định ghép với selection. NahtKey dùng implementation Swift riêng.

Hồi quy gồm hai thứ tự dấu của `chưa/cưa`, `thư`, `ưu`, `đã`, Telex, từ ở đầu ô và sau tiền tố; AppKit thực hiện selection thật trên NSTextView, kèm mô phỏng loại ký tự vô hình. Kiểm tra 100 lượt `chưa cưa ưu bạn bạn ` liên tiếp giữ đủ chữ và Space. Xác nhận bằng bàn phím thật sau cài vẫn cần thiết.

Theo phản hồi người dùng, bỏ nhận nhấn đúp trên menu bar để không chờ `doubleClickInterval`. Nhấn trái/phải mở menu ngay; mở cửa sổ bằng mục **Mở NahtKey…**. Ctrl+Shift và hai trạng thái icon giữ nguyên.
