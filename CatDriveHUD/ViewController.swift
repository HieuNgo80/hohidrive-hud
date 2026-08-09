import UIKit
import GoogleMaps
import CoreLocation

class ViewController: UIViewController {

    // UI
    private let mapView = GMSMapView()
    private let destinationField = UITextField()
    private let goButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    // Services
    private let locationManager = CLLocationManager()
    private let ble = BLEManager()
    private let nav = NavigationManager()

    // Trạng thái dẫn đường
    private var steps: [RouteStep] = []
    private var currentStepIndex = 0
    private var isNavigating = false
    private var totalDistanceText = ""
    private var routePolyline: GMSPolyline?

    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String ?? ""
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLocation()
        setupBLE()
    }

    // MARK: - UI

    private func setupUI() {
        view.backgroundColor = .black

        // Bản đồ
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
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

    // MARK: - Actions

    @objc private func goTapped() {
        destinationField.resignFirstResponder()
        guard let address = destinationField.text, !address.isEmpty else { return }

        // Geocode địa chỉ -> tọa độ (dùng CLGeocoder của Apple — SDK Google Maps 11 đã bỏ GMSGeocoder)
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
        nav.fetchRoute(from: origin, to: destination, apiKey: apiKey) { [weak self] steps, _, totalDistanceText, overviewPoints in
            guard let self = self, !steps.isEmpty else {
                self?.statusLabel.text = "Không có tuyến đường"
                return
            }
            self.steps = steps
            self.currentStepIndex = 0
            self.totalDistanceText = totalDistanceText
            self.isNavigating = true
            self.drawRoute(overviewPoints: overviewPoints)
            self.statusLabel.text = "Đang dẫn đường... (\(totalDistanceText))"
        }
    }

    private func drawRoute(overviewPoints: String) {
        routePolyline?.map = nil
        guard let path = GMSPath(fromEncodedPath: overviewPoints) else { return }
        let polyline = GMSPolyline(path: path)
        polyline.strokeColor = .systemBlue
        polyline.strokeWidth = 5
        polyline.map = mapView
        routePolyline = polyline

        let bounds = GMSCoordinateBounds(path: path)
        mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 40))
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

// MARK: - CLLocationManagerDelegate

extension ViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coord = location.coordinate

        if !isNavigating {
            mapView.animate(toLocation: coord)
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
