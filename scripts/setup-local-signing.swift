// Run only after the user authorizes a persistent local code-signing identity.
// Passwords never enter process arguments, stdout, source control or saved config.
import Foundation
import Security
import CryptoKit

let identityName = "NahtKey Local Development"

func configureRepository(_ certificate: SecCertificate) throws {
    let fingerprint = Insecure.SHA1.hash(data: SecCertificateCopyData(certificate) as Data)
        .map { String(format: "%02X", $0) }.joined()
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let git = Process()
    git.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    git.arguments = ["-C", root.path, "config", "--local", "nahtkey.signingIdentity", fingerprint]
    try git.run()
    git.waitUntilExit()
    guard git.terminationStatus == 0 else {
        throw NSError(domain: "NahtKeySigning", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not save repository signing identity"])
    }
}

func check(_ status: OSStatus, _ operation: String) throws {
    guard status == errSecSuccess else {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
        throw NSError(domain: "NahtKeySigning", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "\(operation): \(message)"])
    }
}

func trustForCodeSigning(_ certificate: SecCertificate) throws {
    let settings: [[String: Any]] = [[
        kSecTrustSettingsPolicy as String: SecPolicyCreateWithProperties(kSecPolicyAppleCodeSigning, nil)!,
        kSecTrustSettingsResult as String: SecTrustSettingsResult.trustRoot.rawValue
    ]]
    // User domain, codeSign policy only. No SSL/basic/system-root trust is granted.
    try check(SecTrustSettingsSetTrustSettings(certificate, .user, settings as CFArray), "Set code-signing trust")
}

func existingCertificate() -> SecCertificate? {
    var result: CFTypeRef?
    let query: [String: Any] = [kSecClass as String: kSecClassIdentity,
                              kSecReturnRef as String: true, kSecMatchLimit as String: kSecMatchLimitAll]
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let identities = result as? [SecIdentity] else { return nil }
    for identity in identities {
        var certificate: SecCertificate?
        if SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
           let certificate, (SecCertificateCopySubjectSummary(certificate) as String?) == identityName {
            return certificate
        }
    }
    return nil
}

func openssl(_ arguments: [String], input: Data? = nil) throws {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
    task.arguments = arguments
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    let pipe = Pipe()
    task.standardInput = pipe
    try task.run()
    if let input { pipe.fileHandleForWriting.write(input) }
    try pipe.fileHandleForWriting.close()
    task.waitUntilExit()
    guard task.terminationStatus == 0 else {
        throw NSError(domain: "NahtKeySigning", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Certificate generation failed"])
    }
}

do {
    if let existing = existingCertificate() {
        try trustForCodeSigning(existing)
        try configureRepository(existing)
        print("Reused existing NahtKey local identity; no key rotation.")
        exit(0)
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("nahtkey-signing-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    defer { try? FileManager.default.removeItem(at: directory) }
    let config = directory.appendingPathComponent("request.cnf")
    let key = directory.appendingPathComponent("private.pem")
    let cert = directory.appendingPathComponent("certificate.pem")
    let archive = directory.appendingPathComponent("identity.p12")
    try """
    [req]
    distinguished_name=subject
    x509_extensions=extensions
    prompt=no
    [subject]
    CN=NahtKey Local Development
    O=NahtKey
    [extensions]
    basicConstraints=critical,CA:false
    keyUsage=critical,digitalSignature
    extendedKeyUsage=critical,codeSigning
    subjectKeyIdentifier=hash
    authorityKeyIdentifier=keyid
    """.write(to: config, atomically: true, encoding: .utf8)
    try openssl(["req", "-new", "-x509", "-newkey", "rsa:3072", "-nodes", "-sha256", "-days", "3650",
                 "-config", config.path, "-keyout", key.path, "-out", cert.path])
    var random = [UInt8](repeating: 0, count: 32)
    try check(SecRandomCopyBytes(kSecRandomDefault, random.count, &random), "Generate temporary archive password")
    let password = Data(random).base64EncodedString()
    try openssl(["pkcs12", "-export", "-inkey", key.path, "-in", cert.path, "-name", identityName,
                 "-out", archive.path, "-passout", "stdin"], input: Data((password + "\n").utf8))

    var keychain: SecKeychain?
    let keychainPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Keychains/login.keychain-db").path
    try check(SecKeychainOpen(keychainPath, &keychain), "Open login Keychain")
    var codesign: SecTrustedApplication?
    try check(SecTrustedApplicationCreateFromPath("/usr/bin/codesign", &codesign), "Restrict key use to codesign")
    var access: SecAccess?
    try check(SecAccessCreate(identityName as CFString, [codesign!] as CFArray, &access), "Create private-key access policy")
    let options: [String: Any] = [kSecImportExportPassphrase as String: password,
                                 kSecImportExportKeychain as String: keychain!,
                                 kSecImportExportAccess as String: access!]
    var imported: CFArray?
    try check(SecPKCS12Import(try Data(contentsOf: archive) as CFData, options as CFDictionary, &imported), "Import local identity")
    guard let items = imported as? [[String: Any]],
          let identityValue = items.first?[kSecImportItemIdentity as String] else {
        throw NSError(domain: "NahtKeySigning", code: 1, userInfo: [NSLocalizedDescriptionKey: "Imported identity missing"])
    }
    let identity = identityValue as! SecIdentity
    var certificate: SecCertificate?
    try check(SecIdentityCopyCertificate(identity, &certificate), "Read public certificate")
    try trustForCodeSigning(certificate!)
    try configureRepository(certificate!)
    print("Created NahtKey Local Development in login Keychain; code-signing trust only.")
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
