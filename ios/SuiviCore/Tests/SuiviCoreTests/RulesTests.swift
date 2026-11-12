import Foundation
import Testing
@testable import SuiviCore

@Suite struct RulesTests {
    static let exo = Exercise(id: "m-chest-press", name: "Chest press", kind: .muscu, muscle: .pecs,
                              posture: .transfert, help: false, equipment: .machine)
    static let cardioExo = Exercise(id: "c-velo", name: "Vélo", kind: .cardio, muscle: .cardio,
                                    posture: .fauteuil, help: false, equipment: .cardio)

    private func set(_ kg: Double, _ reps: Int, _ done: Bool = false) -> SetEntry {
        SetEntry(kg: kg, reps: reps, done: done)
    }

    private func doneSession(_ id: String, owner: String = "p1", items: [SessionItem]) -> Session {
        Session(id: id, ownerId: owner, createdBy: owner, date: "2026-11-10", title: "Séance",
                status: .done, items: items, updatedAt: "2026-11-10T10:00:00.000Z")
    }

    private func item(_ sets: [SetEntry], scheme: RepScheme? = nil) -> SessionItem {
        SessionItem(id: "i1", exerciseId: Self.exo.id, sets: sets, scheme: scheme)
    }

    @Test func pyramidNewItemWithoutHistory() {
        let it = Rules.newItem(Self.exo, ownerId: "p1", sessions: [], scheme: .pyramid)
        #expect(it.sets.map(\.reps) == [12, 10, 8, 12])
        #expect(it.sets.map(\.kg) == [0, 0, 0, 0])
        #expect(it.sets.allSatisfy { !$0.done })
        #expect(it.scheme == .pyramid)
    }

    @Test func pyramidNewItemFromLastTime() {
        let last = item([set(20, 12, true), set(25, 10, true), set(30, 8, true), set(20, 12, true)],
                        scheme: .pyramid)
        let it = Rules.newItem(Self.exo, ownerId: "p1",
                               sessions: [doneSession("s1", items: [last])], scheme: .pyramid)
        #expect(it.sets.map(\.kg) == [20, 25, 30, 20])
        #expect(it.sets.map(\.reps) == [12, 10, 8, 12])
        #expect(it.sets.allSatisfy { !$0.done })
    }

    @Test func pyramidIgnoresClassicLastTime() {
        let last = item([set(40, 10, true), set(40, 10, true), set(40, 10, true)], scheme: .classic)
        let it = Rules.newItem(Self.exo, ownerId: "p1",
                               sessions: [doneSession("s1", items: [last])], scheme: .pyramid)
        #expect(it.sets.map(\.kg) == [0, 0, 0, 0])
    }

    @Test func classicNewItemFromLastTimeAndDefault() {
        let last = item([set(40, 10, true), set(45, 8, true), set(50, 6, false)])
        let it = Rules.newItem(Self.exo, ownerId: "p1",
                               sessions: [doneSession("s1", items: [last])], scheme: .classic)
        #expect(it.sets == [set(40, 10), set(45, 8)])
        #expect(it.scheme == .classic)
        let blank = Rules.newItem(Self.exo, ownerId: "p1", sessions: [], scheme: .classic)
        #expect(blank.sets == [set(0, 10), set(0, 10), set(0, 10)])
    }

    @Test func cardioNewItem() {
        let blank = Rules.newItem(Self.cardioExo, ownerId: "p1", sessions: [], scheme: .pyramid)
        #expect(blank.scheme == nil)
        #expect(blank.sets.isEmpty)
        #expect(blank.cardio?.minutes == 15)
        #expect(blank.cardio?.done == false)
        let last = SessionItem(id: "c", exerciseId: Self.cardioExo.id,
                               cardio: CardioEntry(minutes: 25, distanceKm: 8, level: 3, done: true))
        let it = Rules.newItem(Self.cardioExo, ownerId: "p1",
                               sessions: [doneSession("s1", items: [last])], scheme: .classic)
        #expect(it.cardio?.minutes == 25)
        #expect(it.cardio?.distanceKm == 8)
        #expect(it.cardio?.level == 3)
        #expect(it.scheme == nil)
    }

    @Test func pyramidSet1MirrorsSet4() {
        let it = item([set(0, 12), set(10, 10), set(15, 8), set(0, 12)], scheme: .pyramid)
        let out = Rules.setKg(it, index: 0, kg: 22.5)
        #expect(out.sets[0].kg == 22.5)
        #expect(out.sets[3].kg == 22.5)
        #expect(out.sets[1].kg == 10)
        #expect(out.sets[2].kg == 15)
    }

    @Test func pyramidOtherSetsTouchOnlyThemselves() {
        let it = item([set(5, 12), set(10, 10), set(15, 8), set(5, 12)], scheme: .pyramid)
        let out = Rules.setKg(it, index: 2, kg: 30)
        #expect(out.sets.map(\.kg) == [5, 10, 30, 5])
        let out3 = Rules.setKg(it, index: 3, kg: 7)
        #expect(out3.sets.map(\.kg) == [5, 10, 15, 7])
    }

