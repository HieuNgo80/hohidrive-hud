import Foundation
import CoreLocation
import MapKit

/// Một bước rẽ trong tuyến đường (Apple MapKit / MKDirections).
struct RouteStep {
    let instruction: String
    let roadName: String
    /// left | right | slight_left | slight_right | keep_left | keep_right |
    /// sharp_left | sharp_right | straight | uturn | roundabout | arrive
    let maneuver: String
    let roundaboutExit: Int
    let endLat: Double
    let endLng: Double
    let distance: Int
    let durationValue: Int
    /// Hình học chi tiết của riêng step. Dùng để tính khoảng cách theo ĐƯỜNG ĐI,
    /// thay vì đo đường chim bay tới điểm cuối step.
    let polylineCoordinates: [CLLocationCoordinate2D]
}

/// Apple MapKit route helper.
final class NavigationManager {

    func fetchRoute(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        completion: @escaping ([RouteStep], Int, String, [CLLocationCoordinate2D]) -> Void
    ) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        MKDirections(request: request).calculate { response, _ in
            guard let route = response?.routes.first else {
                DispatchQueue.main.async { completion([], 0, "", []) }
                return
            }

            let totalDurationSec = Int(route.expectedTravelTime)
            let totalDistanceText = Self.formatDistance(route.distance)
            let totalStepDistance = route.steps.reduce(0.0) { $0 + $1.distance }

            var steps: [RouteStep] = []
            for step in route.steps {
                let coords = Self.coordinates(from: step.polyline)
                guard let end = coords.last else { continue }

                let duration = totalStepDistance > 0
                    ? Int(step.distance / totalStepDistance * Double(totalDurationSec))
                    : 0

                let instruction = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
                let maneuver = Self.mapManeuver(instruction)
                steps.append(
                    RouteStep(
                        instruction: instruction,
                        roadName: Self.extractRoadName(from: instruction),
                        maneuver: maneuver,
                        roundaboutExit: maneuver == "roundabout" ? Self.extractRoundaboutExit(from: instruction) : 0,
                        endLat: end.latitude,
                        endLng: end.longitude,
                        distance: Int(step.distance.rounded()),
                        durationValue: duration,
                        polylineCoordinates: coords
                    )
                )
            }

            let routeCoordinates = Self.coordinates(from: route.polyline)
            DispatchQueue.main.async {
                completion(steps, totalDurationSec, totalDistanceText, routeCoordinates)
            }
        }
    }

    private static func coordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        guard polyline.pointCount > 0 else { return [] }
        let points = polyline.points()
        return (0..<polyline.pointCount).map { points[$0].coordinate }
    }

    static func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(max(0, Int(meters.rounded()))) m"
    }

    static func mapManeuver(_ instruction: String) -> String {
        let lower = instruction.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        if lower.contains("roundabout") || lower.contains("traffic circle") || lower.contains("rotary")
            || lower.contains("vong xoay") || lower.contains("bung binh") {
            return "roundabout"
        }
        if lower.contains("quay dau") || lower.contains("u-turn") || lower.contains("u turn")
            || lower.contains("make a u-turn") || lower.contains("turn around") {
            return "uturn"
        }
        if lower.contains("den noi") || lower.contains("diem den")
            || lower.contains("arrive") || lower.contains("destination")
            || lower.contains("you have arrived") {
            return "arrive"
        }
        if lower.contains("keep left") || lower.contains("giu ben trai") { return "keep_left" }
        if lower.contains("keep right") || lower.contains("giu ben phai") { return "keep_right" }
        if lower.contains("slight left") || lower.contains("chech trai") { return "slight_left" }
        if lower.contains("slight right") || lower.contains("chech phai") { return "slight_right" }
        if lower.contains("sharp left") { return "sharp_left" }
        if lower.contains("sharp right") { return "sharp_right" }
        if lower.contains("re trai") || lower.contains("left") { return "left" }
        if lower.contains("re phai") || lower.contains("right") { return "right" }
        return "straight"
    }

    /// Lấy số lối ra ở vòng xoay nếu Apple cung cấp trong câu chỉ dẫn.
    static func extractRoundaboutExit(from instruction: String) -> Int {
        let lower = instruction.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard lower.contains("roundabout") || lower.contains("traffic circle") || lower.contains("rotary")
                || lower.contains("vong xoay") || lower.contains("bung binh") else { return 0 }

        let patterns = [
            #"(?:exit|loi ra|loi thoat)[^0-9]{0,16}([0-9]{1,2})"#,
            #"(?:take|lay|chon)[^0-9]{0,16}([0-9]{1,2})(?:st|nd|rd|th)?[^a-z0-9]{0,8}(?:exit|loi ra)"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..<lower.endIndex, in: lower)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: lower),
               let value = Int(lower[range]) {
                return value
            }
        }

        let wordOrdinals: [(String, Int)] = [
            ("first exit", 1), ("second exit", 2), ("third exit", 3), ("fourth exit", 4),
            ("fifth exit", 5), ("sixth exit", 6), ("seventh exit", 7), ("eighth exit", 8),
            ("loi ra thu nhat", 1), ("loi ra thu hai", 2), ("loi ra thu ba", 3),
            ("loi ra thu tu", 4), ("loi ra thu nam", 5), ("loi ra thu sau", 6)
        ]
        for item in wordOrdinals where lower.contains(item.0) { return item.1 }
        return 0
    }

    static func extractRoadName(from instruction: String) -> String {
        let text = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        let separators = [
            " vào ", " tại ", " trên ", " theo ", " qua ", " đến ",
            " onto ", " on ", " via ", " toward ", " towards ", " along "
        ]

        for separator in separators {
            if let range = text.range(of: separator, options: [.caseInsensitive, .diacriticInsensitive]) {
                var road = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                road = road.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                if !road.isEmpty { return road }
            }
        }

        let prefixes = [
            "turn left ", "turn right ", "turn around ",
            "rẽ trái ", "rẽ phải ", "quay đầu ",
            "keep left ", "keep right ", "slight left ", "slight right ",
            "sharp left ", "sharp right ", "continue "
        ]
        for prefix in prefixes {
            if text.range(of: prefix, options: [.caseInsensitive, .diacriticInsensitive])?.lowerBound == text.startIndex {
                let start = text.index(text.startIndex, offsetBy: prefix.count, limitedBy: text.endIndex) ?? text.endIndex
                let road = String(text[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !road.isEmpty { return road }
            }
        }

        let lower = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if lower.contains("head ") || lower.contains("di ve huong") || lower.contains("di ve") { return "" }
        return text
    }

    // MARK: - Route progress geometry

    /// Khoảng cách vuông góc từ GPS hiện tại đến polyline gần nhất.
    static func distanceToPolyline(from location: CLLocation, coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 2 else { return .greatestFiniteMagnitude }
        var best = Double.greatestFiniteMagnitude
        for i in 0..<(coordinates.count - 1) {
            let segment = projectedSegment(location: location, a: coordinates[i], b: coordinates[i + 1])
            best = min(best, segment.distance)
        }
        return best
    }

    /// Khoảng cách còn lại dọc THEO polyline tới cuối step, không phải đường chim bay.
    static func remainingDistanceAlongPolyline(from location: CLLocation, coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 2 else {
            guard let last = coordinates.last else { return .greatestFiniteMagnitude }
            return location.distance(from: CLLocation(latitude: last.latitude, longitude: last.longitude))
        }

        var bestDistance = Double.greatestFiniteMagnitude
        var bestIndex = 0
        var bestT = 0.0

        for i in 0..<(coordinates.count - 1) {
            let segment = projectedSegment(location: location, a: coordinates[i], b: coordinates[i + 1])
            if segment.distance < bestDistance {
                bestDistance = segment.distance
                bestIndex = i
                bestT = segment.t
            }
        }

        let a = CLLocation(latitude: coordinates[bestIndex].latitude, longitude: coordinates[bestIndex].longitude)
        let b = CLLocation(latitude: coordinates[bestIndex + 1].latitude, longitude: coordinates[bestIndex + 1].longitude)
        var remaining = a.distance(from: b) * (1.0 - bestT)

        if bestIndex + 1 < coordinates.count - 1 {
            for i in (bestIndex + 1)..<(coordinates.count - 1) {
                let p0 = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
                let p1 = CLLocation(latitude: coordinates[i + 1].latitude, longitude: coordinates[i + 1].longitude)
                remaining += p0.distance(from: p1)
            }
        }
        return max(0, remaining)
    }

    /// Chọn step gần xe nhất trong cửa sổ nhỏ quanh step hiện tại.
    /// Không quét toàn tuyến để tránh nhảy nhầm sang đoạn đường song song phía xa trong hành trình.
    static func nearestStepIndex(from location: CLLocation, steps: [RouteStep], currentIndex: Int) -> Int {
        guard !steps.isEmpty else { return 0 }
        let start = max(0, currentIndex - 1)
        let end = min(steps.count - 1, currentIndex + 3)
        var bestIndex = min(max(currentIndex, 0), steps.count - 1)
        var bestDistance = Double.greatestFiniteMagnitude

        for i in start...end {
            let d = distanceToPolyline(from: location, coordinates: steps[i].polylineCoordinates)
            if d < bestDistance {
                bestDistance = d
                bestIndex = i
            }
        }
        return max(currentIndex, bestIndex)
    }

    private static func projectedSegment(
        location: CLLocation,
        a: CLLocationCoordinate2D,
        b: CLLocationCoordinate2D
    ) -> (distance: Double, t: Double) {
        let lat0 = location.coordinate.latitude * .pi / 180
        let metersLat = 111_320.0
        let metersLng = 111_320.0 * cos(lat0)

        let ax = (a.longitude - location.coordinate.longitude) * metersLng
        let ay = (a.latitude - location.coordinate.latitude) * metersLat
        let bx = (b.longitude - location.coordinate.longitude) * metersLng
        let by = (b.latitude - location.coordinate.latitude) * metersLat

        let vx = bx - ax
        let vy = by - ay
        let lengthSquared = vx * vx + vy * vy
        if lengthSquared <= 0.0001 { return (hypot(ax, ay), 0) }

        let rawT = -(ax * vx + ay * vy) / lengthSquared
        let t = min(1.0, max(0.0, rawT))
        let px = ax + t * vx
        let py = ay + t * vy
        return (hypot(px, py), t)
    }

    // MARK: - Legacy mini-map helpers retained for compatibility

    static func relativeRoutePoints(from location: CLLocation,
                                    routeCoords: [CLLocationCoordinate2D]) -> [[Int]] {
        guard routeCoords.count > 1 else { return [] }

        let lat0 = location.coordinate.latitude
        let lng0 = location.coordinate.longitude
        var heading = location.course
        if heading < 0 {
            var nearest = 0
            var best = Double.greatestFiniteMagnitude
            for (i, p) in routeCoords.enumerated() {
                let d = CLLocation(latitude: p.latitude, longitude: p.longitude).distance(from: location)
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
        let cosH = cos(h), sinH = sin(h)

        var startIdx = 0
        var bestDist = Double.greatestFiniteMagnitude
        for (i, p) in routeCoords.enumerated() {
            let d = CLLocation(latitude: p.latitude, longitude: p.longitude).distance(from: location)
            if d < bestDist { bestDist = d; startIdx = i }
        }

        var result: [[Int]] = []
        var last = routeCoords[startIdx]
        var accumulated: Double = 0
        let spacing: Double = 12

        func appendPoint(_ p: CLLocationCoordinate2D) {
            let dLat = (p.latitude - lat0) * 111320
            let dLng = (p.longitude - lng0) * 111320 * cos(lat0 * .pi / 180)
            let forward = dLat * cosH + dLng * sinH
            let right = -dLat * sinH + dLng * cosH
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

    static func makeMapBitmap(routePoints: [[Int]], width: Int = 128, height: Int = 64) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let carX = width / 2
        let carY = height / 2 + 6

        var maxDy = 10, maxDx = 10
        for p in routePoints where p.count >= 2 {
            maxDy = max(maxDy, p[1])
            maxDx = max(maxDx, abs(p[0]))
        }
        let scale = min(Float(carY - 4) / Float(maxDy), Float(width / 2 - 6) / Float(maxDx + 4))
        let s = scale > 2.0 ? 2.0 : (scale < 0.05 ? 0.05 : scale)

        var pts: [(Int, Int)] = []
        for p in routePoints where p.count >= 2 {
            pts.append((carX + Int(Float(p[0]) * s), carY - Int(Float(p[1]) * s)))
        }

        func setPixel(_ x: Int, _ y: Int) {
            if x >= 0 && x < width && y >= 0 && y < height { pixels[y * width + x] = 1 }
        }
        func drawLine(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) {
            var x0 = x0, y0 = y0
            let dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1
            let dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1
            var err = dx + dy
            while true {
                setPixel(x0, y0)
                if x0 == x1 && y0 == y1 { break }
                let e2 = 2 * err
                if e2 >= dy { err += dy; x0 += sx }
                if e2 <= dx { err += dx; y0 += sy }
            }
        }

        if pts.count >= 2 {
            for i in 1..<pts.count { drawLine(pts[i - 1].0, pts[i - 1].1, pts[i].0, pts[i].1) }
        }
        for dy in -2...2 {
            for dx in -2...2 where dx * dx + dy * dy <= 4 { setPixel(carX + dx, carY + dy) }
        }

        var bytes = [UInt8](repeating: 0, count: width * height / 8)
        for y in 0..<height {
            for x in 0..<width where pixels[y * width + x] == 1 {
                bytes[y * (width / 8) + x / 8] |= UInt8(1 << (7 - (x % 8)))
            }
        }
        return bytes
    }
}
