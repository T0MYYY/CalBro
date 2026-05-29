import Foundation

struct Meal: Identifiable, Hashable {
    let id: String
    let name: String
    var time: String
    var calories: Int
    var isLogged: Bool
}
