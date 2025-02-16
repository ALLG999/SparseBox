import SwiftUI

struct AppItemView: View {
    @State private var showMessage = false
    @State private var message: String = "" // 用于存储显示的消息
    let appDetails: [String: AnyCodable]

    var body: some View {
        Form {
            Section {
                ForEach(Array(appDetails.keys), id: \.self) { key in
                    if let value = appDetails[key]?.value as? String {
                        Text(key)
                            .badge("\(value)")
                            .textSelection(.enabled)
                    }
                }
            }

            Section {
                if let bundlePath = appDetails["Path"]?.value as? String {
                    Button("复制应用程序包文件夹") {
                        let filePath = "file://\(bundlePath)" // 修正路径拼接
                        UIPasteboard.general.string = filePath
                        message = "应用程序包文件夹已复制到剪贴板：\(bundlePath)"
                        showMessage = true
                        print(message)
                    }
                }

                if let containerPath = appDetails["Container"]?.value as? String {
                    Button("复制应用程序数据文件夹") {
                        let filePath = "file://\(containerPath)" // 修正路径拼接
                        UIPasteboard.general.string = filePath
                        message = "应用程序数据文件夹已复制到剪贴板：\(containerPath)"
                        showMessage = true
                        print(message)
                    }
                }
            } header: {
                Text("任意读取漏洞")
            } footer: {
                Text("复制路径后，打开“设置”，粘贴到搜索栏，再次选择全部，点击“共享”。\n\n仅支持iOS 18.2b1往下版本。对于这个漏洞，文件夹只能通过AirDrop共享。如果你正在分享App Store应用，请注意它仍将保持加密状态。")
            }
        }
}

struct MessageView: View {
    var message: String
    var duration: Double
    @Binding var isVisible: Bool

    var body: some View {
        if isVisible {
            Text(message)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        isVisible = false
                    }
                }
        }
    }
}

struct AppListView: View {
    @State private var apps: [String: AnyCodable] = [:]
    @State private var searchString: String = ""

    var results: [String] {
        if searchString.isEmpty {
            return Array(apps.keys)
        } else {
            return apps.filter { key, value in
                let appDetails = value.value as? [String: AnyCodable]
                let appName = appDetails?["CFBundleName"]?.value as? String ?? ""
                let appPath = appDetails?["Path"]?.value as? String ?? ""
                return appName.localizedCaseInsensitiveContains(searchString) || appPath.localizedCaseInsensitiveContains(searchString)
            }.map { $0.key }
        }
    }

    var body: some View {
        List {
            ForEach(results, id: \.self) { bundleID in
                if let value = apps[bundleID], let appDetails = value.value as? [String: AnyCodable] {
                    let appImage = appDetails["PlaceholderIcon"]?.value as? Data
                    let appName = appDetails["CFBundleName"]?.value as? String ?? "Unknown"
                    let appPath = appDetails["Path"]?.value as? String ?? "Unknown"

                    NavigationLink {
                        AppItemView(appDetails: appDetails)
                    } label: {
                        HStack {
                            if let imageData = appImage, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(8)
                            } else {
                                Image(systemName: "app.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.gray)
                            }
                            VStack(alignment: .leading) {
                                Text(appName)
                                Text(appPath)
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if apps.isEmpty {
                Task {
                    let deviceList = MobileDevice.deviceList()
                    guard deviceList.count == 1 else {
                        print("设备数量无效: \(deviceList.count)")
                        return
                    }
                    let udid = deviceList.first!
                    apps = MobileDevice.listApplications(udid: udid) ?? [:]
                }
            }
        }
        .searchable(text: $searchString)
        .navigationTitle("应用程序列表")
    }
}
