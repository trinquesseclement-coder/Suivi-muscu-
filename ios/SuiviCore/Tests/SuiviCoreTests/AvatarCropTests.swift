import Testing
@testable import SuiviCore

@Suite struct AvatarCropTests {
    @Test func portraitIsCroppedAboveCentre() {
        let r = AvatarCrop.squareRect(width: 3000, height: 4000)
        #expect(r == AvatarCrop.Rect(x: 0, y: 400, side: 3000))
    }

    @Test func landscapeIsCentred() {
        let r = AvatarCrop.squareRect(width: 4000, height: 3000)
        #expect(r == AvatarCrop.Rect(x: 500, y: 0, side: 3000))
    }

    @Test func squareStaysWhole() {
        let r = AvatarCrop.squareRect(width: 800, height: 800)
        #expect(r == AvatarCrop.Rect(x: 0, y: 0, side: 800))
    }
}
