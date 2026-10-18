import Darwin
import Foundation

/// The file remains in place; only the kernel lock represents a live owner.
/// Closing the descriptor (including process termination) releases ownership.
final class SingleInstanceLock {
    private let descriptor: Int32

    private init(descriptor: Int32) { self.descriptor = descriptor }

    deinit { close(descriptor) }

    static func acquire(at url: URL) throws -> SingleInstanceLock? {
        let descriptor = open(url.path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        if flock(descriptor, LOCK_EX | LOCK_NB) == 0 {
            return SingleInstanceLock(descriptor: descriptor)
        }
        let failure = errno
        close(descriptor)
        if failure == EWOULDBLOCK { return nil }
        throw POSIXError(POSIXErrorCode(rawValue: failure) ?? .EIO)
    }
}
