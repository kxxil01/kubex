import Foundation
import CryptoKit

enum StableIdentifier {
    static func uuid(
        metadataUID: String?,
        context: String,
        namespace: String?,
        kind: String,
        name: String
    ) -> UUID {
        if let metadataUID,
           let uuid = UUID(uuidString: metadataUID) {
            return uuid
        }
        return deterministicUUID(from: [context, namespace ?? "", kind, name].joined(separator: "|"))
    }

    private static func deterministicUUID(from seed: String) -> UUID {
        let digest = SHA256.hash(data: Data(seed.utf8))
        var hex = digest.map { String(format: "%02x", $0) }.joined()
        if hex.count < 32 {
            hex = hex.padding(toLength: 32, withPad: "0", startingAt: 0)
        } else if hex.count > 32 {
            hex = String(hex.prefix(32))
        }
        var characters = Array(hex)
        if characters.count >= 32 {
            characters[12] = "4"
            characters[16] = "8"
        }
        let segments = [
            String(characters[0..<8]),
            String(characters[8..<12]),
            String(characters[12..<16]),
            String(characters[16..<20]),
            String(characters[20..<32])
        ]
        let formatted = segments.joined(separator: "-")
        return UUID(uuidString: formatted) ?? UUID()
    }
}
