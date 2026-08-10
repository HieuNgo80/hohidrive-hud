import Foundation
import CoreLocation
import MapKit

/// Một bước rẽ trong tuyến đường (từ Apple MapKit / MKDirections)
struct RouteStep {
    let instruction: String   // chỉ dẫn: "Rẽ trái vào Lê Lợi"
    let maneuver: String      // left | right | straight | arrive
    let endLat: Double
    let endLng: Double
    let distance: Int         // mét tới hết bước này
    let durationValue: Int    // giây đi hết bước này
}

/// Lấy tuyến đường bằng Apple MapKit (MKDirections) — miễn phí, không cần API key
class NavigationManager {

    /// Tính tuyến đường, trả về steps + thông tin tổng + tọa độ polyline để vẽ
    func fetchRoute(from: CLLocationCoordinate2D,
                    to: CLLocationCoordinate2D,
                    completion: @escaping ([RouteStep], Int, String, [CLLocationCoordinate2D]) -> Void) {

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let route = response?.routes.first else {
                DispatchQueue.main.async { completion([], 0, "", []) }
                return
            }

            // Tổng: thời gian + khoảng cách
            let totalDurationSec = Int(route.expectedTravelTime)
            let totalDistanceText = Self.formatDistance(route.distance)
            let totalDistance = route.steps.reduce(0.0) { $0 + $1.distance }

            // Từng bước rẽ (MKRouteStep) — MapKit không cho thời gian từng step,
            // nên chia tổng thời gian theo tỷ lệ quãng đường của từng bước
            var steps: [RouteStep] = []
            for s in route.steps {
                // Điểm cuối của bước này = điểm cuối polyline của step
                let pts = s.polyline.points()
                let end = pts[s.polyline.pointCount - 1].coordinate
                let stepDuration = totalDistance > 0
                    ? Int(Double(s.distance) / totalDistance * Double(totalDurationSec))
                    : 0
                steps.append(RouteStep(
                    instruction: s.instructions,
                    maneuver: Self.mapManeuver(s.instructions),
                    endLat: end.latitude,
                    endLng: end.longitude,
                    distance: Int(s.distance),
                    durationValue: stepDuration
                ))
            }

            // Tọa độ polyline tổng (để vẽ tuyến đường)
            var coords: [CLLocationCoordinate2D] = []
            let routePts = route.polyline.points()
            for i in 0..<route.polyline.pointCount {
                coords.append(routePts[i].coordinate)
            }

            DispatchQueue.main.async {
                completion(steps, totalDurationSec, totalDistanceText, coords)
            }
        }
    }

    /// Định dạng khoảng cách mét -> "25.4 km" / "800 m"
    static func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters)) m"
    }

    /// Đoán maneuver từ chữ chỉ dẫn của Apple (tiếng Việt/Anh)
    static func mapManeuver(_ instruction: String) -> String {
        let lower = instruction.lowercased()
        if lower.contains("trái") || lower.contains("left") { return "left" }
        if lower.contains("phải") || lower.contains("right") { return "right" }
        if lower.contains("đến nơi") || lower.contains("điểm đến")
            || lower.contains("arrive") || lower.contains("destination") { return "arrive" }
        return "straight"
    }
}