    @Test func pyramidDoesNotTouchDoneSet4() {
        let it = item([set(20, 12), set(25, 10), set(30, 8), set(20, 12, true)], scheme: .pyramid)
        let out = Rules.setKg(it, index: 0, kg: 25)
        #expect(out.sets[0].kg == 25)
        #expect(out.sets[3].kg == 20)
    }

    @Test func pyramidRepsNeverCopy() {
        let it = item([set(20, 12), set(25, 10), set(30, 8), set(20, 12)], scheme: .pyramid)
        let out = Rules.setReps(it, index: 0, reps: 14)
        #expect(out.sets.map(\.reps) == [14, 10, 8, 12])
    }

    @Test func classicCopiesToFollowingUndone() {
        let it = item([set(30, 10), set(35, 10, true), set(30, 10)], scheme: .classic)
        let out = Rules.setKg(it, index: 0, kg: 40)
        #expect(out.sets.map(\.kg) == [40, 35, 40])
        let reps = Rules.setReps(it, index: 0, reps: 12)
        #expect(reps.sets.map(\.reps) == [12, 10, 12])
    }

    @Test func legacyNilSchemeBehavesLikeClassic() {
        let it = item([set(30, 10), set(30, 10), set(30, 10)], scheme: nil)
        #expect(Rules.setKg(it, index: 1, kg: 32.5).sets.map(\.kg) == [30, 32.5, 32.5])
    }

    @Test func outOfRangeAndClamping() {
        let it = item([set(10, 10)], scheme: .classic)
        #expect(Rules.setKg(it, index: 5, kg: 20) == it)
        #expect(Rules.setReps(it, index: -1, reps: 20) == it)
        #expect(Rules.setKg(it, index: 0, kg: -5).sets[0].kg == 0)
        #expect(Rules.setReps(it, index: 0, reps: -3).sets[0].reps == 0)
    }

    @Test func switchingSchemeKeepsDoneSets() {
        let it = item([set(20, 12, true), set(25, 10, true), set(30, 8), set(20, 12)], scheme: .pyramid)
        let out = Rules.switchScheme(it, to: .classic)
        #expect(out.scheme == .classic)
        #expect(out.sets[0] == it.sets[0])
        #expect(out.sets[1] == it.sets[1])
        // séries non faites : reps et charge de la dernière série faite
        #expect(out.sets[2] == set(25, 10))
        #expect(out.sets[3] == set(25, 10))
    }

    @Test func switchToClassicWithoutDoneUsesSet1() {
        let it = item([set(20, 12), set(25, 10), set(30, 8), set(20, 12)], scheme: .pyramid)
        let out = Rules.switchScheme(it, to: .classic)
        #expect(out.sets.allSatisfy { $0.kg == 20 && $0.reps == 12 && !$0.done })
    }

    @Test func switchToPyramidPadsAndTruncatesUndone() {
        let classic = item([set(40, 10, true), set(40, 10), set(40, 10)], scheme: .classic)
        let p = Rules.switchScheme(classic, to: .pyramid)
        #expect(p.scheme == .pyramid)
        #expect(p.sets.count == 4)
        #expect(p.sets[0] == classic.sets[0])
        #expect(p.sets.map(\.reps) == [10, 10, 8, 12])
        #expect(p.sets.dropFirst().allSatisfy { !$0.done })

        let long = item([set(40, 10, true), set(40, 10), set(40, 10), set(40, 10), set(40, 10), set(40, 10)],
                        scheme: .classic)
        #expect(Rules.switchScheme(long, to: .pyramid).sets.count == 4)
    }

    @Test func switchToPyramidSet4ReturnsToSet1Load() {
        let padded = item([set(20, 12, true), set(25, 10, true), set(30, 8, true)], scheme: .classic)
        let p = Rules.switchScheme(padded, to: .pyramid)
        #expect(p.sets.count == 4)
        #expect(p.sets[3].kg == 20)
        #expect(p.sets[3].reps == 12)
        let undone = item([set(20, 12), set(25, 10), set(30, 8), set(35, 12)], scheme: .classic)
        #expect(Rules.switchScheme(undone, to: .pyramid).sets[3].kg == 20)
    }

    @Test func defaultSchemeFollowsSlotAndSettings() {
        #expect(Rules.defaultScheme(for: Profile(id: "p1", name: "Clément", slot: 1)) == .pyramid)
        #expect(Rules.defaultScheme(for: Profile(id: "p2", name: "Jules", slot: 2)) == .classic)
        let custom = Profile(id: "p2", name: "Jules", slot: 2, settings: ProfileSettings(defaultScheme: .pyramid))
        #expect(Rules.defaultScheme(for: custom) == .pyramid)
    }

    @Test func repSchemeReps() {
        #expect(RepScheme.pyramid.reps == [12, 10, 8, 12])
    }

