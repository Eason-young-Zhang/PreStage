import XCTest
@testable import PreStage

final class FilteringAndSortingTests: XCTestCase {
    func testFilterStateMatchesRatingLabelsPickDatesCameraLensAndSearch() {
        var item = TestSupport.mediaItem(
            url: URL(fileURLWithPath: "/tmp/filter/Alpha.JPG"),
            captureDate: TestSupport.date(2026, 5, 10)
        )
        item.rating = 4
        item.colorLabel = .red
        item.pickState = .picked
        item.cameraModel = "Lumix S5II"
        item.lensModel = "24-70"

        var filter = FilterState()
        filter.minimumRating = 3
        filter.colorLabel = .red
        filter.pickState = .picked
        filter.startDate = TestSupport.date(2026, 5, 1)
        filter.endDate = TestSupport.date(2026, 5, 31)
        filter.cameraModel = "Lumix S5II"
        filter.lensModel = "24-70"
        filter.searchText = "alpha"

        XCTAssertTrue(filter.includes(item))

        filter.minimumRating = 5
        XCTAssertFalse(filter.includes(item))
    }

    func testDateFilterExcludesItemsWithoutCaptureDate() {
        let item = TestSupport.mediaItem(
            url: URL(fileURLWithPath: "/tmp/filter/UnknownDate.JPG"),
            captureDate: nil
        )

        var filter = FilterState()
        filter.startDate = TestSupport.date(2026, 5, 1)
        XCTAssertFalse(filter.includes(item))

        filter.startDate = nil
        filter.endDate = TestSupport.date(2026, 5, 31)
        XCTAssertFalse(filter.includes(item))
    }

    func testSortServiceCoversAllSupportedFieldsAndDirections() {
        let alpha = TestSupport.mediaItem(
            url: URL(fileURLWithPath: "/tmp/sort/Alpha.JPG"),
            type: .jpeg,
            fileSize: 300,
            addedDate: TestSupport.date(2026, 5, 3),
            createdDate: TestSupport.date(2026, 5, 1),
            modifiedDate: TestSupport.date(2026, 5, 2),
            lastOpenedDate: TestSupport.date(2026, 5, 4)
        )
        let beta = TestSupport.mediaItem(
            url: URL(fileURLWithPath: "/tmp/sort/Beta.RW2"),
            type: .raw,
            fileSize: 100,
            addedDate: TestSupport.date(2026, 5, 1),
            createdDate: TestSupport.date(2026, 5, 3),
            modifiedDate: TestSupport.date(2026, 5, 4),
            lastOpenedDate: TestSupport.date(2026, 5, 2)
        )
        let gamma = TestSupport.mediaItem(
            url: URL(fileURLWithPath: "/tmp/sort/Gamma.MOV"),
            type: .video,
            fileSize: 200,
            addedDate: TestSupport.date(2026, 5, 2),
            createdDate: TestSupport.date(2026, 5, 2),
            modifiedDate: TestSupport.date(2026, 5, 1),
            lastOpenedDate: TestSupport.date(2026, 5, 3)
        )
        let items = [gamma, beta, alpha]
        let sorter = MediaSortService()

        XCTAssertEqual(filenames(sorter.sorted(items, using: SortRule(field: .name, direction: .ascending))), ["Alpha.JPG", "Beta.RW2", "Gamma.MOV"])
        XCTAssertEqual(filenames(sorter.sorted(items, using: SortRule(field: .name, direction: .descending))), ["Gamma.MOV", "Beta.RW2", "Alpha.JPG"])
        XCTAssertEqual(filenames(sorter.sorted(items, using: SortRule(field: .kind, direction: .ascending))), ["Alpha.JPG", "Beta.RW2", "Gamma.MOV"])
        XCTAssertEqual(filenames(sorter.sorted(items, using: SortRule(field: .addedDate, direction: .descending))), ["Alpha.JPG", "Gamma.MOV", "Beta.RW2"])
        XCTAssertEqual(filenames(sorter.sorted(items, using: SortRule(field: .modifiedDate, direction: .ascending))), ["Gamma.MOV", "Alpha.JPG", "Beta.RW2"])
        XCTAssertEqual(filenames(sorter.sorted(items, using: SortRule(field: .createdDate, direction: .descending))), ["Beta.RW2", "Gamma.MOV", "Alpha.JPG"])
        XCTAssertEqual(filenames(sorter.sorted(items, using: SortRule(field: .lastOpenedDate, direction: .ascending))), ["Beta.RW2", "Gamma.MOV", "Alpha.JPG"])
        XCTAssertEqual(filenames(sorter.sorted(items, using: SortRule(field: .size, direction: .descending))), ["Alpha.JPG", "Gamma.MOV", "Beta.RW2"])
    }

    private func filenames(_ items: [MediaItem]) -> [String] {
        items.map(\.filename)
    }
}
