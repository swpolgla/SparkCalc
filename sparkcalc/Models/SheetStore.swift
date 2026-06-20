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
    var defaultAnswerColumnFraction: CGFloat = 0.25

    private var nextSheetNumber = 1

    init(defaultAnswerColumnFraction: CGFloat = 0.25) {
        self.defaultAnswerColumnFraction = defaultAnswerColumnFraction
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
        guard let activeId = activeSheetId,
              let currentIndex = sheets.firstIndex(where: { $0.id == activeId }),
              sheets.count > 1 else { return }
        let previousIndex = currentIndex == 0 ? sheets.count - 1 : currentIndex - 1
        self.activeSheetId = sheets[previousIndex].id
    }

    func activateNextSheet() {
        guard let activeId = activeSheetId,
              let currentIndex = sheets.firstIndex(where: { $0.id == activeId }),
              sheets.count > 1 else { return }
        let nextIndex = currentIndex == sheets.count - 1 ? 0 : currentIndex + 1
        self.activeSheetId = sheets[nextIndex].id
    }

    func renameSheet(id: UUID, to newName: String) {
        guard let index = sheets.firstIndex(where: { $0.id == id }) else { return }
        sheets[index].name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Moves the sheet with the given ID to the specified destination index.
    /// - Parameters:
    ///   - id: The UUID of the sheet to move.
    ///   - destinationIndex: The target insertion index in `sheets`. The sheet
    ///     is inserted before the sheet currently at this index.
    func moveSheet(id: UUID, to destinationIndex: Int) {
        guard let fromIndex = sheets.firstIndex(where: { $0.id == id }),
              destinationIndex >= 0, destinationIndex <= sheets.count else { return }
        let sheet = sheets.remove(at: fromIndex)
        let target = min(destinationIndex, sheets.count)
        sheets.insert(sheet, at: target)
    }

    // MARK: - Helpers

    private func makeSheet() -> Sheet {
        let sheet = Sheet(name: "Sheet \(nextSheetNumber)")
        sheet.answerColumnFraction = defaultAnswerColumnFraction
        nextSheetNumber += 1
        return sheet
    }
}
