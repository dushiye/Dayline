import Foundation
import PDFKit
import ImageIO
#if canImport(Dayline)
@testable import Dayline
#endif

enum ExportChecks {
    struct Failure: Error, CustomStringConvertible { var description: String }
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw Failure(description: message) }
    }

    static func run(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let first = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25))!
        let dates = try DaylineExporter.dates(from: first, through: calendar.date(byAdding: .day, value: 6, to: first)!, calendar: calendar)
        let paragraphs = (1...100).map { "第\($0)段：中文长段落测试，保留完整的研究思路、每日计划、标点和换行。\n这是同一段中的下一行。" }.joined(separator: "\n\n") + "\n终点标记完整保留"
        let dual = ExportTaskSnapshot(title: "唯一归属任务", notes: paragraphs, scheduledDate: dates[0], dueDate: dates[1], area: "研究", goal: "完成论文")
        let due = ExportTaskSnapshot(title: "仅截止日期任务", scheduledDate: nil, dueDate: dates[2], isCompleted: true)
        let unscheduled = ExportTaskSnapshot(title: "无日期任务不应出现")
        let tasks = [dual, due, unscheduled, dual]
        let combined = try DaylineExporter.documents(planTasks: tasks, dates: dates, combined: true, calendar: calendar)
        let separate = try DaylineExporter.documents(planTasks: tasks, dates: dates, combined: false, calendar: calendar)
        try require(combined.count == 1 && separate.count == 7, "Combined / separate document counts")
        try require(combined[0].filename == "Dayline-Plan-2026-10-25_to_2026-10-31" && separate[0].filename == "Dayline-Plan-2026-10-25", "Plan filename convention")
        try require(combined[0].markdown.contains("星期日") && combined[0].markdown.contains("已完成 1 / 2 项"), "Weekday or completion statistics missing")
        for group in ["Learning", "Research", "Health"] { try require(separate[0].markdown.contains("### " + group), "Area group missing") }
        try require(combined[0].markdown.contains("- [ ] 唯一归属任务") && combined[0].markdown.contains("- [x] 仅截止日期任务"), "Markdown checkboxes missing")
        try require(combined[0].markdown.components(separatedBy: "唯一归属任务").count == 2, "Duplicate task or dual dates exported twice")
        try require(separate[1].markdown.contains("当天无计划"), "Due reminder duplicated scheduled task")
        try require(separate[1].markdown.contains("已完成 0 / 0 项"), "Empty-day zero statistics missing")
        try require(!combined[0].markdown.contains("无日期任务不应出现"), "Unscheduled task incorrectly assigned")
        try require(combined[0].markdown.contains("\n\n终点标记完整保留") || combined[0].markdown.contains("\n终点标记完整保留"), "Paragraphs lost")

        for format in [DaylineExportFormat.pdf, .markdown] {
            let folder = directory.appendingPathComponent("plans-" + format.rawValue)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let output = try DaylineExporter.save(documents: combined + separate, format: format, directory: folder)
            try require(output.count == 8, "Seven day output missing files")
            if format == .pdf {
                guard let pdf = PDFDocument(url: output[0]), let text = pdf.string else { throw Failure(description: "PDF unreadable") }
                try require(pdf.pageCount > 3, "Long text must paginate")
                try require(text.contains("终点标记完整保留") && text.contains("第100段"), "PDF lost Chinese end text")
                for date in dates { try require(text.contains(DaylineExporter.dayLabel(date, calendar: calendar)), "PDF omitted date") }
                for index in 0..<pdf.pageCount {
                    let size = pdf.page(at: index)!.bounds(for: .mediaBox).size
                    try require(abs(size.width - 595.28) < 0.1 && abs(size.height - 841.89) < 0.1, "PDF is not A4")
                }
            } else {
                let text = try String(contentsOf: output[0], encoding: .utf8)
                try require(text.contains(paragraphs), "UTF-8 Markdown changed original paragraphs")
            }
        }
        let shortTasks = [ExportTaskSnapshot(title: "清晰长图", notes: "第一段中文\n\n第二段正文", scheduledDate: first)]
        let shortCombined = try DaylineExporter.documents(planTasks: shortTasks, dates: dates, combined: true, calendar: calendar)
        let shortSeparate = try DaylineExporter.documents(planTasks: shortTasks, dates: dates, combined: false, calendar: calendar)
        let pngFolder = directory.appendingPathComponent("plans-png")
        try FileManager.default.createDirectory(at: pngFolder, withIntermediateDirectories: true)
        let pngs = try DaylineExporter.save(documents: shortCombined + shortSeparate, format: .png, directory: pngFolder)
        try require(pngs.count == 8, "PNG batch count")
        for url in pngs {
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)! as NSDictionary
            let width = properties[kCGImagePropertyPixelWidth] as! Int
            let height = properties[kCGImagePropertyPixelHeight] as! Int
            try require(width == 1191 && height >= 1684, "PNG resolution too low")
            try require(width * height <= DaylineExporter.maximumPNGPixelCount, "PNG exceeded memory safety bound")
        }
        let ideas = [ExportIdeaSnapshot(title: "中文灵感 / 文件名安全", body: paragraphs), ExportIdeaSnapshot(title: "", body: "")]
        let ideaCombined = try DaylineExporter.documents(ideas: ideas, combined: true)
        let ideaSeparate = try DaylineExporter.documents(ideas: ideas, combined: false)
        try require(ideaSeparate.count == 2 && ideaCombined.count == 1, "Idea modes")
        for format in [DaylineExportFormat.pdf, .markdown] {
            _ = try DaylineExporter.save(documents: ideaCombined + ideaSeparate, format: format, directory: directory)
        }
        _ = try DaylineExporter.save(documents: DaylineExporter.documents(ideas: [.init(title: "空白灵感")], combined: false), format: .png, directory: directory)
        let ordered = try DaylineExporter.documents(ideas: [
            .init(title: "旧灵感", updatedAt: first),
            .init(title: "新灵感", updatedAt: dates[1]),
            .init(title: "置顶灵感", updatedAt: first, isPinned: true)
        ], combined: false)
        try require(ordered.map(\.filename) == ["Dayline-Idea-置顶灵感", "Dayline-Idea-新灵感", "Dayline-Idea-旧灵感"], "Idea pin/update sort order")
        let longPNG = try DaylineExporter.documents(ideas: [.init(title: "长中文 PNG", body: (1...12).map { "第\($0)段中文正文，需要自动换行并完整保留。\n" + String(repeating: "这是供导出验证的中文段落，包含标点。", count: 8) }.joined(separator: "\n\n") + "\n长图终点")], combined: true)
        _ = try DaylineExporter.save(documents: longPNG, format: .png, directory: directory)
        let pngIdeas = [ExportIdeaSnapshot(title: "双灵感一", body: "第一条灵感正文\n\n第二段"), ExportIdeaSnapshot(title: "双灵感二", body: "另一条灵感")]
        let pngIdeaDocuments = try DaylineExporter.documents(ideas: pngIdeas, combined: true) + DaylineExporter.documents(ideas: pngIdeas, combined: false)
        let pngIdeaFolder = directory.appendingPathComponent("ideas-png")
        try FileManager.default.createDirectory(at: pngIdeaFolder, withIntermediateDirectories: true)
        let pngIdeaURLs = try DaylineExporter.save(documents: pngIdeaDocuments, format: .png, directory: pngIdeaFolder)
        try require(pngIdeaURLs.count == 3, "Multi-idea PNG combined/separate outputs missing")
        for url in pngIdeaURLs {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else { throw Failure(description: "Multi-idea PNG unreadable") }
        }
        let longTitle = String(repeating: "跨行的中文长标题需要保留全部文字，", count: 28) + "长标题终点"
        let titleDocuments = try DaylineExporter.documents(ideas: [.init(title: longTitle, body: "长标题之后的正文终点")], combined: true)
        let titleFolder = directory.appendingPathComponent("long-title")
        try FileManager.default.createDirectory(at: titleFolder, withIntermediateDirectories: true)
        let titlePDF = try DaylineExporter.save(documents: titleDocuments, format: .pdf, directory: titleFolder)[0]
        let titlePNG = try DaylineExporter.save(documents: titleDocuments, format: .png, directory: titleFolder)[0]
        let extractedTitle = (PDFDocument(url: titlePDF)?.string ?? "").components(separatedBy: .whitespacesAndNewlines).joined()
        try require(extractedTitle.contains(longTitle) && extractedTitle.contains("长标题之后的正文终点"), "Wrapped title or following body clipped in PDF")
        guard let titleSource = CGImageSourceCreateWithURL(titlePNG as CFURL, nil), CGImageSourceCreateImageAtIndex(titleSource, 0, nil) != nil else { throw Failure(description: "Long-title PNG unreadable") }
        let huge = ExportDocument(filename: "TooLong", blocks: [.init(text: String(repeating: paragraphs, count: 30), style: .body)])
        do { _ = try DaylineExporter.png(huge); throw Failure(description: "Oversized PNG silently clipped") }
        catch DaylineExportError.tooLarge { }
        let conflict = ExportDocument(filename: "conflict", blocks: [.init(text: "保留原文件", style: .body)])
        let firstURL = try DaylineExporter.save(documents: [conflict], format: .markdown, directory: directory)[0]
        let original = try Data(contentsOf: firstURL)
        let nextURL = try DaylineExporter.save(documents: [conflict], format: .markdown, directory: directory)[0]
        try require(firstURL != nextURL, "File collision overwrote original")
        let after = try Data(contentsOf: firstURL)
        try require(after == original, "Existing file content changed")
        let missingDirectory = directory.appendingPathComponent("missing-\(UUID().uuidString)", isDirectory: true)
        do { _ = try DaylineExporter.save(documents: [conflict], format: .markdown, directory: missingDirectory); throw Failure(description: "Write into nonexistent folder succeeded") }
        catch DaylineExportError.write { }
        try require(!FileManager.default.fileExists(atPath: missingDirectory.path), "Failed write unexpectedly created a directory")
        do { _ = try DaylineExporter.dates(from: dates[1], through: dates[0], calendar: calendar); throw Failure(description: "Invalid date range accepted") }
        catch DaylineExportError.invalidRange { }
        do { _ = try DaylineExporter.documents(ideas: [], combined: true); throw Failure(description: "Empty selection accepted") }
        catch DaylineExportError.emptySelection { }
        // A render failure after a completed first file rolls back the whole invocation.
        let rollback = directory.appendingPathComponent("rollback")
        try FileManager.default.createDirectory(at: rollback, withIntermediateDirectories: true)
        do { _ = try DaylineExporter.save(documents: [conflict, huge], format: .png, directory: rollback); throw Failure(description: "Unsafe batch succeeded") }
        catch DaylineExportError.tooLarge { }
        let remains = try FileManager.default.contentsOfDirectory(atPath: rollback.path)
        try require(remains.isEmpty, "Failed batch left partial output")
        print("PASS export: A4 PDF text/pages, UTF-8 paragraphs, 7-day combined/separate PDF/MD/PNG, ideas, empty days, unique attribution, PNG limits, collision, rollback")
    }

    static func cancellation(directory: URL) async throws {
        let target = directory.appendingPathComponent("cancelled")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let document = ExportDocument(filename: "cancelled", blocks: [.init(text: "取消测试", style: .body)])
        // Wait for cancellation so save itself must reject the cancelled context.
        let task = Task {
            while !Task.isCancelled { await Task.yield() }
            return try DaylineExporter.save(documents: [document], format: .pdf, directory: target)
        }
        task.cancel()
        do { _ = try await task.value; throw Failure(description: "Cancelled export succeeded") }
        catch is CancellationError { }
        let remains = try FileManager.default.contentsOfDirectory(atPath: target.path)
        try require(remains.isEmpty, "Cancelled export wrote files")
        print("PASS export cancellation: no files created")
    }
}
