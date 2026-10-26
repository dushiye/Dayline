import XCTest
import SwiftUI
import UIKit
import DaylineData
@testable import DaylineIOS

/// Renders the iPhone UI at ordinary phone sizes. These are layout previews, not device simulators.
@MainActor
final class LayoutPreviewTests: XCTestCase {
    func testOrdinaryPhoneLayouts() throws {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LayoutPreviews", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try previewStore()
        let sizes: [(String, CGFloat, CGFloat)] = [
            ("se-375x667", 375, 667),
            ("iphone16-393x852", 393, 852),
            ("promax-440x956", 440, 956)
        ]
        for (name, width, height) in sizes {
            for scheme in [ColorScheme.light, ColorScheme.dark] where name == "iphone16-393x852" || scheme == .light {
                let suffix = scheme == .dark ? "dark" : "light"
                if name == "iphone16-393x852" {
                    for tab in [PhoneTab.today, .upcoming, .inbox, .goals, .ideas] {
                        try render(PhoneRootView(initialTab: tab).environment(store).environment(\.colorScheme, scheme),
                                   width: width, height: height, style: scheme == .dark ? .dark : .light,
                                   to: directory.appendingPathComponent("preview-\(name)-\(tab.rawValue)-\(suffix).png"))
                    }
                } else if name == "promax-440x956" {
                    for tab in [PhoneTab.today, .goals] {
                        try render(PhoneRootView(initialTab: tab).environment(store).environment(\.colorScheme, scheme),
                                   width: width, height: height, style: scheme == .dark ? .dark : .light,
                                   to: directory.appendingPathComponent("preview-\(name)-\(tab.rawValue)-\(suffix).png"))
                    }
                } else {
                    try render(PhoneRootView(initialTab: .today).environment(store).environment(\.colorScheme, scheme),
                               width: width, height: height, style: scheme == .dark ? .dark : .light,
                               to: directory.appendingPathComponent("preview-\(name)-today-\(suffix).png"))
                }
            }
        }
        try render(PhoneTaskEditor(request: PhoneTaskRequest(scheduledDate: Date())).environment(store),
                   width: 375, height: 667,
                   to: directory.appendingPathComponent("preview-se-375x667-task-editor-light.png"))
        try render(DatePreview(), width: 375, height: 667,
                   to: directory.appendingPathComponent("preview-se-375x667-date-picker-light.png"))
        let written = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        XCTAssertGreaterThanOrEqual(written.count, 10)
    }

    private func previewStore() throws -> DaylineStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Dayline-Preview-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try DaylineStore(container: DaylineStore.makeContainer(url: directory.appendingPathComponent("Dayline.store")))
        store.loadDemoData()
        _ = store.addTask(title: "这是一条故意写得很长的任务标题，用来确认窄屏幕会换行而不是把文字挤出屏幕边缘", scheduledDate: Date())
        return store
    }

    private func render<V: View>(_ view: V, width: CGFloat, height: CGFloat, style: UIUserInterfaceStyle = .light, to url: URL) throws {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let host = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        let window = host ?? UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: height))
        if host == nil { window.makeKeyAndVisible() }
        let controller = UIHostingController(rootView: view)
        controller.overrideUserInterfaceStyle = style
        let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        container.backgroundColor = .systemBackground
        container.clipsToBounds = true
        controller.view.frame = container.bounds
        controller.view.backgroundColor = .systemBackground
        container.addSubview(controller.view)
        window.addSubview(container)
        window.rootViewController?.addChild(controller)
        controller.didMove(toParent: window.rootViewController)
        container.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.35))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let image = UIGraphicsImageRenderer(bounds: container.bounds, format: format).image { _ in
            container.drawHierarchy(in: container.bounds, afterScreenUpdates: true)
        }
        controller.willMove(toParent: nil)
        controller.removeFromParent()
        container.removeFromSuperview()
        guard let data = image.pngData(), let cg = image.cgImage else {
            XCTFail("Could not encode \(url.lastPathComponent)")
            return
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        if let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            context.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        let brightness = Int(pixel[0]) + Int(pixel[1]) + Int(pixel[2])
        let minimum = style == .dark ? 8 : 40
        XCTAssertGreaterThan(brightness, minimum, "\(url.lastPathComponent) rendered blank")
        try data.write(to: url)
    }
}

private struct DatePreview: View {
    @State private var date = Date()
    var body: some View { PhoneDateSheet(date: $date) {} }
}
