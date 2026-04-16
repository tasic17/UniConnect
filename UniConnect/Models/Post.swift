import Foundation
import FirebaseFirestore

struct Post: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var category: PostCategory
    var authorId: String
    var authorName: String
    var price: Double?
    var imageURLs: [String]
    var isActive: Bool
    var department: String?
    var createdAt: Date

    enum PostCategory: String, Codable, CaseIterable {
        case prodaja = "Prodaja"
        case kupovina = "Kupovina"
        case cimeri = "Cimeri"
        case usluge = "Usluge"
        case izgubljeno = "Izgubljeno/Nadjeno"
    }
}

