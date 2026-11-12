import Foundation
import Testing
@testable import SuiviCore

@Suite struct ModelTests {
    static let webJSON = """
    {"id":"s1","ownerId":"p1","createdBy":"p1","date":"2026-11-12","title":"Pecs et dos",
     "status":"done",
     "items":[{"id":"i1","exerciseId":"m-chest-press","sets":[
        {"kg":37.5,"reps":10,"done":true},{"kg":40,"reps":8,"done":true}]}],
     "rpe":7,"durationMin":55,"startedAt":"2026-11-12T17:00:00.000Z","endedAt":"2026-11-12T17:55:00.000Z",
     "updatedAt":"2026-11-12T17:55:00.000Z"}
    """

    @Test func decodesWebSessionJSON() throws {
        let data = Data(Self.webJSON.utf8)
        let session = try JSONDecoder().decode(Session.self, from: data)
        #expect(session.status == .done)
        #expect(session.items.count == 1)
        #expect(session.items[0].sets.count == 2)
        #expect(session.items[0].sets[0].kg == 37.5)
        #expect(session.durationMin == 55)
        #expect(session.startedAt == "2026-11-12T17:00:00.000Z")
        #expect(session.endedAt == "2026-11-12T17:55:00.000Z")

        let encoded = try JSONEncoder().encode(session)
        let original = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let again = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(Set(again.keys) == Set(original.keys))
        let origItem = try #require((original["items"] as? [[String: Any]])?.first)
        let newItem = try #require((again["items"] as? [[String: Any]])?.first)
        #expect(Set(newItem.keys) == Set(origItem.keys))
    }
}
