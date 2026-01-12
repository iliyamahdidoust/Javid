import Foundation
import CoreLocation
import FirebaseFirestore

struct Business: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var category: String
    var description: String
    var phone: String
    var address: String
    var city: String
    var country: String
    var latitude: Double
    var longitude: Double
    var ownerId: String
    var photoURLs: [String] = []
    var rating: Double = 0.0
    var reviewCount: Int = 0
    var workHours: WorkHours?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // Updated initializer with photoURLs
    init(id: String = UUID().uuidString, name: String, category: String, description: String, phone: String, address: String, city: String, country: String, latitude: Double, longitude: Double, ownerId: String, photoURLs: [String] = [], rating: Double = 0.0, reviewCount: Int = 0, workHours: WorkHours? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.phone = phone
        self.address = address
        self.city = city
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.ownerId = ownerId
        self.photoURLs = photoURLs
        self.rating = rating
        self.reviewCount = reviewCount
        self.workHours = workHours
    }
}

struct WorkHours: Codable {
    var monday: DayHours
    var tuesday: DayHours
    var wednesday: DayHours
    var thursday: DayHours
    var friday: DayHours
    var saturday: DayHours
    var sunday: DayHours
    
    init() {
        monday = DayHours()
        tuesday = DayHours()
        wednesday = DayHours()
        thursday = DayHours()
        friday = DayHours()
        saturday = DayHours()
        sunday = DayHours()
    }
}

struct DayHours: Codable {
    var isOpen: Bool
    var openTime: String
    var closeTime: String
    
    init(isOpen: Bool = true, openTime: String = "09:00", closeTime: String = "17:00") {
        self.isOpen = isOpen
        self.openTime = openTime
        self.closeTime = closeTime
    }
}
