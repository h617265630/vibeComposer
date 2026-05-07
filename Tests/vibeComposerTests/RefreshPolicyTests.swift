import XCTest
@testable import vibeComposer

final class RefreshPolicyTests: XCTestCase {
    func testForcedRefreshAlwaysRunsFullScan() {
        XCTAssertTrue(RefreshPolicy.shouldRunFullScan(force: true, hasChanges: false, hasExistingScan: true))
    }

    func testAutomaticRefreshSkipsFullScanWhenNothingChangedAndDataExists() {
        XCTAssertFalse(RefreshPolicy.shouldRunFullScan(force: false, hasChanges: false, hasExistingScan: true))
    }

    func testAutomaticRefreshRunsFullScanWhenChangesExist() {
        XCTAssertTrue(RefreshPolicy.shouldRunFullScan(force: false, hasChanges: true, hasExistingScan: true))
    }

    func testAutomaticRefreshRunsFullScanWhenNoDataExistsYet() {
        XCTAssertTrue(RefreshPolicy.shouldRunFullScan(force: false, hasChanges: false, hasExistingScan: false))
    }
}
