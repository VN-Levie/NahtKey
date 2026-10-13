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

Kiểm tra ngày 13/10/2026: máy chưa có code-signing identity hợp lệ. Chưa tạo hoặc cài chứng chỉ mới, chưa đổi trust trong Keychain. Bản 0.2 đang chạy vẫn giữ nguyên chữ ký đã được người dùng cấp quyền.

Tham khảo: [TN3127 – Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements), [TN2206 – Code Signing In Depth](https://developer.apple.com/library/archive/technotes/tn2206/).
