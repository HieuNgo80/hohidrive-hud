import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController {

    // UI
    private let mapView = MKMapView()
    private let destinationField = UITextField()
    private let goButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let suggestionTable = UITableView()

    // Services
    private let locationManager = CLLocationManager()
    private let ble = BLEManager()
    private let nav = NavigationManager()
    private let completer = MKLocalSearchCompleter()

    // Tìm kiếm gợi ý
    private var suggestions: [MKLocalSearchCompletion] = []
    private var selectedCoordinate: CLLocationCoordinate2D?

    // Trạng thái dẫn đường
    private var steps: [RouteStep] = []
    private var currentStepIndex = 0
    private var isNavigating = false
    private var totalDistanceText = ""
    private var routePolyline: MKPolyline?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLocation()
        setupBLE()
        setupCompleter()
    }

    // MARK: - UI

    private func setupUI() {
        view.backgroundColor = .black

        // Bản đồ Apple (miễn phí, không cần key)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.delegate = self
        view.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Thanh nhập điểm đến
        let bar = UIView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        view.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 56)
        ])

        destinationField.translatesAutoresizingMaskIntoConstraints = false
        destinationField.placeholder = "Nhập điểm đến..."
        destinationField.backgroundColor = .white
        destinationField.layer.cornerRadius = 8
        destinationField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        destinationField.leftViewMode = .always
        destinationField.returnKeyType = .go
        destinationField.delegate = self
        destinationField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        bar.addSubview(destinationField)

        goButton.translatesAutoresizingMaskIntoConstraints = false
        goButton.setTitle("Đi ▶", for: .normal)
        goButton.setTitleColor(.white, for: .normal)
        goButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        goButton.backgroundColor = .systemBlue
        goButton.layer.cornerRadius = 8
        goButton.addTarget(self, action: #selector(goTapped), for: .touchUpInside)
        bar.addSubview(goButton)

        NSLayoutConstraint.activate([
            destinationField.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 8),
            destinationField.topAnchor.constraint(equalTo: bar.topAnchor, constant: 8),
            destinationField.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -8),
            goButton.leadingAnchor.constraint(equalTo: destinationField.trailingAnchor, constant: 8),
            goButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
            goButton.topAnchor.constraint(equalTo: bar.topAnchor, constant: 8),
            goButton.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -8),
            goButton.widthAnchor.constraint(equalToConstant: 64)
        ])

        // Bảng gợi ý địa chỉ (ẩn mặc định)
        suggestionTable.translatesAutoresizingMaskIntoConstraints = false
        suggestionTable.isHidden = true
        suggestionTable.dataSource = self
        suggestionTable.delegate = self
        view.addSubview(suggestionTable)
        NSLayoutConstraint.activate([
            suggestionTable.topAnchor.constraint(equalTo: bar.bottomAnchor),
            suggestionTable.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestionTable.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            suggestionTable.heightAnchor.constraint(equalToConstant: 280)
        ])

        // Trạng thái
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.text = "Đang tìm HUD..."
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8)
        ])
    }

    // MARK: - Services setup

    private func setupLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
    }

    private func setupBLE() {
        ble.onStatusChange = { [weak self] text in
            DispatchQueue.main.async { self?.statusLabel.text = text }
        }
        ble.onConnectedChange = { [weak self] connected in
            DispatchQueue.main.async {
                self?.statusLabel.textColor = connected ? .systemGreen : .white
            }
        }
        ble.startScan()
    }

    private func setupCompleter() {
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.pointOfInterestFilter = .includingAll
    }

    // MARK: - Actions

    @objc private func textChanged() {
        guard let text = destinationField.text, !text.isEmpty else {
            suggestionTable.isHidden = true
            suggestions = []
            selectedCoordinate = nil
            return
        }
        completer.queryFragment = text
    }

    @objc private func goTapped() {
        destinationField.resignFirstResponder()
        suggestionTable.isHidden = true

        // Nếu đã chọn từ gợi ý thì dùng luôn
        if let coord = selectedCoordinate {
            startNavigation(to: coord)
            return
        }

        guard let address = destinationField.text, !address.isEmpty else { return }

        // Geocode địa chỉ -> tọa độ
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { [weak self] placemarks, error in
            guard let self = self,
                  let coordinate = placemarks?.first?.location?.coordinate,
                  error == nil else {
                self?.statusLabel.text = "Không tìm thấy địa chỉ"
                return
            }
            self.startNavigation(to: coordinate)
        }
    }

    private func startNavigation(to destination: CLLocationCoordinate2D) {
        guard let origin = locationManager.location?.coordinate else {
            statusLabel.text = "Chưa có vị trí GPS"
            return
        }

        statusLabel.text = "Đang lấy tuyến đường..."
        nav.fetchRoute(from: origin, to: destination) { [weak self] steps, _, totalDistanceText, coords in
            guard let self = self, !steps.isEmpty else {
                self?.statusLabel.text = "Không có tuyến đường"
                return
            }
            self.steps = steps
            self.currentStepIndex = 0
            self.totalDistanceText = totalDistanceText
            self.isNavigating = true
            self.drawRoute(coordinates: coords)
            self.statusLabel.text = "Đang dẫn đường... (\(totalDistanceText))"
        }
    }

    private func drawRoute(coordinates: [CLLocationCoordinate2D]) {
        if let poly = routePolyline {
            mapView.removeOverlay(poly)
        }
        guard coordinates.count > 1 else { return }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        routePolyline = polyline

        let rect = polyline.boundingMapRect
        mapView.setVisibleMapRect(rect,
                                   edgePadding: UIEdgeInsets(top: 100, left: 50, bottom: 100, right: 50),
                                   animated: true)
    }

    // MARK: - Helpers

    private func distanceMeters(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    private static func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h) giờ \(m) phút" }
        if m > 0 { return "\(m) phút" }
        return "\(seconds) giây"
    }
}

