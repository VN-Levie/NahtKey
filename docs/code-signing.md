# Danh tính ứng dụng qua các bản cập nhật

Bản thử hiện ký ad-hoc. Designated requirement của bản này phụ thuộc hash mã, nên bản build mới có thể không khớp quyền Trợ năng đã cấp cho bản cũ. Đó là hạn chế của cách đóng gói thử nghiệm, không phải yêu cầu bình thường của một bộ gõ.

macOS lưu requirement của ứng dụng khi người dùng cấp quyền. Khi cập nhật, bản mới phải thỏa requirement đó. Chỉ giữ bundle ID hoặc đường dẫn chưa đủ.

## Ký bằng danh tính cố định

```sh
security find-identity -v -p codesigning
NAHTKEY_SIGN_IDENTITY='tên hoặc fingerprint của identity trong Keychain' ./scripts/build-app.sh
```

Khi cung cấp identity, script dùng đúng identity đó và dừng nếu ký không thành công; không âm thầm chuyển về ad-hoc. Không tự nới lỏng designated requirement. Bundle ID tiếp tục là `vn.nahtkey.mac`.

- Phát hành cho người khác: dùng Developer ID phù hợp và quy trình notarization riêng.
- Dùng nội bộ: có thể đánh giá certificate code-signing riêng, giữ cùng khóa và requirement qua các bản build. Đây không tương đương notarization hoặc sự tin cậy của Gatekeeper khi phân phối công khai; cần kiểm chứng giữ quyền trên máy thực tế.
- Chuyển từ ad-hoc sang certificate là một lần đổi danh tính, nên có thể phải cấp lại quyền một lần nữa.
- Không đưa certificate private key, mật khẩu Keychain, token Apple hoặc file export identity vào Git.

Ngày 13/10/2026, sau khi người dùng chấp thuận, đã tạo **NahtKey Local Development** trong login Keychain. Certificate RSA 3072/SHA-256, chỉ digitalSignature/codeSigning; trust ở user domain chỉ áp dụng codeSign. Khóa riêng cho phép `/usr/bin/codesign` sử dụng, không được lưu trong repo. Tệp tạm tạo khóa và archive được xóa sau import; mật khẩu archive chỉ truyền qua stdin/bộ nhớ, không có trong argv/log.

`scripts/setup-local-signing.swift` tạo hoặc tái sử dụng đúng danh tính này và lưu fingerprint **công khai** vào Git config local `nahtkey.signingIdentity`; không xoay khóa khi chạy lại. Script chỉ được chạy sau khi người dùng đồng ý thay đổi Keychain. Build sử dụng cấu hình local này trừ khi có `NAHTKEY_SIGN_IDENTITY` override.

Đã ký hai executable có mã khác nhau và app bằng cùng certificate, rồi dùng `codesign --verify -R` xác minh chúng đều thỏa cùng designated requirement: bundle identifier + certificate root. Requirement không còn phụ thuộc hash mỗi binary.

Sau khi người dùng cấp quyền cho identity mới, đã kiểm tra cập nhật thật từ build 3 sang build 4: bundle hash khác, vẫn thỏa requirement cũ; thay app trong `/Applications`, mở lại và bật VNI thành công, không cần cấp quyền lại. Đây là kiểm chứng giữ quyền trên máy này với chứng chỉ hiện tại. Không xóa/tạo lại identity hoặc quay về ad-hoc nếu muốn tiếp tục giữ cùng danh tính.

Tham khảo: [TN3127 – Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements), [TN2206 – Code Signing In Depth](https://developer.apple.com/library/archive/technotes/tn2206/).
