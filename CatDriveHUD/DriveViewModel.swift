import Foundation
import SwiftUI
import MapKit
import CoreLocation

struct DriveStop: Identifiable, Codable {
    let id: UUID
    var address: String
    var coordinate: CLLocationCoordinate2D? = nil
    var completed: Bool = false
    var completedAt: Date? = nil

    init(id: UUID = UUID(), address: String, coordinate: CLLocationCoordinate2D? = nil, completed: Bool = false, completedAt: Date? = nil) {
        self.id = id
        self.address = address
        self.coordinate = coordinate
        self.completed = completed
        self.completedAt = completedAt
    }

    enum CodingKeys: String, CodingKey { case id, address, latitude, longitude, completed, completedAt }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        address = try c.decode(String.self, forKey: .address)
        completed = try c.decode(Bool.self, forKey: .completed)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        if let lat = try c.decodeIfPresent(Double.self, forKey: .latitude), let lng = try c.decodeIfPresent(Double.self, forKey: .longitude) {
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(address, forKey: .address)
        try c.encode(completed, forKey: .completed)
        try c.encodeIfPresent(completedAt, forKey: .completedAt)
        try c.encodeIfPresent(coordinate?.latitude, forKey: .latitude)
        try c.encodeIfPresent(coordinate?.longitude, forKey: .longitude)
    }
}

struct CompletedTrip: Identifiable, Codable {
    let id: UUID
    let destination: String
    let distance: String
    let duration: String
    let completedAt: Date
    let stopNumber: Int
    var orderCount: Int

    init(id: UUID = UUID(), destination: String, distance: String, duration: String, completedAt: Date = Date(), stopNumber: Int, orderCount: Int = 0) {
        self.id = id; self.destination = destination; self.distance = distance; self.duration = duration; self.completedAt = completedAt; self.stopNumber = stopNumber; self.orderCount = orderCount
    }
}

final class DriveViewModel: NSObject, ObservableObject {
    @Published var stops: [DriveStop] = [DriveStop(address: "")]
    @Published var currentLocation: CLLocation?
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var routeSteps: [RouteStep] = []
    @Published var currentStepIndex = 0
    @Published var currentStopIndex = 0
    @Published var isNavigating = false
    @Published var isCalculating = false
    @Published var statusText = "Ready for a new trip"
    @Published var connectionText = "HUD not connected"
    @Published var hudConnected = false
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var activeStopID: UUID?
    @Published var completedTrips: [CompletedTrip] = []
    @Published var showArrival = false
    @Published var lastCompletedStopNumber = 0
    @Published var mapType: MKMapType = .standard
    @Published var followUser = false
    @Published var headingMode = false
    @Published var centerRequest = 0
    @Published var selectedOrderTab = 0

    let maxStops = 6
    let locationManager = CLLocationManager()
    let ble = BLEManager()
    let nav = NavigationManager()
    let completer = MKLocalSearchCompleter()

    private var pendingCoordinate: CLLocationCoordinate2D?
    private var pendingStopID: UUID?
    private var lastSentTime: TimeInterval = 0
    private let turnPreviewDistanceM: Double = 100

