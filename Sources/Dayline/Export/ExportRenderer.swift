import Foundation
import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers
import Darwin
import DaylineData

extension DaylineExporter {
    static let pageSize = CGSize(width: 595.28, height: 841.89)
    static let margin: CGFloat = 42
    static let pngScale: CGFloat = 2
    static let maximumPNGDimension = 16_384
    static let maximumPNGPixelCount = 32_000_000

    static func render(_ document: ExportDocument, format: DaylineExportFormat) throws -> Data {
        try Task.checkCancellation()
        switch format {
        case .markdown: return Data(document.markdown.utf8)
        case .pdf: return try pdf(document)
        case .png: return try png(document)
        }
    }

    private static func attributed(_ document: ExportDocument) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        for block in document.blocks {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 4; style.paragraphSpacing = 12
            style.lineBreakMode = .byWordWrapping
            let size: CGFloat
            let weight: NSFont.Weight
            switch block.style {
            case .title: size = 25; weight = .semibold
            case .heading: size = 15; weight = .semibold
            case .subheading: size = 12; weight = .semibold
            case .task: size = 11; weight = .medium
            case .body: size = 11; weight = .regular
            case .metadata: size = 9; weight = .regular
            }
            let color = block.style == .metadata ? NSColor(calibratedWhite: 0.35, alpha: 1) : NSColor(calibratedWhite: 0.12, alpha: 1)
            result.append(NSAttributedString(string: block.text + "\n", attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: style]))
        }
        return result
    }

    static func pdf(_ document: ExportDocument) throws -> Data {
        let text = attributed(document)
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: data), let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw DaylineExportError.render("无法建立 PDF 文档。")
        }
        let rect = CGRect(x: margin, y: margin + 12, width: pageSize.width - 2 * margin, height: pageSize.height - 2 * margin - 12)
        let path = CGPath(rect: rect, transform: nil)
        var offset = 0, page = 0
        repeat {
            try Task.checkCancellation()
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: offset, length: 0), path, nil)
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.length > 0 else { throw DaylineExportError.render("PDF 排版未能继续，未保存不完整内容。") }
            context.beginPDFPage(nil)
            context.textMatrix = .identity
            CTFrameDraw(frame, context)
            page += 1
            let footer = NSAttributedString(string: "Dayline  ·  \(page)", attributes: [.font: NSFont.systemFont(ofSize: 8), .foregroundColor: NSColor.gray])
            context.textPosition = CGPoint(x: margin, y: 25)
            CTLineDraw(CTLineCreateWithAttributedString(footer), context)
            context.endPDFPage()
            offset += visible.length
        } while offset < text.length
        context.closePDF()
        return data as Data
    }

    static func png(_ document: ExportDocument) throws -> Data {
        let text = attributed(document)
        guard text.length <= 1_000_000 else { throw DaylineExportError.tooLarge("PNG 内容过长。请选择 PDF、Markdown 或分开导出。") }
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let contentWidth = pageSize.width - 2 * margin
        let measured = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(location: 0, length: 0), nil, CGSize(width: contentWidth, height: .greatestFiniteMagnitude), nil)
        let height = max(pageSize.height, ceil(measured.height) + 2 * margin + 4)
        let pixelWidth = Int(ceil(pageSize.width * pngScale)), pixelHeight = Int(ceil(height * pngScale))
        guard pixelWidth <= maximumPNGDimension, pixelHeight <= maximumPNGDimension,
              pixelHeight <= maximumPNGPixelCount / pixelWidth else {
            throw DaylineExportError.tooLarge("PNG 超出安全尺寸（最长 16,384 像素 / 3,200 万像素）。请改用自动分页 PDF、Markdown 或分开导出；不会裁剪内容。")
        }
        guard let context = CGContext(data: nil, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8, bytesPerRow: pixelWidth * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw DaylineExportError.render("无法为 PNG 分配图像内存，请使用 PDF 或 Markdown。")
        }
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.scaleBy(x: pngScale, y: pngScale); context.textMatrix = .identity
        let path = CGPath(rect: CGRect(x: margin, y: margin, width: contentWidth, height: height - 2 * margin), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        guard CTFrameGetVisibleStringRange(frame).length == text.length else { throw DaylineExportError.render("PNG 无法容纳完整内容，请使用 PDF；没有保存裁剪图像。") }
        CTFrameDraw(frame, context)
        try Task.checkCancellation()
        guard let image = context.makeImage() else { throw DaylineExportError.render("PNG 图像生成失败。") }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { throw DaylineExportError.render("PNG 编码失败。") }
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw DaylineExportError.render("PNG 编码失败。") }
        return data as Data
    }

    /// O_EXCL reserves each filename atomically, including when another process races us.
    /// On cancellation/failure, remove only files created by this invocation.
    static func save(documents: [ExportDocument], format: DaylineExportFormat, directory: URL) throws -> [URL] {
        var written: [URL] = []
        do {
            for document in documents {
                try Task.checkCancellation()
                let data = try render(document, format: format)
                try Task.checkCancellation()
                let (url, descriptor) = try reserve(directory: directory, filename: document.filename, extension: format.rawValue)
                written.append(url)
                let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
                do { try handle.write(contentsOf: data); try handle.synchronize(); try handle.close() }
                catch { try? handle.close(); throw error }
            }
            try Task.checkCancellation()
            return written
        } catch {
            var unremoved: [String] = []
            for url in written {
                do { try FileManager.default.removeItem(at: url) }
                catch { unremoved.append(url.path) }
            }
            if !unremoved.isEmpty {
                throw DaylineExportError.write("导出未完成，以下本次生成的文件无法清理，请检查：\n" + unremoved.joined(separator: "\n") + "\n原始原因：" + error.localizedDescription)
            }
            throw error
        }
    }

    private static func reserve(directory: URL, filename: String, extension ext: String) throws -> (URL, Int32) {
        let invalid = CharacterSet(charactersIn: "/\\:\n\r\t\0").union(.controlCharacters)
        let cleaned = filename.components(separatedBy: invalid).joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        var base = ""
        for character in cleaned {
            if (base + String(character)).utf8.count > 160 { break }
            base.append(character)
        }
        if base.isEmpty || base == "." || base == ".." { base = "Dayline-导出" }
        for number in 0..<10_000 {
            let suffix = number == 0 ? "" : " (\(number + 1))"
            let url = directory.appendingPathComponent(base + suffix + "." + ext)
            let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
            if descriptor >= 0 { return (url, descriptor) }
            if errno != EEXIST { throw DaylineExportError.write("无法写入 \(url.lastPathComponent)：\(String(cString: strerror(errno)))") }
        }
        throw DaylineExportError.write("同名文件过多，请选择其他文件夹。")
    }
}
