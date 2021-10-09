//

import Foundation
import WireDataModel
import ZipArchive
import WireUtilities
import WireCryptobox

extension SessionManager {
    
    public typealias BackupResultClosure = (Result<URL>) -> Void
    public typealias RestoreResultClosure = (VoidResult) -> Void
    
    static private let workerQueue = DispatchQueue(label: "history-backup")

    // MARK: - Export
    
    public enum BackupError: Error {
        case notAuthenticated
        case noActiveAccount
        case compressionError
        case invalidFileExtension
        case keyCreationFailed
        case decryptionError
        case unknown
    }

    public func backupActiveAccount(password: String, completion: @escaping BackupResultClosure) {
        guard let userId = accountManager.selectedAccount?.userIdentifier,
              let clientId = activeUserSession?.selfUserClient()?.remoteIdentifier,
              let handle = activeUserSession.flatMap(ZMUser.selfUser)?.handle else { return completion(.failure(BackupError.noActiveAccount)) }

        StorageStack.backupLocalStorage(
            accountIdentifier: userId,
            clientIdentifier: clientId,
            applicationContainer: sharedContainerURL,
            dispatchGroup: dispatchGroup,
            completion: { [dispatchGroup] in SessionManager.handle(result: $0, password: password, accountId: userId, dispatchGroup: dispatchGroup, completion: completion, handle: handle) }
        )
    }
    
    private static func handle(
        result: Result<StorageStack.BackupInfo>,
        password: String,
        accountId: UUID,
        dispatchGroup: ZMSDispatchGroup? = nil,
        completion: @escaping BackupResultClosure,
        handle: String
        ) {
        workerQueue.async(group: dispatchGroup) {
            let encrypted: Result<URL> = result.map { info in
                // 1. Compress the backup
                let compressed = try compress(backup: info)
                
                // 2. Encrypt the backup
                let url = targetBackupURL(for: info, handle: handle)
                try encrypt(from: compressed, to: url, password: password, accountId: accountId)
                return url
            }
            
            DispatchQueue.main.async(group: dispatchGroup) {
                completion(encrypted)
            }
        }
    }
    
    // MARK: - Import
    
    /// Restores the account database from the Wire iOS database back up file.
    /// @param completion called when the restoration is ended. If success, Result.success with the new restored account
    /// is called.
    public func restoreFromBackup(at location: URL, password: String, completion: @escaping RestoreResultClosure) {
        func complete(_ result: VoidResult) {
            DispatchQueue.main.async(group: dispatchGroup) {
                completion(result)
            }
        }

        guard let userId = unauthenticatedSession?.authenticationStatus.authenticatedUserIdentifier else { return completion(.failure(BackupError.notAuthenticated)) }

        // Verify the imported file has the correct file extension.
        guard location.pathExtension == BackupMetadata.fileExtension else { return completion(.failure(BackupError.invalidFileExtension)) }
        
        SessionManager.workerQueue.async(group: dispatchGroup) { [weak self] in
            guard let `self` = self else { return }
            let decryptedURL = SessionManager.temporaryURL(for: location)
            do {
                try SessionManager.decrypt(from: location, to: decryptedURL, password: password, accountId: userId)
            } catch {
                switch error {
                case ChaCha20Encryption.EncryptionError.decryptionFailed: return complete(.failure(BackupError.decryptionError))
                case ChaCha20Encryption.EncryptionError.keyGenerationFailed: return complete(.failure(BackupError.keyCreationFailed))
                default: return complete(.failure(error))
                }
            }
            
            let url = SessionManager.unzippedBackupURL(for: location)
            guard decryptedURL.unzip(to: url) else { return complete(.failure(BackupError.compressionError)) }
            StorageStack.importLocalStorage(
                accountIdentifier: userId,
                from: url,
                applicationContainer: self.sharedContainerURL,
                dispatchGroup: self.dispatchGroup,
                completion: completion >>> VoidResult.init
            )
        }
    }
    
    // MARK: - Encryption & Decryption
    
    static func encrypt(from input: URL, to output: URL, password: String, accountId: UUID) throws {
        guard let inputStream = InputStream(url: input) else { throw BackupError.unknown }
        guard let outputStream = OutputStream(url: output, append: false) else { throw BackupError.unknown }
        try ChaCha20Encryption.encrypt(input: inputStream, output: outputStream, passphrase: ChaCha20Encryption.Passphrase(password: password, uuid: accountId))
    }
    
    static func decrypt(from input: URL, to output: URL, password: String, accountId: UUID) throws {
        guard let inputStream = InputStream(url: input) else { throw BackupError.unknown }
        guard let outputStream = OutputStream(url: output, append: false) else { throw BackupError.unknown }
        try ChaCha20Encryption.decrypt(input: inputStream, output: outputStream, passphrase: ChaCha20Encryption.Passphrase(password: password, uuid: accountId))
    }
    
    // MARK: - Helper
    
    /// Deletes all previously exported and imported backups.
    public static func clearPreviousBackups(dispatchGroup: ZMSDispatchGroup? = nil) {
        StorageStack.clearBackupDirectory(dispatchGroup: dispatchGroup)
    }
    
    private static func unzippedBackupURL(for url: URL) -> URL {
        let filename = url.deletingPathExtension().lastPathComponent
        return StorageStack.importsDirectory.appendingPathComponent(filename)
    }
    
    private static func compress(backup: StorageStack.BackupInfo) throws -> URL {
        let url = temporaryURL(for: backup.url)
        guard backup.url.zipDirectory(to: url) else { throw BackupError.compressionError }
        return url
    }

    private static func targetBackupURL(for backup: StorageStack.BackupInfo, handle: String) -> URL {
        let component = backup.metadata.backupFilename(for: handle)
        return backup.url.deletingLastPathComponent().appendingPathComponent(component)
    }
    
    private static func temporaryURL(for url: URL) -> URL {
        return url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
    }
}

// MARK: - Compressed Filename

fileprivate extension BackupMetadata {
    
    fileprivate static let nameAppName = "Secret"
    fileprivate static let nameFileName = "Backup"
    fileprivate static let fileExtension = "ios_sbu"

    private static let formatter: DateFormatter = {
       let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
    
    func backupFilename(for handle: String) -> String {
        return "\(BackupMetadata.nameAppName)-\(handle)-\(BackupMetadata.nameFileName)_\(BackupMetadata.formatter.string(from: creationTime)).\(BackupMetadata.fileExtension)"
    }
}

// MARK: - Zip Helper

extension URL {
    func zipDirectory(to url: URL) -> Bool {
        return SSZipArchive.createZipFile(atPath: url.path, withContentsOfDirectory: path)
    }
    
    func unzip(to url: URL) -> Bool {
        return SSZipArchive.unzipFile(atPath: path, toDestination: url.path)
    }
}
