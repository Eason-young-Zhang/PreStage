import Foundation

struct MediaSortService {
    func sorted(_ items: [MediaItem], using rule: SortRule) -> [MediaItem] {
        items.sorted { compare($0, $1, using: rule) }
    }

    func compare(_ lhs: MediaItem, _ rhs: MediaItem, using rule: SortRule) -> Bool {
        switch rule.field {
        case .name:
            return orderedString(lhs.filename, rhs.filename, direction: rule.direction)
        case .kind:
            return orderedString(
                lhs.mediaType.displayName,
                rhs.mediaType.displayName,
                direction: rule.direction,
                fallback: { self.orderedString(lhs.filename, rhs.filename, direction: .ascending) }
            )
        case .addedDate:
            return orderedDate(
                lhs.addedDate ?? lhs.createdDate ?? lhs.modifiedDate,
                rhs.addedDate ?? rhs.createdDate ?? rhs.modifiedDate,
                direction: rule.direction,
                lhs: lhs,
                rhs: rhs
            )
        case .modifiedDate:
            return orderedDate(lhs.modifiedDate, rhs.modifiedDate, direction: rule.direction, lhs: lhs, rhs: rhs)
        case .createdDate:
            return orderedDate(lhs.createdDate, rhs.createdDate, direction: rule.direction, lhs: lhs, rhs: rhs)
        case .lastOpenedDate:
            return orderedDate(lhs.lastOpenedDate, rhs.lastOpenedDate, direction: rule.direction, lhs: lhs, rhs: rhs)
        case .size:
            if lhs.fileSize == rhs.fileSize {
                return orderedString(lhs.filename, rhs.filename, direction: .ascending)
            }
            return rule.direction == .ascending ? lhs.fileSize < rhs.fileSize : lhs.fileSize > rhs.fileSize
        }
    }

    private func orderedString(_ lhs: String, _ rhs: String, direction: SortDirection, fallback: (() -> Bool)? = nil) -> Bool {
        let result = lhs.localizedStandardCompare(rhs)
        if result == .orderedSame {
            return fallback?() ?? false
        }
        return direction == .ascending ? result == .orderedAscending : result == .orderedDescending
    }

    private func orderedDate(_ lhsDate: Date?, _ rhsDate: Date?, direction: SortDirection, lhs: MediaItem, rhs: MediaItem) -> Bool {
        switch (lhsDate, rhsDate) {
        case let (lhsDate?, rhsDate?):
            if lhsDate == rhsDate {
                return orderedString(lhs.filename, rhs.filename, direction: .ascending)
            }
            return direction == .ascending ? lhsDate < rhsDate : lhsDate > rhsDate
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return orderedString(lhs.filename, rhs.filename, direction: .ascending)
        }
    }
}
