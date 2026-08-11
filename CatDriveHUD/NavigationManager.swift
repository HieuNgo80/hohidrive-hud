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

    /// Tính các điểm tuyến đường phía trước dạng tọa độ TƯƠNG ĐỐI so với xe
    /// để firmware vẽ mini map heading-up: dx > 0 = bên phải, dy > 0 = phía trước (đơn vị mét)
    /// - Returns: [[dx,dy], ...] tối đa 20 điểm, mỗi điểm cách nhau ~12m
    static func relativeRoutePoints(from location: CLLocation,
                                    routeCoords: [CLLocationCoordinate2D]) -> [[Int]] {
        guard routeCoords.count > 1 else { return [] }

        let lat0 = location.coordinate.latitude
        let lng0 = location.coordinate.longitude

        // Heading: ưu tiên course của GPS; nếu không có thì đoán từ 2 điểm polyline gần nhất
        var heading = location.course
        if heading < 0 {
            var nearest = 0
            var best = Double.greatestFiniteMagnitude
            for (i, p) in routeCoords.enumerated() {
                let d = CLLocation(latitude: p.latitude, longitude: p.longitude)
                    .distance(from: location)
                if d < best { best = d; nearest = i }
            }
            let a = routeCoords[nearest]
            let b = routeCoords[min(nearest + 1, routeCoords.count - 1)]
            let dLat = b.latitude - a.latitude
            let dLng = b.longitude - a.longitude
            heading = atan2(dLng * cos(a.latitude * .pi / 180), dLat) * 180 / .pi
        }
        if heading < 0 { heading += 360 }
        let h = heading * .pi / 180
        let cosH = cos(h)
        let sinH = sin(h)

        // Tìm điểm polyline gần xe nhất -> bắt đầu lấy từ đó
        var startIdx = 0
        var bestDist = Double.greatestFiniteMagnitude
        for (i, p) in routeCoords.enumerated() {
            let d = CLLocation(latitude: p.latitude, longitude: p.longitude)
                .distance(from: location)
            if d < bestDist { bestDist = d; startIdx = i }
        }

        var result: [[Int]] = []
        var last = routeCoords[startIdx]
        var accumulated: Double = 0
        let spacing: Double = 12 // mét giữa các điểm gửi đi

        func appendPoint(_ p: CLLocationCoordinate2D) {
            let dLat = (p.latitude - lat0) * 111320
            let dLng = (p.longitude - lng0) * 111320 * cos(lat0 * .pi / 180)
            let forward = dLat * cosH + dLng * sinH   // dy: phía trước
            let right = -dLat * sinH + dLng * cosH    // dx: bên phải
            result.append([Int(right.rounded()), Int(forward.rounded())])
        }

        appendPoint(last)
        for i in (startIdx + 1)..<routeCoords.count {
            let p = routeCoords[i]
            accumulated += CLLocation(latitude: p.latitude, longitude: p.longitude)
                .distance(from: CLLocation(latitude: last.latitude, longitude: last.longitude))
            if accumulated >= spacing {
                appendPoint(p)
                last = p
                accumulated = 0
                if result.count >= 20 { break }
            }
        }
        return result
    }
}
