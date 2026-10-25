import Foundation

/// The five file formats available from the Finder New File submenu.
enum FileKind: String, CaseIterable, Sendable {
    case text
    case markdown
    case word
    case excel
    case powerPoint

    var fileExtension: String {
        switch self {
        case .text: return "txt"
        case .markdown: return "md"
        case .word: return "docx"
        case .excel: return "xlsx"
        case .powerPoint: return "pptx"
        }
    }

    var title: String {
        switch self {
        case .text: return NSLocalizedString("Text File", comment: "New text file menu item")
        case .markdown: return NSLocalizedString("Markdown File", comment: "New Markdown file menu item")
        case .word: return NSLocalizedString("Word Document", comment: "New Word document menu item")
        case .excel: return NSLocalizedString("Excel Workbook", comment: "New Excel workbook menu item")
        case .powerPoint: return NSLocalizedString("PowerPoint Presentation", comment: "New PowerPoint presentation menu item")
        }
    }

    var templateName: String? {
        switch self {
        case .text, .markdown: return nil
        case .word, .excel, .powerPoint: return "Blank.\(fileExtension)"
        }
    }
}