    var qrString: String {
        get { UserDefaults.standard.string(forKey: "qrString") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "qrString") }
    }

    var nextIncompleteIndex: Int? {
        stops.firstIndex { !$0.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.completed }
    }

    var completedCount: Int { stops.filter(\.completed).count }

    override init() {
        super.init()
        loadHistory()
        setupLocation()
        setupCompleter()
        setupBLE()
    }

    func addStop() {
        guard stops.count < maxStops else { statusText = "Tối đa \(maxStops) chặng"; return }
        stops.append(DriveStop(address: ""))
        activeStopID = stops.last?.id
    }

    func removeStop(id: UUID) {
        guard let index = stops.firstIndex(where: { $0.id == id }), !stops[index].completed else { return }

        // Luôn giữ ít nhất một ô Destination để Home không rơi vào trạng thái mảng rỗng.
        // Dùng UUID thay vì giữ index qua các callback async để tránh crash khi người dùng xóa chặng.
        if stops.count == 1 {
            stops[0].address = ""
            stops[0].coordinate = nil
            activeStopID = stops[0].id
            suggestions = []
            return
        }

        let wasActive = activeStopID == id
        stops.remove(at: index)
        if wasActive {
            activeStopID = stops.indices.contains(index) ? stops[index].id : stops.last?.id
        }
        suggestions = []
    }

    func updateStop(_ text: String, id: UUID) {
        guard let i = stops.firstIndex(where: { $0.id == id }), !stops[i].completed else { return }
        stops[i].address = text
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            stops[i].coordinate = nil
            suggestions = []
            return
        }
        activeStopID = id
        completer.queryFragment = text
    }

    func chooseSuggestion(_ completion: MKLocalSearchCompletion) {
        guard let stopID = activeStopID else { return }
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { [weak self] response, _ in
            guard let self, let item = response?.mapItems.first else { return }
            DispatchQueue.main.async {
                // Tìm lại index theo UUID sau khi search trả về. Nếu chặng đã bị xóa thì bỏ callback.
                guard let index = self.stops.firstIndex(where: { $0.id == stopID }) else { return }
                self.stops[index].address = completion.title
                self.stops[index].coordinate = item.placemark.coordinate
                self.suggestions = []
                self.statusText = "Đã chọn điểm \(index + 1)"
            }
        }
    }

    func startOrContinue() {
        guard !isCalculating else { return }
        let filled = stops.filter { !$0.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !filled.isEmpty else { statusText = "Nhập ít nhất 1 điểm đến"; return }

        if let idx = nextIncompleteIndex {
            currentStopIndex = idx
            resolveCoordinatesThenStart(stopID: stops[idx].id)
        } else {
            resetTrip()
            if let idx = nextIncompleteIndex { resolveCoordinatesThenStart(stopID: stops[idx].id) }
        }
    }

    func continueNextStage() {
        showArrival = false
        guard let idx = nextIncompleteIndex else {
            statusText = "🎉 Đã hoàn thành tất cả chặng"
            sendIdleToHUD()
            return
        }
        currentStopIndex = idx
        resolveCoordinatesThenStart(stopID: stops[idx].id)
    }

    func startNewTrip() {
        isNavigating = false
        isCalculating = false
        routeSteps = []
        routeCoordinates = []
        currentStepIndex = 0
        currentStopIndex = 0
        showArrival = false
        lastCompletedStopNumber = 0
        stops = [DriveStop(address: "")]
        activeStopID = nil
        suggestions = []
        followUser = true
        centerRequest &+= 1
        sendIdleToHUD()
        statusText = "Sẵn sàng cho chuyến mới"
    }

    func stopNavigation() {
        isNavigating = false
        isCalculating = false
        routeSteps = []
        routeCoordinates = []
        currentStepIndex = 0
        sendIdleToHUD()
        statusText = "Đã dừng chuyến"
    }

    /// Dùng để test UI hoàn thành chặng ngay trên iPhone. Không thay đổi firmware OLED.
    func simulateArrival() {
        guard isNavigating, !routeSteps.isEmpty else {
            statusText = "Chưa có chặng đang dẫn đường để giả lập"
            return
        }
        arriveCurrentStage()
    }

    func centerOnUser() {
        followUser = true
        centerRequest &+= 1
        mapViewTrackingHint()
    }

    func toggleHeading() {
        headingMode.toggle()
        followUser = true
        centerRequest &+= 1
        mapViewTrackingHint()
    }

    private func mapViewTrackingHint() {}

    func zoomMap(_ factor: Double, mapView: MKMapView?) {
        guard let mapView else { return }
        var r = mapView.region
        r.span.latitudeDelta *= factor
        r.span.longitudeDelta *= factor
        mapView.setRegion(r, animated: true)
    }

    func selectSuggestionField(id: UUID) { activeStopID = id }

    func updateOrderCount(id: UUID, value: Int) {
        guard let i = completedTrips.firstIndex(where: { $0.id == id }) else { return }
        completedTrips[i].orderCount = max(0, value)
        saveHistory()
    }

    func clearHistory() {
        completedTrips.removeAll()
        saveHistory()
    }

    func saveQR(_ value: String) {
        qrString = value.trimmingCharacters(in: .whitespacesAndNewlines)
        statusText = qrString.isEmpty ? "Đã xóa dữ liệu thanh toán" : "Đã lưu dữ liệu thanh toán"
    }

    private func resetTrip() {
        for i in stops.indices {
            stops[i].completed = false
            stops[i].completedAt = nil
        }
        routeSteps = []
        routeCoordinates = []
        currentStepIndex = 0
        currentStopIndex = 0
        showArrival = false
    }

    private func resolveCoordinatesThenStart(stopID: UUID) {
        guard let index = stops.firstIndex(where: { $0.id == stopID }) else { return }
        let destinationText = stops[index].address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destinationText.isEmpty else {
            statusText = "Chặng \(index + 1) chưa có địa chỉ"
            return
        }

        isCalculating = true
        statusText = "Đang tìm địa chỉ…"

        if let coordinate = stops[index].coordinate {
            fetchLeg(to: coordinate, stopID: stopID)
            return
        }

        CLGeocoder().geocodeAddressString(destinationText) { [weak self] placemarks, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                guard let currentIndex = self.stops.firstIndex(where: { $0.id == stopID }) else {
                    self.isCalculating = false
                    return
                }
                guard let coordinate = placemarks?.first?.location?.coordinate else {
                    self.isCalculating = false
                    self.statusText = "Không tìm thấy: \(destinationText)"
                    return
                }
                self.stops[currentIndex].coordinate = coordinate
                self.fetchLeg(to: coordinate, stopID: stopID)
            }
        }
    }

    private func fetchLeg(to destination: CLLocationCoordinate2D, stopID: UUID) {
        guard let currentIndex = stops.firstIndex(where: { $0.id == stopID }) else {
            isCalculating = false
            return
        }

        guard let origin = locationManager.location?.coordinate ?? currentLocation?.coordinate else {
            pendingCoordinate = destination
            pendingStopID = stopID
            currentStopIndex = currentIndex
            statusText = "Đang chờ vị trí GPS…"
            return
        }

        nav.fetchRoute(from: origin, to: destination) { [weak self] steps, _, totalDistanceText, coordinates in
            guard let self else { return }
            self.isCalculating = false

            guard let resolvedIndex = self.stops.firstIndex(where: { $0.id == stopID }) else { return }
            guard !steps.isEmpty, !coordinates.isEmpty else {
                self.statusText = "Không tìm thấy tuyến đường"
                return
            }

            self.currentStopIndex = resolvedIndex
            self.routeSteps = steps
            self.routeCoordinates = coordinates
            self.currentStepIndex = 0
            self.isNavigating = true
            self.followUser = true
            self.centerRequest &+= 1
            self.statusText = "Đang dẫn đường · Chặng \(resolvedIndex + 1)/\(self.stops.count) · \(totalDistanceText)"
            self.sendCurrentNavigation(force: true)
        }
    }

    private func updateNavigation(_ location: CLLocation) {
        guard isNavigating, !routeSteps.isEmpty else { return }
        var bestIndex = currentStepIndex
        var bestDistance = Double.greatestFiniteMagnitude
        for i in currentStepIndex..<routeSteps.count {
            let s = routeSteps[i]
            let end = CLLocation(latitude: s.endLat, longitude: s.endLng)
            let d = end.distance(from: location)
            if d < bestDistance { bestDistance = d; bestIndex = i }
        }
        if bestDistance < 30, bestIndex < routeSteps.count - 1 { bestIndex += 1 }
        currentStepIndex = bestIndex

        if bestDistance < 40 && (routeSteps[bestIndex].maneuver == "arrive" || bestIndex == routeSteps.count - 1) {
            arriveCurrentStage()
            return
        }
        sendCurrentNavigation(force: false)
    }

    private func arriveCurrentStage() {
        guard !showArrival else { return }
        isNavigating = false
        let idx = currentStopIndex
        guard stops.indices.contains(idx) else { return }
        let destination = stops[idx].address
        let duration = formatDuration(routeSteps.reduce(0) { $0 + $1.durationValue })
        let totalDistance = NavigationManager.formatDistance(Double(routeSteps.reduce(0) { $0 + $1.distance }))
        stops[idx].completed = true
        stops[idx].completedAt = Date()
        completedTrips.insert(CompletedTrip(destination: destination, distance: totalDistance, duration: duration, stopNumber: idx + 1), at: 0)
        completedTrips = Array(completedTrips.prefix(100))
        saveHistory()
        lastCompletedStopNumber = idx + 1

        let eta = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        ble.send(json: [
            "speed": 0,
            "distance": 0,
            "next_road": "ĐÃ ĐẾN NƠI",
            "next_road_sub": "",
            "eta": eta,
            "ete": "",
            "total_distance": totalDistance,
            "maneuver": "arrive",
            "qr": qrString,
            "next": ""
        ])
        showArrival = true
        statusText = "Đã hoàn thành chặng \(idx + 1)"
    }

    private func sendCurrentNavigation(force: Bool) {
        guard let location = locationManager.location, !routeSteps.isEmpty else { return }
        let now = Date().timeIntervalSince1970
        if !force && now - lastSentTime < 0.35 { return }
        lastSentTime = now

        let step = routeSteps[currentStepIndex]
        let distance = CLLocation(latitude: step.endLat, longitude: step.endLng).distance(from: location)
        var remainingSec = 0
        for i in currentStepIndex..<routeSteps.count { remainingSec += routeSteps[i].durationValue }
        let eta = Date().addingTimeInterval(TimeInterval(remainingSec))
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
        let displayManeuver = maneuverForHUD(step: step, distance: distance)
        let road = roadNameForHUD(stepIndex: currentStepIndex, distance: distance)
        let totalDistance = NavigationManager.formatDistance(Double(routeSteps.reduce(0) { $0 + $1.distance }))
        let relative = NavigationManager.relativeRoutePoints(from: location, routeCoords: routeCoordinates)

        ble.send(json: [
            "speed": max(0, Int(location.speed * 3.6)),
            "distance": NavigationManager.formatDistance(distance),
            "next_road": road.isEmpty ? "Đang dẫn đường" : road,
            "next_road_sub": step.instruction,
            "eta": formatter.string(from: eta),
            "ete": formatDuration(remainingSec),
            "total_distance": totalDistance,
            "maneuver": displayManeuver,
            "actual_maneuver": step.maneuver,
            "next": (currentStepIndex + 1..<min(currentStepIndex + 5, routeSteps.count)).map { routeSteps[$0].maneuver }.joined(separator: ","),
            "route_points": relative
        ])
    }

    private func maneuverForHUD(step: RouteStep, distance: Double) -> String {
        if step.maneuver == "arrive" || step.maneuver == "straight" { return step.maneuver }
        return distance <= turnPreviewDistanceM ? step.maneuver : "straight"
    }

    private func roadNameForHUD(stepIndex: Int, distance: Double) -> String {
        guard routeSteps.indices.contains(stepIndex) else { return "" }
        let step = routeSteps[stepIndex]
        if distance <= turnPreviewDistanceM && step.maneuver != "straight" && step.maneuver != "arrive" { return step.roadName }
        if stepIndex > 0, !routeSteps[stepIndex - 1].roadName.isEmpty { return routeSteps[stepIndex - 1].roadName }
        return step.roadName
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60
        if h > 0 { return "\(h) giờ \(m) phút" }
        if m > 0 { return "\(m) phút" }
        return "\(seconds) giây"
    }

    private func sendIdleToHUD() {
        ble.send(json: ["speed": 0, "distance": 0, "next_road": "", "next_road_sub": "", "eta": "", "ete": "", "total_distance": "", "maneuver": "straight", "next": ""])
    }

    private func setupLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
    }

    private func setupCompleter() {
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.pointOfInterestFilter = .includingAll
    }

    private func setupBLE() {
        ble.onStatusChange = { [weak self] text in DispatchQueue.main.async { self?.connectionText = text } }
        ble.onConnectedChange = { [weak self] connected in DispatchQueue.main.async { self?.hudConnected = connected } }
        ble.startScan()
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "completedTrips"), let value = try? JSONDecoder().decode([CompletedTrip].self, from: data) { completedTrips = value }
    }
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(completedTrips) { UserDefaults.standard.set(data, forKey: "completedTrips") }
    }
}

extension DriveViewModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse { manager.startUpdatingLocation() }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        if let pending = pendingCoordinate, let stopID = pendingStopID {
            pendingCoordinate = nil
            pendingStopID = nil
            fetchLeg(to: pending, stopID: stopID)
            return
        }
        if isNavigating { updateNavigation(location) }
    }
}

extension DriveViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) { suggestions = completer.results }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) { suggestions = [] }
}
