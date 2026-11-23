import Foundation

@main
struct TestLibraryOrdering {
    static func main() {
        let initial = ["a", "b", "c", "d", "e"]
        precondition(SiteOrder.moving(initial, fromOffsets: IndexSet(integer: 0), toOffset: 5)
                     == ["b", "c", "d", "e", "a"], "Move first to last")
        precondition(SiteOrder.moving(initial, fromOffsets: IndexSet(integer: 4), toOffset: 0)
                     == ["e", "a", "b", "c", "d"], "Move last to first")
        precondition(SiteOrder.moving(initial, fromOffsets: IndexSet([1, 3]), toOffset: 5)
                     == ["a", "c", "e", "b", "d"], "Move multiple in order")
        precondition(SiteOrder.moving(initial, fromOffsets: IndexSet(integer: 2), toOffset: 3)
                     == initial, "Move to same position")
        precondition(SiteOrder.moving(initial, fromOffsets: IndexSet(), toOffset: 2)
                     == initial, "Empty move should be a no-op")
        print("PASS: stable library reordering (single, multi, boundary, no-op)")
    }
}
