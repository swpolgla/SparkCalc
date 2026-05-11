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
        store.moveSheet(fromIndex: 0, toIndex: 2)
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
}
