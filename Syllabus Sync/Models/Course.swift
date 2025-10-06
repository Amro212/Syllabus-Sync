import Foundation

/// Domain model for a course
struct Course: Identifiable, Codable, Equatable {
    let id: String
    let code: String
    var title: String?
    var colorHex: String?
    var instructor: String?
    
    init(id: String = UUID().uuidString, code: String, title: String? = nil, colorHex: String? = nil, instructor: String? = nil) {
        self.id = id
        self.code = code
        self.title = title
        self.colorHex = colorHex
        self.instructor = instructor
    }
}

