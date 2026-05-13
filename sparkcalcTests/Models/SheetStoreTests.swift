import Foundation
import Testing
@testable import sparkcalc

struct SheetStoreTests {

    @Test func initialState() {
        let store = SheetStore()
        #expect(store.sheets.count == 1)
        #expect(store.activeSheetId != nil)
    }

    @Test func addSheet() {
        let store = SheetStore()
        let initialCount = store.sheets.count
        store.addSheet()
        #expect(store.sheets.count == initialCount + 1)
        #expect(store.activeSheetId == store.sheets.last?.id)
    }

    @Test func removeSheet() {
        let store = SheetStore()
        let first = store.sheets[0]
        store.addSheet()
        let second = store.sheets[1]
        store.removeSheet(id: second.id)
        #expect(store.sheets.count == 1)
        #expect(store.activeSheetId == first.id)
    }

    @Test func removeLastSheetReplaces() {
        let store = SheetStore()
        let oldId = store.sheets[0].id
        store.removeSheet(id: oldId)
        #expect(store.sheets.count == 1)
        #expect(store.sheets[0].id != oldId)
    }

    @Test func activateSheet() {
        let store = SheetStore()
        let first = store.sheets[0]
        store.addSheet()
        let second = store.sheets[1]
        store.activateSheet(id: first.id)
        #expect(store.activeSheetId == first.id)
    }

    @Test func renameSheet() {
        let store = SheetStore()
        let sheet = store.sheets[0]
        store.renameSheet(id: sheet.id, to: "New Name")
        #expect(store.sheets[0].name == "New Name")
    }

    @Test func moveSheet() {
        let store = SheetStore()
        store.addSheet()
        store.addSheet()
        let firstId = store.sheets[0].id
        let secondId = store.sheets[1].id
        store.moveSheet(id: firstId, toBaseIndex: 1)
        #expect(store.sheets[1].id == firstId)
        #expect(store.sheets[0].id == secondId)
    }

    @Test func activatePreviousSheetWraps() {
        let store = SheetStore()
        store.addSheet()
        let firstId = store.sheets[0].id
        store.activateSheet(id: store.sheets[1].id)
        store.activatePreviousSheet()
        #expect(store.activeSheetId == firstId)
    }

    @Test func activateNextSheetWraps() {
        let store = SheetStore()
        store.addSheet()
        let lastId = store.sheets[1].id
        store.activateSheet(id: store.sheets[0].id)
        store.activateNextSheet()
        #expect(store.activeSheetId == lastId)
    }

    @Test func removeActiveMiddleSheetSelectsNextAtSameIndex() {
        let store = SheetStore()
        store.addSheet()
        store.addSheet()
        let middleId = store.sheets[1].id
        store.activateSheet(id: middleId)
        store.removeSheet(id: middleId)
        #expect(store.sheets.count == 2)
        #expect(store.activeSheetId == store.sheets[1].id)
    }

    @Test func removeActiveFirstSheetSelectsNewFirst() {
        let store = SheetStore()
        store.addSheet()
        store.addSheet()
        let firstId = store.sheets[0].id
        store.activateSheet(id: firstId)
        store.removeSheet(id: firstId)
        #expect(store.sheets.count == 2)
        #expect(store.activeSheetId == store.sheets[0].id)
    }

    @Test func removeActiveLastSheetOfMultipleSelectsNewLast() {
        let store = SheetStore()
        store.addSheet()
        let lastId = store.sheets[1].id
        store.activateSheet(id: lastId)
        store.removeSheet(id: lastId)
        #expect(store.sheets.count == 1)
        #expect(store.activeSheetId == store.sheets[0].id)
    }

    @Test func removeSheetWithInvalidIdDoesNothing() {
        let store = SheetStore()
        store.addSheet() // ensure at least 2 sheets so invalid ID is truly a no-op
        let originalCount = store.sheets.count
        let originalActive = store.activeSheetId
        store.removeSheet(id: UUID())
        #expect(store.sheets.count == originalCount)
        #expect(store.activeSheetId == originalActive)
    }

