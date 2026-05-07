enum RefreshPolicy {
    static func shouldRunFullScan(force: Bool, hasChanges: Bool, hasExistingScan: Bool) -> Bool {
        force || hasChanges || !hasExistingScan
    }
}
