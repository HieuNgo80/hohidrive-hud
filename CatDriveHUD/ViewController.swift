import UIKit
import MapKit
import CoreLocation
import CoreImage

class ViewController: UIViewController {

    // UI
    private let mapView = MKMapView()
    private let destinationField = UITextField()
    private let goButton = UIButton(type: .system)
    private let qrButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let suggestionTable = UITableView()

    // HUD card (hiện khi đang dẫn đường)
    private let hudCard = UIView()
    private let arrowLabel = UILabel()
    private let speedLabel = UILabel()
    private let roadLabel = UILabel()
    private let etaLabel = UILabel()
    private let progressView = UIProgressView()

    // Overlay đến nơi + QR
    private let arriveOverlay = UIView()
    private let arriveTitle = UILabel()
    private let qrImageView = UIImageView()

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
    private var pendingDestination: CLLocationCoordinate2D?
    private var lastSendTime: TimeInterval = 0

    /// Chuỗi mã QR thanh toán (VietQR) — nhập ở nút QR, lưu vĩnh viễn
    private var qrString: String {
        get { UserDefaults.standard.string(forKey: "qrString") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "qrString") }
    }

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
        mapView.overrideUserInterfaceStyle = .dark
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

        // Nút QR (góc trái)
        qrButton.translatesAutoresizingMaskIntoConstraints = false
        qrButton.setTitle("◧ QR", for: .normal)
        qrButton.setTitleColor(.white, for: .normal)
        qrButton.titleLabel?.font = .boldSystemFont(ofSize: 13)
        qrButton.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.9)
        qrButton.layer.cornerRadius = 8
        qrButton.addTarget(self, action: #selector(qrTapped), for: .touchUpInside)
        bar.addSubview(qrButton)

        destinationField.translatesAutoresizingMaskIntoConstraints = false
        destinationField.backgroundColor = .white
        destinationField.textColor = .black
        destinationField.attributedPlaceholder = NSAttributedString(
            string: "Nhập điểm đến...",
            attributes: [.foregroundColor: UIColor.darkGray]
        )
        destinationField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        destinationField.leftViewMode = .always
        destinationField.layer.cornerRadius = 10
        destinationField.returnKeyType = .go
        destinationField.delegate = self
        destinationField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        bar.addSubview(destinationField)

        goButton.translatesAutoresizingMaskIntoConstraints = false
        goButton.setTitle("Đi ▶", for: .normal)
        goButton.setTitleColor(.white, for: .normal)
        goButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        goButton.backgroundColor = .systemBlue
        goButton.layer.cornerRadius = 10
        goButton.addTarget(self, action: #selector(goTapped), for: .touchUpInside)
        bar.addSubview(goButton)

        NSLayoutConstraint.activate([
            qrButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 8),
            qrButton.topAnchor.constraint(equalTo: bar.topAnchor, constant: 10),
            qrButton.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -10),
            qrButton.widthAnchor.constraint(equalToConstant: 56),

            destinationField.leadingAnchor.constraint(equalTo: qrButton.trailingAnchor, constant: 6),
            destinationField.topAnchor.constraint(equalTo: bar.topAnchor, constant: 8),
            destinationField.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -8),

            goButton.leadingAnchor.constraint(equalTo: destinationField.trailingAnchor, constant: 6),
            goButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
            goButton.topAnchor.constraint(equalTo: bar.topAnchor, constant: 8),
            goButton.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -8),
            goButton.widthAnchor.constraint(equalToConstant: 64)
        ])

        // Bảng gợi ý địa chỉ (ẩn mặc định)
        suggestionTable.translatesAutoresizingMaskIntoConstraints = false
        suggestionTable.isHidden = true
        suggestionTable.backgroundColor = UIColor.black.withAlphaComponent(0.92)
        suggestionTable.separatorColor = .darkGray
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
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        statusLabel.layer.cornerRadius = 6
        statusLabel.clipsToBounds = true
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 6),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8)
        ])

        // ---- HUD card dưới đáy ----
        hudCard.translatesAutoresizingMaskIntoConstraints = false
        hudCard.isHidden = true
        hudCard.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        hudCard.layer.cornerRadius = 18
        hudCard.layer.borderWidth = 1
        hudCard.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.6).cgColor
        view.addSubview(hudCard)
        NSLayoutConstraint.activate([
            hudCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            hudCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            hudCard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            hudCard.heightAnchor.constraint(equalToConstant: 148)
        ])

        arrowLabel.translatesAutoresizingMaskIntoConstraints = false
        arrowLabel.font = .systemFont(ofSize: 52, weight: .bold)
        arrowLabel.textColor = .systemGreen
        arrowLabel.text = "↑"
        arrowLabel.textAlignment = .center
        hudCard.addSubview(arrowLabel)

        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        speedLabel.font = .monospacedDigitSystemFont(ofSize: 46, weight: .bold)
        speedLabel.textColor = .white
        speedLabel.text = "--"
        speedLabel.textAlignment = .right
        hudCard.addSubview(speedLabel)

        roadLabel.translatesAutoresizingMaskIntoConstraints = false
        roadLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        roadLabel.textColor = .white
        roadLabel.numberOfLines = 2
        roadLabel.text = ""
        hudCard.addSubview(roadLabel)

        etaLabel.translatesAutoresizingMaskIntoConstraints = false
        etaLabel.font = .systemFont(ofSize: 12)
        etaLabel.textColor = .systemGray2
        etaLabel.text = ""
        hudCard.addSubview(etaLabel)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .systemGreen
        progressView.trackTintColor = .darkGray
        hudCard.addSubview(progressView)

        NSLayoutConstraint.activate([
            arrowLabel.leadingAnchor.constraint(equalTo: hudCard.leadingAnchor, constant: 12),
            arrowLabel.topAnchor.constraint(equalTo: hudCard.topAnchor, constant: 8),
            arrowLabel.widthAnchor.constraint(equalToConstant: 60),
            arrowLabel.heightAnchor.constraint(equalToConstant: 56),

            speedLabel.trailingAnchor.constraint(equalTo: hudCard.trailingAnchor, constant: -16),
            speedLabel.topAnchor.constraint(equalTo: hudCard.topAnchor, constant: 8),
            speedLabel.heightAnchor.constraint(equalToConstant: 52),

            roadLabel.leadingAnchor.constraint(equalTo: hudCard.leadingAnchor, constant: 16),
            roadLabel.trailingAnchor.constraint(equalTo: hudCard.trailingAnchor, constant: -16),
            roadLabel.topAnchor.constraint(equalTo: arrowLabel.bottomAnchor, constant: 2),

            etaLabel.leadingAnchor.constraint(equalTo: hudCard.leadingAnchor, constant: 16),
            etaLabel.trailingAnchor.constraint(equalTo: hudCard.trailingAnchor, constant: -16),
            etaLabel.topAnchor.constraint(equalTo: roadLabel.bottomAnchor, constant: 2),

            progressView.leadingAnchor.constraint(equalTo: hudCard.leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: hudCard.trailingAnchor, constant: -16),
            progressView.bottomAnchor.constraint(equalTo: hudCard.bottomAnchor, constant: -14)
        ])

        // ---- Overlay đến nơi + QR ----
        arriveOverlay.translatesAutoresizingMaskIntoConstraints = false
        arriveOverlay.isHidden = true
        arriveOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.94)
        view.addSubview(arriveOverlay)
        NSLayoutConstraint.activate([
            arriveOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            arriveOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arriveOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arriveOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        arriveTitle.translatesAutoresizingMaskIntoConstraints = false
        arriveTitle.text = "🏁 ĐÃ ĐẾN NƠI"
        arriveTitle.font = .boldSystemFont(ofSize: 26)
        arriveTitle.textColor = .systemGreen
        arriveTitle.textAlignment = .center
        arriveOverlay.addSubview(arriveTitle)

        qrImageView.translatesAutoresizingMaskIntoConstraints = false
        qrImageView.contentMode = .scaleAspectFit
        qrImageView.backgroundColor = .white
        qrImageView.layer.cornerRadius = 12
        qrImageView.clipsToBounds = true
        arriveOverlay.addSubview(qrImageView)

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("Đóng", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        closeButton.backgroundColor = .systemBlue
        closeButton.layer.cornerRadius = 12
        closeButton.addTarget(self, action: #selector(closeArriveOverlay), for: .touchUpInside)
        arriveOverlay.addSubview(closeButton)

        NSLayoutConstraint.activate([
            arriveTitle.centerXAnchor.constraint(equalTo: arriveOverlay.centerXAnchor),
            arriveTitle.topAnchor.constraint(equalTo: arriveOverlay.safeAreaLayoutGuide.topAnchor, constant: 70),

            qrImageView.centerXAnchor.constraint(equalTo: arriveOverlay.centerXAnchor),
            qrImageView.topAnchor.constraint(equalTo: arriveTitle.bottomAnchor, constant: 24),
            qrImageView.widthAnchor.constraint(equalToConstant: 260),
            qrImageView.heightAnchor.constraint(equalToConstant: 260),

            closeButton.centerXAnchor.constraint(equalTo: arriveOverlay.centerXAnchor),
            closeButton.topAnchor.constraint(equalTo: qrImageView.bottomAnchor, constant: 28),
            closeButton.widthAnchor.constraint(equalToConstant: 140),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
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

    @objc private func qrTapped() {
        let alert = UIAlertController(title: "Mã QR thanh toán",
                                      message: "Dán chuỗi VietQR (000201...) — khi đến nơi app sẽ hiện mã QR này",
                                      preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = self.qrString
            tf.placeholder = "000201010212..."
            tf.keyboardType = .asciiCapable
        }
        alert.addAction(UIAlertAction(title: "Lưu", style: .default) { [weak self] _ in
            let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self?.qrString = text
            self?.statusLabel.text = text.isEmpty ? "Đã xóa mã QR" : "Đã lưu mã QR ✓"
        })
        alert.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func closeArriveOverlay() {
        arriveOverlay.isHidden = true
    }

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
            beginNavigation(to: coord)
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
            self.beginNavigation(to: coordinate)
        }
    }

    /// Bắt đầu dẫn đường — nếu chưa có GPS thì lưu lại và chờ fix vị trí đầu tiên
    private func beginNavigation(to destination: CLLocationCoordinate2D) {
        guard let origin = locationManager.location?.coordinate else {
            pendingDestination = destination
            statusLabel.text = "Đang chờ vị trí GPS..."
            return
        }
        startNavigation(from: origin, to: destination)
    }

    private func startNavigation(from origin: CLLocationCoordinate2D,
                                 to destination: CLLocationCoordinate2D) {
        pendingDestination = nil
        isNavigating = true
        hudCard.isHidden = false
        arriveOverlay.isHidden = true
        statusLabel.text = "Đang lấy tuyến đường..."
        nav.fetchRoute(from: origin, to: destination) { [weak self] steps, _, totalDistanceText, coords in
            guard let self = self, !steps.isEmpty else {
                self?.statusLabel.text = "Không có tuyến đường"
                self?.hudCard.isHidden = true
                return
            }
            self.steps = steps
            self.currentStepIndex = 0
            self.totalDistanceText = totalDistanceText
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
                                   edgePadding: UIEdgeInsets(top: 100, left: 50, bottom: 200, right: 50),
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

    private func arrowSymbol(for maneuver: String) -> String {
        switch maneuver {
        case "left": return "←"
        case "right": return "→"
        case "arrive": return "🏁"
        default: return "↑"
        }
    }

    /// Tạo ảnh QR từ chuỗi VietQR bằng CoreImage
    private func makeQRImage(from text: String) -> UIImage? {
        guard !text.isEmpty else { return nil }
        let data = text.data(using: .utf8)!
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }
        let scale = ciImage.extent.width > 0 ? 520 / ciImage.extent.width : 10
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return UIImage(ciImage: scaled)
    }

    /// Hiện overlay "ĐÃ ĐẾN NƠI" + mã QR thanh toán (nếu đã nhập)
    private func showArriveOverlay() {
        hudCard.isHidden = true
        if let qr = makeQRImage(from: qrString) {
            qrImageView.image = qr
            qrImageView.isHidden = false
        } else {
            qrImageView.isHidden = true
        }
        arriveTitle.text = qrString.isEmpty ? "🏁 ĐÃ ĐẾN NƠI" : "🏁 QUÉT MÃ THANH TOÁN"
        arriveOverlay.isHidden = false
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
        cell.backgroundColor = .clear
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.textColor = .lightGray
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
            self.beginNavigation(to: item.placemark.coordinate)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension ViewController: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            statusLabel.text = "Bật quyền vị trí trong Settings để dẫn đường"
        } else if status == .authorizedAlways || status == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coord = location.coordinate

        // Có điểm đến đang chờ GPS — fix được vị trí là tự bắt đầu dẫn đường
        if let pending = pendingDestination {
            startNavigation(from: coord, to: pending)
            return
        }

        if !isNavigating {
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

        // ---- ĐẾN NƠI: step cuối là arrive hoặc còn cách đích < 40m ----
        let isArriveStep = step.maneuver == "arrive" || currentStepIndex == steps.count - 1
        if isArriveStep && bestDistance < 40 {
            isNavigating = false
            let json: [String: Any] = [
                "speed": 0,
                "distance": 0,
                "next_road": "ĐÃ ĐẾN NƠI",
                "next_road_sub": "",
                "eta": formatter.string(from: eta),
                "ete": "",
                "total_distance": totalDistanceText,
                "maneuver": "arrive",
                "qr": qrString
            ]
            ble.send(json: json)
            showArriveOverlay()
            return
        }

        // Cập nhật HUD card trên app
        arrowLabel.text = arrowSymbol(for: step.maneuver)
        arrowLabel.textColor = step.maneuver == "arrive" ? .systemYellow : .systemGreen
        speedLabel.text = "\(speed)"
        roadLabel.text = step.instruction
        etaLabel.text = "Còn \(Int(bestDistance)) m · ETA \(formatter.string(from: eta)) · \(Self.formatDuration(remainingSec))"
        if totalDistanceText.contains("km"), let totalKM = Double(totalDistanceText.replacingOccurrences(of: " km", with: "")) {
            let travelled = max(0, totalKM * 1000 - Double(bestDistance))
            progressView.progress = Float(travelled / (totalKM * 1000))
        }

        // Gửi JSON lên ESP — tối đa 1 lần/giây (tránh nghẽn BLE)
        let now = Date().timeIntervalSince1970
        if now - lastSendTime >= 1.0 || step.maneuver == "arrive" {
            lastSendTime = now
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
}

// MARK: - UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        goTapped()
        return true
    }
}
