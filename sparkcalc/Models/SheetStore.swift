import Foundation
import Combine

/// Manages the collection of calculator sheets.
///
/// Maintains an ordered list of sheets, tracks the active sheet, and provides
/// CRUD operations. Ensures at least one sheet always exists.
class SheetStore: ObservableObject {
    @Published var sheets: [Sheet] = []
    @Published var activeSheetId: UUID?

    private var nextSheetNumber = 1

    init() {
        let first = makeSheet()
        sheets.append(first)
        activeSheetId = first.id
    }

    // MARK: - Sheet Lifecycle

    @discardableResult
    func addSheet() -> Sheet {
        let sheet = makeSheet()
        sheets.append(sheet)
        activeSheetId = sheet.id
        return sheet
    }

    func removeSheet(id: UUID) {
        guard sheets.count > 1 else {
            // Replace the last sheet with a fresh blank one rather than leaving zero sheets.
            let replacement = makeSheet()
            sheets = [replacement]
            activeSheetId = replacement.id
            return
        }

        if let index = sheets.firstIndex(where: { $0.id == id }) {
            sheets.remove(at: index)
            if activeSheetId == id {
                // Activate the sheet that is now at the same index, or the last one.
                let newIndex = min(index, sheets.count - 1)
                activeSheetId = sheets[newIndex].id
            }
        }
    }

    func activateSheet(id: UUID) {
        guard sheets.contains(where: { $0.id == id }) else { return }
        activeSheetId = id
    }

    func renameSheet(id: UUID, to newName: String) {
        guard let index = sheets.firstIndex(where: { $0.id == id }) else { return }
        sheets[index].name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func moveSheet(fromIndex: Int, toIndex: Int) {
        guard fromIndex != toIndex,
              fromIndex >= 0, fromIndex < sheets.count,
              toIndex >= 0, toIndex < sheets.count else { return }
        let sheet = sheets.remove(at: fromIndex)
        let destination = toIndex > fromIndex ? toIndex - 1 : toIndex
        sheets.insert(sheet, at: destination)
    }

    // MARK: - Helpers

    private func makeSheet() -> Sheet {
        let sheet = Sheet(name: "Sheet \(nextSheetNumber)")
        nextSheetNumber += 1
        return sheet
    }
}
