# Quan sát lỗi gõ và thay đổi trong 0.2

## Lỗi phải sửa ở bộ gõ

- Đầu ô nhập trình duyệt: gõ `đã` có thể thành `ddã` hoặc chỉ còn `ã`.
- Gõ nhanh: mất chữ hoặc mất ranh giới từ.
- `uu7` thành `uư` thay vì `ưu`: tái hiện trực tiếp trong lõi 0.1; đã sửa chọn nguyên âm trong nhóm `ưu`, `ươu`, `ươi`.

Không dùng quy tắc cá nhân để che các lỗi trên.

Phần xuất phím hiện gửi một giao dịch đồng bộ trong callback. Ở trình duyệt, ký tự tạm chốt lựa chọn gợi ý, sau đó chọn phần đuôi cũ cùng ký tự tạm và thay trực tiếp; tránh xóa hết chữ đầu tiên rồi để frontend xử lý trạng thái rỗng. Ký tự tạm phải biến mất trong cùng giao dịch. Phần khác dùng đường Backspace thông thường. Bật cho các browser nhận diện được và Codex/ChatGPT desktop, chưa áp dụng toàn cục.

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