// MARK: - MKMapViewDelegate

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 5
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension ViewController: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
        suggestionTable.isHidden = suggestions.isEmpty
        suggestionTable.reloadData()
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestionTable.isHidden = true
    }
}

// MARK: - UITableViewDataSource / Delegate

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        suggestions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let s = suggestions[indexPath.row]
        cell.textLabel?.text = s.title
        cell.detailTextLabel?.text = s.subtitle
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let completion = suggestions[indexPath.row]
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self = self, let item = response?.mapItems.first else { return }
            self.destinationField.text = completion.title
            self.selectedCoordinate = item.placemark.coordinate
            self.suggestionTable.isHidden = true
            self.destinationField.resignFirstResponder()
            self.startNavigation(to: item.placemark.coordinate)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension ViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coord = location.coordinate

        if !isNavigating {
            // Bản đồ đang follow vị trí — chỉ cần giữ tâm bám theo
            mapView.setCenter(coord, animated: true)
            return
        }

        guard !steps.isEmpty else { return }

        // Tìm step hiện tại: step có end_location gần nhất (từ vị trí hiện tại trở đi)
        var bestIndex = currentStepIndex
        var bestDistance = Double.greatestFiniteMagnitude
        for i in currentStepIndex..<steps.count {
            let end = CLLocationCoordinate2D(latitude: steps[i].endLat, longitude: steps[i].endLng)
            let d = distanceMeters(from: coord, to: end)
            if d < bestDistance {
                bestDistance = d
                bestIndex = i
            }
        }
        // Đã qua step hiện tại (< 30m) thì chuyển step kế tiếp
        if bestDistance < 30 && bestIndex < steps.count - 1 {
            bestIndex += 1
        }
        currentStepIndex = bestIndex
        let step = steps[currentStepIndex]

        // Thời gian + khoảng cách còn lại
        var remainingSec = 0
        for i in currentStepIndex..<steps.count {
            remainingSec += steps[i].durationValue
        }
        let eta = Date().addingTimeInterval(TimeInterval(remainingSec))
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        // Tốc độ (m/s -> km/h)
        let speed = max(0, Int(location.speed * 3.6))

        let json: [String: Any] = [
            "speed": speed,
            "distance": Int(bestDistance),
            "next_road": step.instruction,
            "next_road_sub": "",
            "eta": formatter.string(from: eta),
            "ete": Self.formatDuration(remainingSec),
            "total_distance": totalDistanceText,
            "maneuver": step.maneuver
        ]
        ble.send(json: json)
    }
}

// MARK: - UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        goTapped()
        return true
    }
}
