import Foundation
import CoreLocation
import GoogleMaps

/// Một bước rẽ trong tuyến đường (từ Directions API)
struct RouteStep {
    let instruction: String   // tên đường / chỉ dẫn (đã bỏ thẻ HTML)
    let maneuver: String      // left | right | straight | arrive
    let endLat: Double
    let endLng: Double
    let distance: Int         // mét tới hết bước này
    let durationValue: Int    // giây đi hết bước này
}

/// Lấy tuyến đường từ Google Directions API + parse
class NavigationManager {

    /// Gọi Directions API, trả về steps + thông tin tổng
    func fetchRoute(from: CLLocationCoordinate2D,
                    to: CLLocationCoordinate2D,
                    apiKey: String,
                    completion: @escaping ([RouteStep], Int, String, String) -> Void) {

        let urlStr = "https://maps.googleapis.com/maps/api/directions/json"
            + "?origin=\(from.latitude),\(from.longitude)"
            + "&destination=\(to.latitude),\(to.longitude)"
            + "&mode=driving&language=vi&key=\(apiKey)"

        guard let url = URL(string: urlStr) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let routes = json["routes"] as? [[String: Any]],
                  let route = routes.first,
                  let legs = route["legs"] as? [[String: Any]],
                  let leg = legs.first else { return }

            // Khoảng cách + thời gian tổng
            var totalDistanceText = ""
            var totalDurationSec = 0
            if let dist = leg["distance"] as? [String: Any] {
                totalDistanceText = dist["text"] as? String ?? ""
            }
            if let dur = leg["duration"] as? [String: Any] {
                totalDurationSec = dur["value"] as? Int ?? 0
            }

            // Polyline tổng (để vẽ tuyến đường trên bản đồ)
            var overviewPoints = ""
            if let overview = route["overview_polyline"] as? [String: Any],
               let points = overview["points"] as? String {
                overviewPoints = points
            }

            // Từng bước rẽ
            var steps: [RouteStep] = []
            if let stepArr = leg["steps"] as? [[String: Any]] {
                for s in stepArr {
                    let end = s["end_location"] as? [String: Any] ?? [:]
                    let dist = s["distance"] as? [String: Any] ?? [:]
                    let dur = s["duration"] as? [String: Any] ?? [:]
                    let html = s["html_instructions"] as? String ?? ""
                    let maneuver = s["maneuver"] as? String ?? ""
                    steps.append(RouteStep(
                        instruction: Self.stripHTML(html),
                        maneuver: Self.mapManeuver(maneuver),
                        endLat: end["lat"] as? Double ?? 0,
                        endLng: end["lng"] as? Double ?? 0,
                        distance: dist["value"] as? Int ?? 0,
                        durationValue: dur["value"] as? Int ?? 0
                    ))
                }
            }

            DispatchQueue.main.async {
                completion(steps, totalDurationSec, totalDistanceText, overviewPoints)
            }
        }.resume()
    }

    /// Bỏ thẻ HTML trong chỉ dẫn: "<b>Rẽ trái</b> vào <b>Lê Lợi</b>" -> "Rẽ trái vào Lê Lợi"
    static func stripHTML(_ html: String) -> String {
        let cleaned = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return cleaned
            .replacingOccurrences(of: " +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Chuẩn hóa maneuver của Google thành mã HUD: left / right / straight / arrive
    static func mapManeuver(_ raw: String) -> String {
        if raw.contains("left") { return "left" }
        if raw.contains("right") { return "right" }
        if raw == "arrive" || raw == "destination" { return "arrive" }
        return "straight"
    }
}
