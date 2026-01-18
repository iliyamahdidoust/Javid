import Foundation
import CoreLocation

class GeocodingManager {
    static let shared = GeocodingManager()
    
    private let geocoder = CLGeocoder()
    
    private init() {}
    
    // Convert address to coordinates
    func geocodeAddress(address: String, city: String, country: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let fullAddress = "\(address), \(city), \(country)"
        
        geocoder.geocodeAddressString(fullAddress) { placemarks, error in
            if let error = error {
                print("❌ Geocoding error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let coordinate = placemarks?.first?.location?.coordinate {
                print("✅ Geocoded: \(fullAddress) -> (\(coordinate.latitude), \(coordinate.longitude))")
                completion(coordinate)
            } else {
                print("❌ No coordinates found for: \(fullAddress)")
                completion(nil)
            }
        }
    }
    
    // Reverse geocoding: coordinates to address
    func reverseGeocode(latitude: Double, longitude: Double, completion: @escaping (String?, String?, String?) -> Void) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("❌ Reverse geocoding error: \(error.localizedDescription)")
                completion(nil, nil, nil)
                return
            }
            
            if let placemark = placemarks?.first {
                let address = [placemark.thoroughfare, placemark.subThoroughfare]
                    .compactMap { $0 }
                    .joined(separator: " ")
                let city = placemark.locality ?? ""
                let country = placemark.country ?? ""
                
                completion(address, city, country)
            } else {
                completion(nil, nil, nil)
            }
        }
    }
}