    @Test func removeLastSheetSetsActiveIdToReplacement() {
        let store = SheetStore()
        let oldActive = store.activeSheetId
        store.removeSheet(id: store.sheets[0].id)
        #expect(store.sheets.count == 1)
        #expect(store.activeSheetId != oldActive)
        #expect(store.activeSheetId == store.sheets[0].id)
    }

    @Test func activeSheetIdRemainsValidAfterRemovingActiveSheet() {
        let store = SheetStore()
        store.addSheet()
        store.addSheet()
        let activeId = store.sheets[1].id
        store.activateSheet(id: activeId)
        store.removeSheet(id: activeId)
        #expect(store.sheets.contains(where: { $0.id == store.activeSheetId }))
    }

    @Test func activeSheetIdRemainsValidAfterMove() {
        let store = SheetStore()
        store.addSheet()
        let activeId = store.activeSheetId!
        let firstId = store.sheets[0].id
        store.moveSheet(id: firstId, toBaseIndex: 0)
        #expect(store.activeSheetId == activeId)
        #expect(store.sheets.contains(where: { $0.id == store.activeSheetId }))
    }

    @Test func activateSheetWithInvalidIdDoesNothing() {
        let store = SheetStore()
        let originalActive = store.activeSheetId
        store.activateSheet(id: UUID())
        #expect(store.activeSheetId == originalActive)
    }

    @Test func activateSheetWithStaleIdDoesNothing() {
        let store = SheetStore()
        let oldId = store.sheets[0].id
        store.addSheet()
        store.removeSheet(id: oldId)
        let currentActive = store.activeSheetId
        store.activateSheet(id: oldId)
        #expect(store.activeSheetId == currentActive)
    }

    @Test func renameSheetTrimsWhitespace() {
        let store = SheetStore()
        let id = store.sheets[0].id
        store.renameSheet(id: id, to: "  Hello World  ")
        #expect(store.sheets[0].name == "Hello World")
    }

    @Test func renameSheetWithOnlyWhitespaceBecomesEmpty() {
        let store = SheetStore()
        let id = store.sheets[0].id
        store.renameSheet(id: id, to: "   \n   ")
        #expect(store.sheets[0].name == "")
    }

    @Test func renameSheetWithInvalidIdDoesNothing() {
        let store = SheetStore()
        let originalName = store.sheets[0].name
        store.renameSheet(id: UUID(), to: "New Name")
        #expect(store.sheets[0].name == originalName)
    }

    @Test func moveSheetNoOpWhenFromEqualsTo() {
        let store = SheetStore()
        store.addSheet()
        let originalOrder = store.sheets.map { $0.id }
        let firstId = store.sheets[0].id
        store.moveSheet(id: firstId, toBaseIndex: 0)
        #expect(store.sheets.map { $0.id } == originalOrder)
    }

    @Test func moveSheetNoOpWhenOutOfBounds() {
        let store = SheetStore()
        store.addSheet()
        let originalOrder = store.sheets.map { $0.id }
        let firstId = store.sheets[0].id
        store.moveSheet(id: UUID(), toBaseIndex: 0)
        store.moveSheet(id: firstId, toBaseIndex: -1)
        store.moveSheet(id: firstId, toBaseIndex: 10)
        #expect(store.sheets.map { $0.id } == originalOrder)
    }

    @Test func moveSheetBackwards() {
        let store = SheetStore()
        store.addSheet()
        store.addSheet()
        let lastId = store.sheets[2].id
        store.moveSheet(id: lastId, toBaseIndex: 0)
        #expect(store.sheets[0].id == lastId)
    }

    @Test func addSheetIncrementsNames() {
        let store = SheetStore()
        #expect(store.sheets[0].name == "Sheet 1")
        store.addSheet()
        #expect(store.sheets[1].name == "Sheet 2")
        store.addSheet()
        #expect(store.sheets[2].name == "Sheet 3")
    }

    @Test func activatePreviousSheetWithOneSheetDoesNothing() {
        let store = SheetStore()
        let originalActive = store.activeSheetId
        store.activatePreviousSheet()
        #expect(store.activeSheetId == originalActive)
    }

    @Test func activateNextSheetWithOneSheetDoesNothing() {
        let store = SheetStore()
        let originalActive = store.activeSheetId
        store.activateNextSheet()
        #expect(store.activeSheetId == originalActive)
    }
}
