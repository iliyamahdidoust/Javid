import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    @Published var cityName: String? // NEW: For displaying city name in UI
    
    private var lastUpdateTime: Date?
    private let updateInterval: TimeInterval = 10 // Only update every 10 seconds
    private let geocoder = CLGeocoder() // NEW: For reverse geocoding
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters // Less accurate but faster
        locationManager.distanceFilter = 100 // Only update if moved 100 meters
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdating() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }
    
    func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1000
    }
    
    // NEW: Method to manually update location (for location picker)
    func updateLocation(latitude: Double, longitude: Double, cityName: String) {
        let newLocation = CLLocation(latitude: latitude, longitude: longitude)
        self.location = newLocation
        self.cityName = cityName
        self.lastUpdateTime = Date() // Reset throttle timer
    }
    
    // NEW: Private method to get city name from location
    private func getCityName(from location: CLLocation) {
        // Cancel any pending geocoding requests
        geocoder.cancelGeocode()
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Reverse geocoding error: \(error.localizedDescription)")
                // Don't update cityName on error, keep the previous value
                return
            }
            
            if let placemark = placemarks?.first {
                // Build city name with priority: City, State format
                var components: [String] = []
                
                if let city = placemark.locality {
                    components.append(city)
                }
                
                if let state = placemark.administrativeArea {
                    components.append(state)
                }
                
                // If we have both city and state, join them
                if !components.isEmpty {
                    DispatchQueue.main.async {
                        self.cityName = components.joined(separator: ", ")
                    }
                } else if let subLocality = placemark.subLocality {
                    // Fallback to subLocality if city is not available
                    DispatchQueue.main.async {
                        self.cityName = subLocality
                    }
                } else if let name = placemark.name {
                    // Last resort: use the place name
                    DispatchQueue.main.async {
                        self.cityName = name
                    }
                }
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdating()
        case .denied, .restricted:
            locationError = "Location access denied. Please enable in Settings."
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // Throttle updates
        if let lastUpdate = lastUpdateTime,
           Date().timeIntervalSince(lastUpdate) < updateInterval {
            return
        }
        
        location = newLocation
        lastUpdateTime = Date()
        
        // NEW: Get city name for the new location
        // Only geocode if we don't have a city name or location changed significantly
        if cityName == nil || shouldUpdateCityName(for: newLocation) {
            getCityName(from: newLocation)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = "Failed to get location: \(error.localizedDescription)"
    }
    
    // NEW: Helper to determine if we should update city name
    // This prevents excessive geocoding calls
    private func shouldUpdateCityName(for newLocation: CLLocation) -> Bool {
        guard let currentLocation = location else { return true }
        
        // Only update city name if we've moved more than 5km
        let distance = newLocation.distance(from: currentLocation)
        return distance > 5000
    }
}
