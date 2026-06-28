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
    var sheetPendingDeletionId: UUID?

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
        guard let index = sheets.firstIndex(where: { $0.id == id }) else { return }

        guard sheets.count > 1 else {
            // Replace the last sheet with a fresh blank one rather than leaving zero sheets.
            let replacement = makeSheet()
            sheets = [replacement]
            activeSheetId = replacement.id
            return
        }

        sheets.remove(at: index)
        if activeSheetId == id {
            // Activate the sheet that is now at the same index, or the last one.
            let newIndex = min(index, sheets.count - 1)
            activeSheetId = sheets[newIndex].id
        }
    }

    func requestCloseSheet(id: UUID) {
        guard let sheet = sheets.first(where: { $0.id == id }) else { return }
        if sheet.inputText.isEmpty {
            removeSheet(id: id)
        } else {
            sheetPendingDeletionId = id
        }
    }

    func confirmPendingSheetDeletion() {
        guard let id = sheetPendingDeletionId else { return }
        sheetPendingDeletionId = nil
        removeSheet(id: id)
    }

    func cancelPendingSheetDeletion() {
        sheetPendingDeletionId = nil
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
        activeSheetId = sheets[previousIndex].id
    }

    func activateNextSheet() {
        guard let activeId = activeSheetId,
              let currentIndex = sheets.firstIndex(where: { $0.id == activeId }),
              sheets.count > 1 else { return }
        let nextIndex = currentIndex == sheets.count - 1 ? 0 : currentIndex + 1
        activeSheetId = sheets[nextIndex].id
    }

    func renameSheet(id: UUID, to newName: String) {
        guard let index = sheets.firstIndex(where: { $0.id == id }) else { return }
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        sheets[index].name = trimmedName
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
        let adjustedDestination = destinationIndex > fromIndex ? destinationIndex - 1 : destinationIndex
        let target = min(adjustedDestination, sheets.count)
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
