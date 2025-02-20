import SwiftUI
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

extension View {
    func toast(isPresented: Binding<Bool>, message: String) -> some View {
        self.modifier(ToastModifier(showToast: isPresented, message: message))
    }
}

struct AppItemView: View {
    let appDetails: [String : AnyCodable]
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
                if let bundlePath = appDetails["Path"] {
                    Button("Copy app bundle folder") {
                        UIPasteboard.general.string = "file://a\(bundlePath)"
                        showToast = true
                    }
                }
                if let containerPath = appDetails["Container"] {
                    Button("Copy app data folder") {
                        UIPasteboard.general.string = "file://a\(containerPath)"
                        showToast = true
                    }
                }
            } header: {
                Text("Arbitrary read exploit")
            } footer: {
                Text("After copying path, open Settings, paste it in search bar, select all again and tap Share.\n\nOnly supported on iOS 18.2b1 and older. For this exploit, folders can only be shared via AirDrop.\nIf you're sharing App Store apps, please note that it will still remain encrypted.")
            }
        }
        .toast(isPresented: $showToast, message: "Copy to clipboard")
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
                        print("Invalid device count: \(deviceList.count)")
                        return
                    }
                    let udid = deviceList.first!
                    apps = MobileDevice.listApplications(udid: udid)!
                }
            }
        }
        .searchable(text: $searchString)
        .navigationTitle("App list")
    }
}
