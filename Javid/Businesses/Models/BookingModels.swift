import Foundation
import FirebaseFirestore

// MARK: - Booking Settings (configured by business owner)
struct BookingSettings: Identifiable, Codable {
    @DocumentID var id: String?
    var businessId: String
    var isEnabled: Bool
    
    // Availability
    var availableDays: [Int] // 0 = Sunday, 1 = Monday, etc.
    var timeSlots: [TimeSlot]
    var slotDuration: Int // in minutes (e.g., 30, 60)
    var maxAdvanceBookingDays: Int // how far in advance customers can book
    
    // Capacity
    var maxPartySize: Int
    var maxBookingsPerSlot: Int
    
    // Requirements
    var requiresDeposit: Bool
    var depositAmount: Double?
    var cancellationPolicy: String?
    var specialInstructions: String?
    
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String? = nil,
        businessId: String,
        isEnabled: Bool = true,
        availableDays: [Int] = [1, 2, 3, 4, 5, 6], // Mon-Sat
        timeSlots: [TimeSlot] = [],
        slotDuration: Int = 60,
        maxAdvanceBookingDays: Int = 30,
        maxPartySize: Int = 10,
        maxBookingsPerSlot: Int = 5,
        requiresDeposit: Bool = false,
        depositAmount: Double? = nil,
        cancellationPolicy: String? = nil,
        specialInstructions: String? = nil
    ) {
        self.id = id
        self.businessId = businessId
        self.isEnabled = isEnabled
        self.availableDays = availableDays
        self.timeSlots = timeSlots.isEmpty ? TimeSlot.defaultSlots() : timeSlots
        self.slotDuration = slotDuration
        self.maxAdvanceBookingDays = maxAdvanceBookingDays
        self.maxPartySize = maxPartySize
        self.maxBookingsPerSlot = maxBookingsPerSlot
        self.requiresDeposit = requiresDeposit
        self.depositAmount = depositAmount
        self.cancellationPolicy = cancellationPolicy
        self.specialInstructions = specialInstructions
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Time Slot
struct TimeSlot: Identifiable, Codable, Hashable {
    var id: String
    var startTime: String // "09:00"
    var endTime: String // "17:00"
    
    init(id: String = UUID().uuidString, startTime: String, endTime: String) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
    }
    
    static func defaultSlots() -> [TimeSlot] {
        [
            TimeSlot(startTime: "09:00", endTime: "12:00"),
            TimeSlot(startTime: "12:00", endTime: "15:00"),
            TimeSlot(startTime: "15:00", endTime: "18:00"),
            TimeSlot(startTime: "18:00", endTime: "21:00")
        ]
    }
}

// MARK: - Booking (individual reservation)
struct Booking: Identifiable, Codable {
    @DocumentID var id: String?
    var businessId: String
    var userId: String
    var userName: String
    var userEmail: String
    var userPhone: String
    
    // Booking details
    var date: Date
    var timeSlot: String // "09:00 - 10:00"
    var partySize: Int
    var specialRequests: String?
    
    // Status
    var status: BookingStatus
    var createdAt: Date
    var updatedAt: Date
    
    // Payment (if required)
    var depositPaid: Bool
    var depositAmount: Double?
    
    // Business info (cached for display)
    var businessName: String
    var businessAddress: String
    
    init(
        id: String? = nil,
        businessId: String,
        userId: String,
        userName: String,
        userEmail: String,
        userPhone: String,
        date: Date,
        timeSlot: String,
        partySize: Int,
        specialRequests: String? = nil,
        status: BookingStatus = .pending,
        depositPaid: Bool = false,
        depositAmount: Double? = nil,
        businessName: String,
        businessAddress: String
    ) {
        self.id = id
        self.businessId = businessId
        self.userId = userId
        self.userName = userName
        self.userEmail = userEmail
        self.userPhone = userPhone
        self.date = date
        self.timeSlot = timeSlot
        self.partySize = partySize
        self.specialRequests = specialRequests
        self.status = status
        self.createdAt = Date()
        self.updatedAt = Date()
        self.depositPaid = depositPaid
        self.depositAmount = depositAmount
        self.businessName = businessName
        self.businessAddress = businessAddress
    }
}

// MARK: - Booking Status
enum BookingStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case confirmed = "confirmed"
    case cancelled = "cancelled"
    case completed = "completed"
    case noShow = "no_show"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .cancelled: return "Cancelled"
        case .completed: return "Completed"
        case .noShow: return "No Show"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .confirmed: return "green"
        case .cancelled: return "red"
        case .completed: return "blue"
        case .noShow: return "gray"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .confirmed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .completed: return "checkmark.seal.fill"
        case .noShow: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Available Time Slot (for display)
struct AvailableTimeSlot: Identifiable {
    let id = UUID()
    let time: String
    let isAvailable: Bool
    let remainingSpots: Int
    
    var displayTime: String {
        time
    }
}

// MARK: - Booking Summary (for analytics)
struct BookingSummary {
    var totalBookings: Int
    var pendingBookings: Int
    var confirmedBookings: Int
    var cancelledBookings: Int
    var completedBookings: Int
    var noShowBookings: Int
    var todayBookings: Int
    var upcomingBookings: Int
    
    static var empty: BookingSummary {
        BookingSummary(
            totalBookings: 0,
            pendingBookings: 0,
            confirmedBookings: 0,
            cancelledBookings: 0,
            completedBookings: 0,
            noShowBookings: 0,
            todayBookings: 0,
            upcomingBookings: 0
        )
    }
}