    @Test func helperLabelIsSameOnBothPhones() {
        let profiles = [
            Profile(id: "p1", name: "Clément", slot: 1, needsHelp: true),
            Profile(id: "p2", name: "Jules", slot: 2),
        ]
        #expect(Rules.helperName(profiles) == "Jules")
        #expect(Rules.needsHelp(profiles, id: "p1"))
        #expect(!Rules.needsHelp(profiles, id: "p2"))
        #expect(!Rules.needsHelp(profiles, id: nil))
        #expect(Rules.partner(of: "p1", in: profiles)?.id == "p2")
    }

    @Test func needsHelpFallsBackToSlot() {
        let profiles = [Profile(id: "a", name: "A", slot: 1), Profile(id: "b", name: "B", slot: 2)]
        #expect(Rules.needsHelp(profiles, id: "a"))
        #expect(Rules.helperName(profiles) == "B")
    }

    @Test func titleSuggestionStrings() {
        func ex(_ id: String, _ m: Muscle) -> Exercise {
            Exercise(id: id, name: id, kind: m == .cardio ? .cardio : .muscu, muscle: m,
                     posture: .fauteuil, help: false, equipment: .machine)
        }
        let byId = Dictionary(uniqueKeysWithValues: [ex("pec", .pecs), ex("dos", .dos), ex("jam", .quadris),
                                                      ex("car", .cardio), ex("abs", .abdos)].map { ($0.id, $0) })
        func title(_ ids: [String]) -> String {
            Rules.titleSuggestion(ids.map { SessionItem(id: $0, exerciseId: $0) }, byId: byId)
        }
        #expect(title(["pec", "jam"]) == "Full body")
        #expect(title(["pec", "jam", "car"]) == "Full body + cardio")
        #expect(title(["pec"]) == "Push")
        #expect(title(["pec", "car"]) == "Push + cardio")
        #expect(title(["dos"]) == "Pull")
        #expect(title(["pec", "dos"]) == "Haut du corps")
        #expect(title(["jam"]) == "Jambes")
        #expect(title(["jam", "car"]) == "Jambes + cardio")
        #expect(title(["car"]) == "Cardio")
        #expect(title(["abs"]) == "Séance")
        #expect(title([]) == "Séance")
    }

    @Test func isLiveWindow() {
        let now = ISO8601DateFormatter().date(from: "2026-11-12T18:00:00Z")!
        func s(status: SessionStatus = .done, started: String?, ended: String? = nil) -> Session {
            Session(id: "s", ownerId: "p1", createdBy: "p1", date: "2026-11-12", title: "x",
                    status: status, startedAt: started, endedAt: ended, updatedAt: "2026-11-12T17:30:00.000Z")
        }
        #expect(Rules.isLive(s(started: "2026-11-12T17:30:00.000Z"), now: now))
        #expect(Rules.isLive(s(started: "2026-11-12T17:30:00Z"), now: now))
        #expect(!Rules.isLive(s(started: "2026-11-12T13:30:00.000Z"), now: now))
        #expect(!Rules.isLive(s(started: "2026-11-12T17:30:00.000Z", ended: "2026-11-12T17:50:00.000Z"), now: now))
        #expect(!Rules.isLive(s(started: nil), now: now))
        #expect(!Rules.isLive(s(status: .planned, started: "2026-11-12T17:30:00.000Z"), now: now))
    }

    @Test func hasProgress() {
        let none = doneSession("a", items: [item([set(10, 10)])])
        let some = doneSession("b", items: [item([set(10, 10, true)])])
        let cardio = doneSession("c", items: [SessionItem(id: "c", exerciseId: "x",
                                                          cardio: CardioEntry(minutes: 5, done: true))])
        #expect(!Rules.hasProgress(none))
        #expect(Rules.hasProgress(some))
        #expect(Rules.hasProgress(cardio))
    }

    @Test func lastPerformanceRules() {
        let a = doneSession("new", items: [item([set(50, 10, true)])])
        let b = doneSession("old", items: [item([set(40, 10, true)])])
        let other = doneSession("other", owner: "p2", items: [item([set(99, 10, true)])])
        let planned = Session(id: "pl", ownerId: "p1", createdBy: "p1", date: "2026-11-11", title: "x",
                              status: .planned, items: [item([set(70, 10, true)])], updatedAt: "x")
        let all = [planned, other, a, b]
        #expect(Stats.lastPerformance(all, ownerId: "p1", exerciseId: Self.exo.id)?.session.id == "new")
        #expect(Stats.lastPerformance(all, ownerId: "p1", exerciseId: Self.exo.id, excluding: "new")?.session.id == "old")
        #expect(Stats.lastPerformance(all, ownerId: "p1", exerciseId: "nope") == nil)
        let undone = doneSession("u", items: [item([set(10, 10)])])
        #expect(Stats.lastPerformance([undone], ownerId: "p1", exerciseId: Self.exo.id) == nil)
    }
}
