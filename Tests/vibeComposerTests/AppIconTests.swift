import XCTest

final class AppIconTests: XCTestCase {
    func testAppIconResourceAndBundleScriptAreConfigured() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let iconURL = root.appendingPathComponent("Resources/AppIcon.icns")
        let scriptURL = root.appendingPathComponent("script/build_and_run.sh")

        XCTAssertTrue(FileManager.default.fileExists(atPath: iconURL.path))

        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        XCTAssertTrue(script.contains("CFBundleIconFile"))
        XCTAssertTrue(script.contains("AppIcon.icns"))
        XCTAssertTrue(script.contains(#"APP_RESOURCES="$APP_CONTENTS/Resources""#))
    }
}
