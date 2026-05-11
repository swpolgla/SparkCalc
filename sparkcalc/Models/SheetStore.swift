import Foundation
import Observation

/// Manages the collection of calculator sheets.
///
/// Maintains an ordered list of sheets, tracks the active sheet, and provides
/// CRUD operations. Ensures at least one sheet always exists.
@Observable
class SheetStore {
    var sheets: [Sheet] = []
    var activeSheetId: UUID?

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

    func activatePreviousSheet() {
        guard let activeSheetId,
              let currentIndex = sheets.firstIndex(where: { $0.id == activeSheetId }),
              sheets.count > 1 else { return }
        let previousIndex = currentIndex == 0 ? sheets.count - 1 : currentIndex - 1
        self.activeSheetId = sheets[previousIndex].id
    }

    func activateNextSheet() {
        guard let activeSheetId,
              let currentIndex = sheets.firstIndex(where: { $0.id == activeSheetId }),
              sheets.count > 1 else { return }
        let nextIndex = currentIndex == sheets.count - 1 ? 0 : currentIndex + 1
        self.activeSheetId = sheets[nextIndex].id
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
