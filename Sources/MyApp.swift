import SwiftUI

// 应用主入口，使用@main标识
@main
struct MyApp: App {
    init() {
        // 可选的初始化配置（示例中被注释）
        // setenv("RUST_LOG", "trace", 1)  // 设置环境变量
        // set_debug(true)                // 启用调试模式
    }
    
    // 定义应用主体结构
    var body: some Scene {
        WindowGroup {          // 窗口组容器
            ContentView()      // 主内容视图
        }
    }
}
