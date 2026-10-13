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

## Phản hồi thực tế và thay đường xuất chữ — 0.3.4

Người dùng xác nhận bản 0.3.3 vẫn lỗi: bôi chọn không thay chữ được, menu hiện mũi tên cuộn và khuất mục đầu. Kết quả kiểm thử selection của bản đó không đại diện cho hành vi editor thực tế.

0.3.4 bỏ hoàn toàn Shift+Left tổng hợp; xóa đúng suffix bằng Backspace rồi chèn Unicode. Không chèn ký tự tạm hoặc cộng thêm một lần xóa cho ký tự giả định. Nhánh xóa vùng gợi ý chỉ dùng khi xác minh được vùng chọn hiện hữu như mô tả trên. Kiểm thử native và mô hình vẫn cần bổ sung bằng xác nhận bàn phím thật, đặc biệt từ đầu ô trống và gõ nhanh.

Menu được gắn trực tiếp bằng `NSStatusItem.menu`, bỏ `NSMenu.popUp` tại tọa độ tự tính. AppKit chịu trách nhiệm đặt menu trong màn hình; không giữ delay hay nhận nhấn đúp.

Sau khi cài 0.3.4, người dùng xác nhận menu đã ổn và gõ được `chưa`, `cưa`, `mưa`; riêng `ưu` vẫn báo lỗi và xác nhận thường gõ `uu7`. Core trả đúng `deleteCount: 2, insertText: "ưu"`; `u7u` và `u7u7` cũng cho `ưu`. Người dùng mô tả nhìn thấy xóa rồi thêm chữ, nhưng chưa xác định kết quả cuối sai hay chỉ bị nháy. Không coi phần này là đã xử lý xong. AXSelectedText không có hỗ trợ ghi thống nhất giữa app/ô nhập, nên chưa áp dụng ghi AX hoặc thay toàn bộ AXValue làm giải pháp chung.

## Giữ phím a khi nhấn dấu — 0.3.5

Người dùng làm rõ: `uu7 → ưu` bình thường, không nháy. Lỗi hay xảy ra với `mưa/chưa/cưa` khi nhấn `a` trước và `7` sát sau, lúc `a` chưa nhả; thứ tự `7` trước `a` ổn. Do đó nhận định trước đó rằng `ưu` đang lỗi không còn phù hợp.

Tái hiện bằng bàn phím thật trong Input Probe (NSTextView riêng, chỉ ghi sự kiện của ô thử): key-down A đã tới target và nội dung là `chua`; hai Backspace có marker NahtKey lần lượt đưa nội dung về `chu`, `ch`; sự kiện Unicode `ưa` không tới, sau đó mới thấy key-up A. Điều này loại khả năng A chưa tới editor trước khi xóa trong lượt tái hiện. Cả lõi lẫn số lần xóa đều đúng. Unicode cũ luôn dùng virtual key 0, trùng phím ANSI A vật lý đang được giữ.

0.3.5 chọn một mã phím chữ ANSI đang rảnh cho cả cặp down/up và mọi chunk của lần chèn Unicode. Ưu tiên giữ A như trước khi A rảnh, dùng B/C… nếu đang giữ A; không dùng phím chức năng hoặc mã reserved. Kết hợp các key-down đã cho qua nhưng chưa nhận key-up với trạng thái HID hiện tại. Chuẩn bị đủ toàn bộ event trước lần xóa đầu tiên; nếu không chuẩn bị được thì reset phiên và cho phím gốc đi qua, không xóa dở rồi bỏ phần chèn.

Kiểm chứng lại cùng ô thử: sau `chua → chu → ch`, Unicode `ưa` có marker NahtKey đến qua key 11 (ANSI B), nội dung trở thành `chưa`, rồi mới tới key-up A. Người dùng xác nhận **“Đã thử, chữ ra đúng”**; ô thử chứa `mưa, chưa, chưa, ưu, mưa, cưa`. Tổng 87 kiểm thử đạt. Đây là bằng chứng khắc phục lỗi giữ A đã tái hiện, không phải bảo đảm mọi chord hoặc mọi editor đều giống NSTextView. Không sửa quy tắc `ưu`, không thêm sleep hay thay đổi clipboard/AXValue.
