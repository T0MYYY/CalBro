import Foundation

protocol WidgetPreviewService: Sendable {
    func previews() async -> [WidgetPreviewModel]
}

final class MockWidgetPreviewService: WidgetPreviewService {
    func previews() async -> [WidgetPreviewModel] {
        // TODO: Replace with WidgetKit timeline previews.
        [
            WidgetPreviewModel(id: "lock-calories", title: "Calories", subtitle: "1,240 of 1,820 kcal"),
            WidgetPreviewModel(id: "lock-macros", title: "Macros", subtitle: "P 82g · C 148g · F 38g"),
            WidgetPreviewModel(id: "home-medium", title: "Today", subtitle: "560 kcal left")
        ]
    }
}
