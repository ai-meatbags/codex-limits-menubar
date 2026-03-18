import Foundation

struct MenubarSnapshot: Decodable {
    let ok: Bool
    let title: String
    let subtitle: String
    let errorMessage: String?
    let accountLabel: String
    let buckets: [SnapshotBucket]
    let updatedAt: String
}

struct SnapshotBucket: Decodable {
    let id: String
    let windowLabel: String
    let remainingPercent: Int
    let resetLabel: String
    let hasCredits: Bool
    let title: String
    let subtitle: String
}

struct RuntimeConfig: Decodable {
    let pollSeconds: TimeInterval
    let logFilePath: String?
}
