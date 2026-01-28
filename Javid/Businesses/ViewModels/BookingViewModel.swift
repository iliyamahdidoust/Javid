import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class BookingViewModel: ObservableObject {
    @Published var userBookings: [Booking] = []
    @Published var businessBookings: [Booking] = []
    @Published var bookingSettings: BookingSettings?
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let db = Firestore.firestore()
    private var bookingsListener: ListenerRegistration?
    
    deinit {
        bookingsListener?.remove()
    }
    
    // MARK: - Booking Settings (Owner)
    
    func fetchBookingSettings(for businessId: String) {
        db.collection("booking_settings")
            .document(businessId)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching booking settings: \(error)")
                    return
                }
                
                if let data = snapshot?.data() {
                    self?.bookingSettings = try? snapshot?.data(as: BookingSettings.self)
                } else {
                    // Create default settings
                    self?.bookingSettings = BookingSettings(businessId: businessId, isEnabled: false)
                }
            }
    }
    
    func saveBookingSettings(_ settings: BookingSettings, completion: @escaping (Bool, String) -> Void) {
        guard let businessId = settings.businessId as String? else {
            completion(false, "Invalid business ID")
            return
        }
        
        var updatedSettings = settings
        updatedSettings.updatedAt = Date()
        
        do {
            try db.collection("booking_settings")
                .document(businessId)
                .setData(from: updatedSettings) { error in
                    if let error = error {
                        completion(false, "Failed to save settings: \(error.localizedDescription)")
                    } else {
                        self.bookingSettings = updatedSettings
                        completion(true, "Booking settings saved successfully")
                    }
                }
        } catch {
            completion(false, "Failed to encode settings: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Create Booking (Customer)
    
    func createBooking(_ booking: Booking, completion: @escaping (Bool, String) -> Void) {
        guard Auth.auth().currentUser != nil else {
            completion(false, "Please login to make a booking")
            return
        }
        
        // Check if slot is still available
        checkSlotAvailability(
            businessId: booking.businessId,
            date: booking.date,
            timeSlot: booking.timeSlot
        ) { [weak self] isAvailable, remaining in
            guard isAvailable else {
                completion(false, "This time slot is no longer available")
                return
            }
            
            // Create the booking
            do {
                try self?.db.collection("bookings")
                    .document(booking.id ?? UUID().uuidString)
                    .setData(from: booking) { error in
                        if let error = error {
                            completion(false, "Failed to create booking: \(error.localizedDescription)")
                        } else {
                            completion(true, "Booking created successfully! Please wait for confirmation.")
                        }
                    }
            } catch {
                completion(false, "Failed to create booking: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Fetch Bookings
    
    func fetchUserBookings() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        db.collection("bookings")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .getDocuments { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    print("Error fetching bookings: \(error)")
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                self?.userBookings = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: Booking.self)
                } ?? []
            }
    }
    
    func fetchBusinessBookings(for businessId: String) {
        isLoading = true
        
        bookingsListener?.remove()
        
        bookingsListener = db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .order(by: "date", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    print("Error fetching business bookings: \(error)")
                    return
                }
                
                self?.businessBookings = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: Booking.self)
                } ?? []
            }
    }
    
    // MARK: - Update Booking Status
    
    func updateBookingStatus(
        bookingId: String,
        status: BookingStatus,
        completion: @escaping (Bool, String) -> Void
    ) {
        db.collection("bookings")
            .document(bookingId)
            .updateData([
                "status": status.rawValue,
                "updatedAt": Date()
            ]) { error in
                if let error = error {
                    completion(false, "Failed to update: \(error.localizedDescription)")
                } else {
                    completion(true, "Booking \(status.displayName.lowercased()) successfully")
                }
            }
    }
    
    // MARK: - Cancel Booking
    
    func cancelBooking(_ booking: Booking, completion: @escaping (Bool, String) -> Void) {
        guard let bookingId = booking.id else {
            completion(false, "Invalid booking")
            return
        }
        
        updateBookingStatus(bookingId: bookingId, status: .cancelled, completion: completion)
    }
    
    // MARK: - Check Availability
    
    func checkSlotAvailability(
        businessId: String,
        date: Date,
        timeSlot: String,
        completion: @escaping (Bool, Int) -> Void
    ) {
        // Fetch booking settings
        db.collection("booking_settings")
            .document(businessId)
            .getDocument { [weak self] snapshot, error in
                guard let settings = try? snapshot?.data(as: BookingSettings.self) else {
                    completion(false, 0)
                    return
                }
                
                // Count existing bookings for this slot
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                self?.db.collection("bookings")
                    .whereField("businessId", isEqualTo: businessId)
                    .whereField("date", isGreaterThanOrEqualTo: startOfDay)
                    .whereField("date", isLessThan: endOfDay)
                    .whereField("timeSlot", isEqualTo: timeSlot)
                    .whereField("status", in: [BookingStatus.pending.rawValue, BookingStatus.confirmed.rawValue])
                    .getDocuments { snapshot, error in
                        let currentBookings = snapshot?.documents.count ?? 0
                        let remaining = settings.maxBookingsPerSlot - currentBookings
                        completion(remaining > 0, max(0, remaining))
                    }
            }
    }
    
    func getAvailableTimeSlots(
        for business: Business,
        on date: Date,
        completion: @escaping ([AvailableTimeSlot]) -> Void
    ) {
        guard let businessId = business.id else {
            completion([])
            return
        }
        
        db.collection("booking_settings")
            .document(businessId)
            .getDocument { [weak self] snapshot, error in
                guard let settings = try? snapshot?.data(as: BookingSettings.self),
                      settings.isEnabled else {
                    completion([])
                    return
                }
                
                // Check if date is within allowed range
                let calendar = Calendar.current
                let daysDiff = calendar.dateComponents([.day], from: Date(), to: date).day ?? 0
                guard daysDiff >= 0 && daysDiff <= settings.maxAdvanceBookingDays else {
                    completion([])
                    return
                }
                
                // Check if day is available
                let weekday = calendar.component(.weekday, from: date) - 1
                guard settings.availableDays.contains(weekday) else {
                    completion([])
                    return
                }
                
                // Generate time slots based on settings
                var availableSlots: [AvailableTimeSlot] = []
                
                for slot in settings.timeSlots {
                    let timeSlotString = "\(slot.startTime) - \(slot.endTime)"
                    
                    self?.checkSlotAvailability(
                        businessId: businessId,
                        date: date,
                        timeSlot: timeSlotString
                    ) { isAvailable, remaining in
                        availableSlots.append(AvailableTimeSlot(
                            time: timeSlotString,
                            isAvailable: isAvailable,
                            remainingSpots: remaining
                        ))
                        
                        if availableSlots.count == settings.timeSlots.count {
                            completion(availableSlots.sorted { $0.time < $1.time })
                        }
                    }
                }
                
                if settings.timeSlots.isEmpty {
                    completion([])
                }
            }
    }
    
    // MARK: - Analytics
    
    func getBookingSummary(for businessId: String) -> BookingSummary {
        let all = businessBookings.filter { $0.businessId == businessId }
        let today = Calendar.current.startOfDay(for: Date())
        
        return BookingSummary(
            totalBookings: all.count,
            pendingBookings: all.filter { $0.status == .pending }.count,
            confirmedBookings: all.filter { $0.status == .confirmed }.count,
            cancelledBookings: all.filter { $0.status == .cancelled }.count,
            completedBookings: all.filter { $0.status == .completed }.count,
            noShowBookings: all.filter { $0.status == .noShow }.count,
            todayBookings: all.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }.count,
            upcomingBookings: all.filter { $0.date >= Date() && ($0.status == .pending || $0.status == .confirmed) }.count
        )
    }
}
