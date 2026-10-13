# Ký mã khi tự build

Giữ cùng danh tính ký qua các bản cập nhật để ứng dụng tiếp tục khớp quyền Trợ năng đã cấp. Chỉ giữ bundle ID hoặc đường dẫn là chưa đủ.

## Cấu hình

Liệt kê các danh tính ký có sẵn trong Keychain rồi chọn một danh tính:

```sh
security find-identity -v -p codesigning
NAHTKEY_SIGN_IDENTITY='tên hoặc fingerprint của identity' ./scripts/build-app.sh
```

Để dùng lại cho các lần build sau:

```sh
git config --local nahtkey.signingIdentity 'tên hoặc fingerprint của identity'
```

Build ưu tiên `NAHTKEY_SIGN_IDENTITY`, rồi cấu hình Git local. Nếu cả hai chưa có, script ký ad-hoc; cách này có thể khiến macOS yêu cầu cấp lại quyền sau khi cập nhật. Nếu danh tính đã chọn không ký được, build dừng và báo lỗi.

## Kiểm tra

```sh
codesign --verify --strict dist/NahtKey.app
codesign -d -r- dist/NahtKey.app
```

Ký mã và notarization là hai bước riêng; script build không thực hiện notarization. Không đưa khóa riêng hoặc thông tin đăng nhập vào Git.

Tham khảo: [Apple — Code Signing Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).
