import Foundation

/// Pure reorder algorithm; makes order changes testable without SwiftUI/UIKit.
enum SiteOrder {
    static func moving<T>(_ items: [T], fromOffsets: IndexSet, toOffset: Int) -> [T] {
        let selected = fromOffsets.filter { items.indices.contains($0) }.sorted()
        guard !selected.isEmpty, (0...items.count).contains(toOffset) else { return items }
        var remaining = items
        let moving = selected.map { items[$0] }
        for index in selected.reversed() { remaining.remove(at: index) }
        let insertionIndex = toOffset - selected.filter { $0 < toOffset }.count
        remaining.insert(contentsOf: moving,
                         at: min(max(0, insertionIndex), remaining.count))
        return remaining
    }
}
