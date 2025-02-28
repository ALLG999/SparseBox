import SwiftUI



extension View {
    func toast(isPresented: Binding<Bool>, message: String) -> some View {
        self.modifier(ToastModifier(showToast: isPresented, message: message))
    }
}

struct AppItemView: View {
    let appDetails: [String : AnyCodable]
    @State private var showToast: Bool = false
    var body: some View {
        Form {
            Section {
                ForEach(Array(appDetails.keys), id: \.self) { k in
                    let v = appDetails[k]?.value as? String
                    Text(k)
                        .badge("\(v ?? "(null)" )")
                        .textSelection(.enabled)
                }
            }
            Section {
                if let bundlePath = appDetails["Path"]
                {
                    Button("复制应用程序包文件夹") {
                        UIPasteboard.general.string = "file://a\(bundlePath)"
                        showToast = true
                    }
                }

                if let containerPath = appDetails["Container"]
                {
                    Button("复制应用程序数据文件夹") {
                        UIPasteboard.general.string = "file://a\(containerPath)"
                        showToast = true
                    }
                }
            } header: {
                Text("任意读取漏洞")
            } footer: {
                Text("复制路径后，打开“设置”，粘贴到搜索栏，再次选择全部，点击“共享”。\n\n仅支持iOS 18.2b1往下版本。对于这个漏洞，文件夹只能通过AirDrop共享。如果你正在分享App Store应用，请注意它仍将保持加密状态。")
           }
        }
        .toast(isPresented: $showToast, message: "路径已复制！")
      }
   }
struct ToastModifier: ViewModifier {
    @Binding var showToast: Bool
    let message: String
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if showToast {
                        VStack {
                            Spacer()
                            HStack {
                                Text(message)
                                    .padding()
                                    .background(Color.black.opacity(0.7))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .transition(.slide)
                        .animation(.easeInOut(duration: 0.3), value: showToast)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                self.showToast = false
                            }
                        }
                    }
                },
                alignment: .bottom
            )
    }
}
struct AppListView: View {
    @State var apps: [String : AnyCodable] = [:]
    @State var searchString: String = ""
    var results: [String] {
        Array(searchString.isEmpty ? apps.keys : apps.filter {
            let appDetails = $0.value.value as? [String: AnyCodable]
            let appName = (appDetails!["CFBundleName"]?.value as! String?)!
            let appPath = (appDetails!["Path"]?.value as! String?)!
            return appName.contains(searchString) || appPath.contains(searchString)
        }.keys)
    }
    var body: some View {
        List {
            ForEach(results, id: \.self) { bundleID in
                let value = apps[bundleID]
                let appDetails = value?.value as? [String: AnyCodable]
                let appImage = appDetails!["PlaceholderIcon"]?.value as! Data?
                let appName = (appDetails!["CFBundleName"]?.value as! String?)!
                let appPath = (appDetails!["Path"]?.value as! String?)!
                NavigationLink {
                    AppItemView(appDetails: appDetails!)
                } label: {
                    Image(uiImage: UIImage(data: appImage!)!)
                        .resizable()
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading) {
                        Text(appName)
                        Text(appPath).font(Font.footnote)
                    }
                }
            }
        }
        .onAppear {
            if apps.count == 0 {
                Task {
                    let deviceList = MobileDevice.deviceList()
                    guard deviceList.count == 1 else {
                        print("设备数量无效: \(deviceList.count)")
                        return
                    }
                    let udid = deviceList.first!
                    apps = MobileDevice.listApplications(udid: udid)!
                }
            }
        }
        .searchable(text: $searchString)
        .navigationTitle("应用程序列表")
    }
}
