import SwiftData
import Foundation

enum ModelContainerFactory {
    static let syncedModels: [any PersistentModel.Type] = [
        QuranBookmark.self, HadithBookmark.self, DuaBookmark.self,
        ReadingPosition.self, RecentHadith.self, RecentDua.self,
        RecentSearch.self,
    ]
    static let localModels: [any PersistentModel.Type] = [AudioDownload.self]

    private static var cloudKitEnabled: Bool {
        // CloudKit requires: (1) iCloud account signed in, (2) CloudKit entitlement
        // in provisioning profile. CKContainer crashes asynchronously (SIGTRAP) if
        // either is missing.
        guard FileManager.default.ubiquityIdentityToken != nil else { return false }
        return hasCloudKitEntitlement()
    }

    private static func hasCloudKitEntitlement() -> Bool {
        guard let profileURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let profileData = try? Data(contentsOf: profileURL) else {
            return false
        }
        // The mobileprovision file contains a CMS envelope around a plist.
        // The plist is between <plist and </plist> tags.
        guard let profileString = String(data: profileData, encoding: .ascii),
              let plistStart = profileString.range(of: "<?xml"),
              let plistEnd = profileString.range(of: "</plist>") else {
            return false
        }
        let plistString = String(profileString[plistStart.lowerBound...plistEnd.upperBound])
        guard let plistData = plistString.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let containers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String] else {
            return false
        }
        return containers.contains("iCloud.com.niya.mobile")
    }

    static func create() -> ModelContainer {
        if cloudKitEnabled,
           let container = try? makeContainer(cloudKit: .private("iCloud.com.niya.mobile")) {
            return container
        }
        if let container = try? makeContainer(cloudKit: .none) {
            return container
        }
        return try! makeContainer(cloudKit: .none, inMemory: true)
    }

    static func makeContainer(
        cloudKit: ModelConfiguration.CloudKitDatabase,
        inMemory: Bool = false
    ) throws -> ModelContainer {
        let allModels: [any PersistentModel.Type] = syncedModels + localModels
        let cloudConfig = ModelConfiguration(
            "CloudSync",
            schema: Schema(syncedModels),
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKit
        )
        let localConfig = ModelConfiguration(
            "LocalOnly",
            schema: Schema(localModels),
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: Schema(allModels),
            configurations: cloudConfig, localConfig
        )
    }
}
