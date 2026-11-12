import Testing
import Foundation
@testable import SuiviCore

@Suite struct RestEndTests {
    let end = Date(timeIntervalSince1970: 1000)

    @Test func liveForegroundEnd() {
        let r = RestEnd.decide(now: end.addingTimeInterval(0.3), endDate: end, isActive: true)
        #expect(r == RestEnd(signal: true, cancelNotification: true))
    }

    @Test func backgroundEndKeepsNotification() {
        let r = RestEnd.decide(now: end.addingTimeInterval(0.3), endDate: end, isActive: false)
        #expect(r == RestEnd(signal: false, cancelNotification: false))
    }

    @Test func lateWakeAfterSuspensionIsSilent() {
        for active in [true, false] {
            let r = RestEnd.decide(now: end.addingTimeInterval(120), endDate: end, isActive: active)
            #expect(r == RestEnd(signal: false, cancelNotification: true))
        }
    }
}
