import SwiftUI
import XCTest
@testable import vibeComposer

final class ThemeTests: XCTestCase {
    func testBackgroundThemeModeProvidesBlackAndWhiteSchemes() {
        XCTAssertEqual(BackgroundThemeMode.black.rawValue, "black")
        XCTAssertEqual(BackgroundThemeMode.white.rawValue, "white")
        XCTAssertEqual(BackgroundThemeMode.black.commandTitle, "黑色主题")
        XCTAssertEqual(BackgroundThemeMode.white.commandTitle, "白色主题")
        XCTAssertEqual(BackgroundThemeMode.black.colorScheme, .dark)
        XCTAssertEqual(BackgroundThemeMode.white.colorScheme, .light)
    }

    func testBackgroundThemeModeFallsBackToBlack() {
        XCTAssertEqual(BackgroundThemeMode.mode(for: "unknown"), .black)
    }
}
