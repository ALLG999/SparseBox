import SwiftUI
import UniformTypeIdentifiers

extension UIDocumentPickerViewController {
    @objc func fix_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        return fix_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }
}

struct ContentView: View {
    let os = ProcessInfo().operatingSystemVersion
    let origMGURL, modMGURL, featFlagsURL: URL
    @AppStorage("PairingFile") var pairingFile: String?
    @State var mbdb: Backup?
    @State var eligibilityData = Data()
    @State var featureFlagsData = Data()
    @State var mobileGestalt: NSMutableDictionary
    @State var productType = machineName()
    @State var minimuxerReady = false
    @State var reboot = true
    @State var showPairingFileImporter = false
    @State var showErrorAlert = false
    @State var taskRunning = false
    @State var initError: String?
    @State var lastError: String?
    @State var path = NavigationPath()
    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    Button(pairingFile == nil ? "选择配对文件" : "重置配对文件") {
                        if pairingFile == nil {
                            showPairingFileImporter.toggle()
                        } else {
                            pairingFile = nil
                        }
                    }
                    .dropDestination(for: Data.self) { items, location in
                        guard let item = items.first else { return false }
                        pairingFile = try! String(decoding: item, as: UTF8.self)
                        guard pairingFile?.contains("设备证书") ?? false else {
                            lastError = "您刚刚拖放的文件不是配对文件"
                            showErrorAlert.toggle()
                            pairingFile = nil
                            return false
                        }
                        startMinimuxer()
                        return true
                    }
                } footer: {
                    if pairingFile != nil {
                        Text("选择配对文件")
                    } else {
                        Text("选择或拖放配对文件以继续。更多信息:https://docs.sidestore.io/docs/getting-started/pairing-file")
                    }
                }
                Section {
                    Button("列出已安装的应用程序") {
                        testListApps()
                    }
                    Button("绕过3个应用程序限制") {
                        testBypassAppLimit()
                    }
                    .disabled(taskRunning)
                } footer: {
                    Text("隐藏已安装的免费开发人员应用程序，这样您就可以安装3个以上的应用程序。您需要为安装或更新的每3个应用程序应用此功能。")
                }
                Section {
                    Toggle("操作按钮", isOn: bindingForMGKeys(["cT44WE1EohiwRzhsZ8xEsw"]))
                        .disabled(requiresVersion(17))
                    Toggle("允许安装iPadOS应用程序", isOn: bindingForMGKeys(["9MZ5AdH43csAUajl/dU+IQ"], type: [Int].self, defaultValue: [1], enableValue: [1, 2]))
                    Toggle("始终显示(18.0+)", isOn: bindingForMGKeys(["j8/Omm6s1lsmTDFsXjsBfA", "2OOJf1VhaM7NxfRok3HbWQ"]))
                        .disabled(requiresVersion(18))
                    Toggle("Apple Intelligence", isOn: bindingForAppleIntelligence())
                        .disabled(requiresVersion(18))
                    Toggle("苹果笔", isOn: bindingForMGKeys(["yhHcB0iH0d1XzPO/CFd3ow"]))
                    Toggle("经典启动铃声", isOn: bindingForMGKeys(["QHxt+hGLaBPbQJbXiUJX3w"]))
                    Toggle("相机按钮(18.0rc+)", isOn: bindingForMGKeys(["CwvKxM2cEogD3p+HYgaW0Q", "oOV1jhJbdV3AddkcCg0AEA"]))
                        .disabled(requiresVersion(18))
                    Toggle("充电限制", isOn: bindingForMGKeys(["37NVydb//GP/GrhuTN+exg"]))
                        .disabled(requiresVersion(17))
                    Toggle("崩溃检测（可能不工作）", isOn: bindingForMGKeys(["HCzWusHQwZDea6nNhaKndw"]))
                    Toggle("灵动岛（17.4+，可能无法工作）", isOn: bindingForMGKeys(["YlEtTtHlNesRBMal1CqRaA"]))
                        .disabled(requiresVersion(17, 4))
                    Toggle("禁用区域限制", isOn: bindingForRegionRestriction())
                    Toggle("内部存储信息", isOn: bindingForMGKeys(["LBJfwOEzExRxzlAnSuI7eg"]))
                    Toggle("性能监测", isOn: bindingForMGKeys(["EqrsVvjcYDdxHBiQmGhAWw"]))
                    Toggle("舞台经理（ipad os联动开启）", isOn: bindingForMGKeys(["qeaj75wk3HF4DwQ8qbIi7g"]))
                        .disabled(UIDevice.current.userInterfaceIdiom != .pad)
                    if let isSE = UIDevice.perform(Selector("_hasHomeButton")) {
                        Toggle("点击唤醒 (iPhone SE)", isOn: bindingForMGKeys(["yZf3GTRMGTuwSV/lD7Cagw"]))
                    }
                } header: {
                    Text("配置文件")
                }
                Section {
                    Picker("设备型号", selection:$productType) {
                        Text("默认").tag(ContentView.machineName())
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            Text("iPad Pro 11 inch 5th Gen").tag("iPad16,3")
                        } else {
                            Text("iPhone 15 Pro Max").tag("iPhone16,2")
                            Text("iPhone 16 Pro Max").tag("iPhone17,2")
                        }
                    }
                    //.disabled(requiresVersion(18, 1))
                } header: {
                    Text("设备欺骗")
                } footer: {
                    Text("仅在下载Apple Intelligence型号时更改设备型号。Face ID可能会损坏。")
                }
                Section {
                    let cacheExtra = mobileGestalt["CacheExtra"] as? NSMutableDictionary
                    Toggle("变身iPadOS", isOn: bindingForTrollPad())
                    // validate DeviceClass
                        .disabled(cacheExtra?["+3Uf0Pm5F8Xy7Onyvko0vA"] as? String != "iPhone")
                } footer: {
                    Text("覆盖iPadOS的用户界面习惯用法，这样你就可以在iPhone上使用iPadOS的所有多任务功能。提供与TrollPad相同的功能，但可能会导致一些问题。请不要在舞台管理中关闭显示坞，否则你的手机将在旋转到横屏时启动。")
                }
                Section {
                    Toggle("恢复完成后重新启动", isOn: $reboot)
                    Button("应用更改") {
                        saveProductType()
                        try! mobileGestalt.write(to: modMGURL)
                        applyChanges()
                    }
                    .disabled(taskRunning)
                    Button("重置更改") {
                        try! FileManager.default.removeItem(at: modMGURL)
                        try! FileManager.default.copyItem(at: origMGURL, to: modMGURL)
                        mobileGestalt = try! NSMutableDictionary(contentsOf: modMGURL, error: ())
                        applyChanges()
                    }
                    .disabled(taskRunning)
                } footer: {
                    VStack {
                        Text("""
一款糟糕的应用程序。使用它的风险由你自己承担。
感谢下面这些大佬无私的分享与支持：
@SideStore: em_proxy and minimuxer
@JJTech0130: SparseRestore and backup exploit
@PoomSmart: MobileGestalt dump
@Lakr233: BBackupp
@libimobiledevice
@V_wo50 中文翻译ALLG
""")
                    }
                }
            }
            .fileImporter(isPresented: $showPairingFileImporter, allowedContentTypes: [UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!], onCompletion: { result in
                switch result {
                case .success(let url):
                    pairingFile = try! String(contentsOf: url)
                    startMinimuxer()
                case .failure(let error):
                    lastError = error.localizedDescription
                    showErrorAlert.toggle()
                }
            })
            .alert("操作异常", isPresented: $showErrorAlert) {
                Button("确定") {}
            } message: {
                Text(lastError ?? "未知错误")
            }
            .navigationDestination(for: String.self) { view in
                if view == "应用变更" {
                    LogView(mbdb: mbdb!, reboot: reboot)
                } else if view == "无重启模式" {
                    LogView(mbdb: mbdb!, reboot: false)
                } else if view == "ListApps" {
                    AppListView()
                }
            }
            .navigationTitle("SparseBox")
        }
        .onAppear {
            if initError != nil {
                lastError = initError
                initError = nil
                showErrorAlert.toggle()
                return
            }
            
            _ = start_emotional_damage("127.0.0.1:51820")
            if let altPairingFile = Bundle.main.object(forInfoDictionaryKey: "ALTPairingFile") as? String, altPairingFile.count > 5000, pairingFile == nil {
                pairingFile = altPairingFile
            }
            startMinimuxer()
            
            if let cacheExtra = mobileGestalt["CacheExtra"] as? NSMutableDictionary {
                productType = cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] as! String
            }
        }
    }
    
    init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        featFlagsURL = documentsDirectory.appendingPathComponent("FeatureFlags.plist", conformingTo: .data)
        origMGURL = documentsDirectory.appendingPathComponent("OriginalMobileGestalt.plist", conformingTo: .data)
        modMGURL = documentsDirectory.appendingPathComponent("ModifiedMobileGestalt.plist", conformingTo: .data)
        
        do {
            if !FileManager.default.fileExists(atPath: origMGURL.path) {
                let url = URL(filePath: "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist")
                try FileManager.default.copyItem(at: url, to: origMGURL)
            }
            chmod(origMGURL.path, 0o644)
            
            if !FileManager.default.fileExists(atPath: modMGURL.path) {
                try FileManager.default.copyItem(at: origMGURL, to: modMGURL)
            }
            chmod(modMGURL.path, 0o644)
            
            _mobileGestalt = State(initialValue: try NSMutableDictionary(contentsOf: modMGURL, error: ()))
        } catch {
            _mobileGestalt = State(initialValue: [:])
            _initError = State(initialValue: "系统配置文件复制失败: \(error)")
            taskRunning = true
        }
        
        // Fix file picker
        let fixMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, #selector(UIDocumentPickerViewController.fix_init(forOpeningContentTypes:asCopy:)))!
        let origMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, #selector(UIDocumentPickerViewController.init(forOpeningContentTypes:asCopy:)))!
        method_exchangeImplementations(origMethod, fixMethod)
    }

    func testBypassAppLimit() {
        Task {
            taskRunning = true
            if ready() {
                mbdb = Restore.createBypassAppLimit()
                path.append("ApplyNoReboot")
            } else {
                lastError = "minimuxer 尚未准备好。请确保您已设置 WiFi 和 WireGuard VPN。"
                showErrorAlert.toggle()
            }
            taskRunning = false
        }
    }
    
    func testListApps() {
        if ready() {
            path.append("ListApps")
        } else {
            lastError = "minimuxer 尚未准备好。请确保您已设置 WiFi 和 WireGuard VPN。"
            showErrorAlert.toggle()
        }
    }
    
    func applyChanges() {
        Task {
            taskRunning = true
            if ready() {
                mbdb = Restore.createMobileGestalt(file: FileToRestore(from: modMGURL, to: URL(filePath: "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"), owner: 501, group: 501))
                //Restore.createBackupFiles(files: generateFilesToRestore())
                path.append("ApplyChanges")
            } else {
                lastError = "minimuxer 尚未准备好。请确保您已设置 WiFi 和 WireGuard VPN。"
                showErrorAlert.toggle()
            }
            taskRunning = false
        }
    }
    
    func bindingForAppleIntelligence() -> Binding<Bool> {
        guard let cacheExtra = mobileGestalt["CacheExtra"] as? NSMutableDictionary else {
            return State(initialValue: false).projectedValue
        }
        let key = "A62OafQ85EJAiiqKn4agtg"
        return Binding(
            get: {
                if let value = cacheExtra[key] as? Int? {
                    return value == 1
                }
                return false
            },
            set: { enabled in
                if enabled {
                    eligibilityData = try! Data(contentsOf: Bundle.main.url(forResource: "eligibility", withExtension: "plist")!)
                    featureFlagsData = try! Data(contentsOf: Bundle.main.url(forResource: "FeatureFlags_Global", withExtension: "plist")!)
                    cacheExtra[key] = 1
                } else {
                    featureFlagsData = try! PropertyListSerialization.data(fromPropertyList: [:], format: .xml, options: 0)
                    eligibilityData = featureFlagsData
                    // just remove the key as it will be pulled from device tree if missing
                    cacheExtra.removeObject(forKey: key)
                }
            }
        )
    }

    func bindingForRegionRestriction() -> Binding<Bool> {
        guard let cacheExtra = mobileGestalt["CacheExtra"] as? NSMutableDictionary else {
            return State(initialValue: false).projectedValue
        }
        return Binding<Bool>(
            get: {
                return cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] as? String == "US" &&
                    cacheExtra["zHeENZu+wbg7PUprwNwBWg"] as? String == "LL/A"
            },
            set: { enabled in
                if enabled {
                    cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] = "US"
                    cacheExtra["zHeENZu+wbg7PUprwNwBWg"] = "LL/A"
                } else {
                    cacheExtra.removeObject(forKey: "h63QSdBCiT/z0WU6rdQv6Q")
                    cacheExtra.removeObject(forKey: "zHeENZu+wbg7PUprwNwBWg")
                }
            }
        )
    }
    
    func bindingForTrollPad() -> Binding<Bool> {
        // We're going to overwrite DeviceClassNumber but we can't do it via CacheExtra, so we need to do it via CacheData instead
        guard let cacheData = mobileGestalt["CacheData"] as? NSMutableData,
              let cacheExtra = mobileGestalt["CacheExtra"] as? NSMutableDictionary else {
            return State(initialValue: false).projectedValue
        }
        let valueOffset = UserDefaults.standard.integer(forKey: "MGCacheDataDeviceClassNumberOffset")
        //print("Read value from \(cacheData.mutableBytes.load(fromByteOffset: valueOffset, as: Int.self))")
        
        let keys = [
            "uKc7FPnEO++lVhHWHFlGbQ", // ipad
            "mG0AnH/Vy1veoqoLRAIgTA", // MedusaFloatingLiveAppCapability
            "UCG5MkVahJxG1YULbbd5Bg", // MedusaOverlayAppCapability
            "ZYqko/XM5zD3XBfN5RmaXA", // MedusaPinnedAppCapability
            "nVh/gwNpy7Jv1NOk00CMrw", // MedusaPIPCapability,
            "qeaj75wk3HF4DwQ8qbIi7g", // DeviceSupportsEnhancedMultitasking
        ]
        return Binding(
            get: {
                if let value = cacheExtra[keys.first!] as? Int? {
                    return value == 1
                }
                return false
            },
            set: { enabled in
                cacheData.mutableBytes.storeBytes(of: enabled ? 3 : 1, toByteOffset: valueOffset, as: Int.self)
                for key in keys {
                    if enabled {
                        cacheExtra[key] = 1
                    } else {
                        // just remove the key as it will be pulled from device tree if missing
                        cacheExtra.removeObject(forKey: key)
                    }
                }
            }
        )
    }
    
    func bindingForMGKeys<T: Equatable>(_ keys: [String], type: T.Type = Int.self, defaultValue: T? = 0, enableValue: T? = 1) -> Binding<Bool> {
        guard let cacheExtra = mobileGestalt["CacheExtra"] as? NSMutableDictionary else {
            return State(initialValue: false).projectedValue
        }
        return Binding(
            get: {
                if let value = cacheExtra[keys.first!] as? T?, let enableValue {
                    return value == enableValue
                }
                return false
            },
            set: { enabled in
                for key in keys {
                    if enabled {
                        cacheExtra[key] = enableValue
                    } else {
                        // just remove the key as it will be pulled from device tree if missing
                        cacheExtra.removeObject(forKey: key)
                    }
                }
            }
        )
    }
    
    func generateFilesToRestore() -> [FileToRestore] {
        return [
            FileToRestore(from: modMGURL, to: URL(filePath: "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"), owner: 501, group: 501),
            FileToRestore(contents: eligibilityData, to: URL(filePath: "/var/db/eligibilityd/eligibility.plist")),
            FileToRestore(contents: featureFlagsData, to: URL(filePath: "/var/preferences/FeatureFlags/Global.plist")),
        ]
    }
    
    // https://stackoverflow.com/questions/26028918/how-to-determine-the-current-iphone-device-model
    // read device model from kernel
    static func machineName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
    
    func saveProductType() {
        let cacheExtra = mobileGestalt["CacheExtra"] as! NSMutableDictionary
        cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] = productType
    }
    
    func startMinimuxer() {
        guard pairingFile != nil else {
            return
        }
        // set USBMUXD_SOCKET_ADDRESS
        target_minimuxer_address()
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].absoluteString
            try start(pairingFile!, documentsDirectory)
        } catch {
            lastError = error.localizedDescription
            showErrorAlert.toggle()
        }
    }
    
    func requiresVersion(_ major : Int, _ minor: Int = 0, _ patch: Int = 0) -> Bool {
        // XXYYZZ: major XX, minor YY, patch ZZ
        let requiredVersion = major*10000 + minor*100 + patch
        let currentVersion = os.majorVersion*10000 + os.minorVersion*100 + os.patchVersion
        return currentVersion < requiredVersion
    }
}
