import UIKit
import MapKit
import CoreLocation
import CoreImage

class ViewController: UIViewController {

    // UI
    private let mapView = MKMapView()
    private let topBar = UIView()
    private let destinationField = UITextField()
    private let goButton = UIButton(type: .system)
    private let qrButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let suggestionTable = UITableView()

    // Banner dẫn đường đen (kiểu hiện đại, phía trên)
    private let navBanner = UIView()
    private let navBannerArrow = UILabel()
    private let navBannerText = UILabel()

    // HUD card (bottom sheet trắng hiện đại)
    private let hudCard = UIView()
    private let arrowLabel = UILabel()
    private let speedLabel = UILabel()
    private let speedUnitLabel = UILabel()
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

    /// Danh sách các bước rẽ tiếp theo (tối đa 4) — gửi cho màn OLED cột bên phải
    private func nextManeuversList() -> String {
        var list: [String] = []
        let startIdx = currentStepIndex + 1
        let endIdx = min(startIdx + 4, steps.count)
        if startIdx < endIdx {
            for i in startIdx..<endIdx {
                list.append(steps[i].maneuver)
            }
        }
        return list.joined(separator: ",")
    }

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

    // MARK: - UI (phong cách hiện đại: hồng #FCB5C4 + dark theme)

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1) // dark nền

        // Bản đồ Apple (miễn phí, không cần key) — chế độ sáng
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

        // ---- Thanh tìm kiếm trắng bo tròn (top bar) ----
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1)
        topBar.layer.cornerRadius = 20
        topBar.layer.shadowColor = UIColor.black.cgColor
        topBar.layer.shadowOpacity = 0.12
        topBar.layer.shadowOffset = CGSize(width: 0, height: 4)
        topBar.layer.shadowRadius = 12
        view.addSubview(topBar)
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            topBar.heightAnchor.constraint(equalToConstant: 58)
        ])

        // Nút QR (góc trái) — icon hiện đại
        qrButton.translatesAutoresizingMaskIntoConstraints = false
        qrButton.setTitle("QR", for: .normal)
        qrButton.setTitleColor(UIColor(red: 0.35, green: 0.13, blue: 0.20, alpha: 1), for: .normal)
        qrButton.titleLabel?.font = .boldSystemFont(ofSize: 13)
        qrButton.backgroundColor = accentColor()
        qrButton.layer.cornerRadius = 14
        qrButton.addTarget(self, action: #selector(qrTapped), for: .touchUpInside)
        topBar.addSubview(qrButton)

        destinationField.translatesAutoresizingMaskIntoConstraints = false
        destinationField.backgroundColor = UIColor(red: 0.17, green: 0.17, blue: 0.20, alpha: 1)
        destinationField.textColor = .white
        destinationField.attributedPlaceholder = NSAttributedString(
            string: "Where to?",
            attributes: [.foregroundColor: UIColor.systemGray]
        )
        destinationField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 20))
        let searchIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchIcon.tintColor = accentColor()
        searchIcon.frame = CGRect(x: 8, y: 0, width: 18, height: 20)
        destinationField.leftView?.addSubview(searchIcon)
        destinationField.leftViewMode = .always
        destinationField.layer.cornerRadius = 14
        destinationField.returnKeyType = .go
        destinationField.delegate = self
        destinationField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        topBar.addSubview(destinationField)

        goButton.translatesAutoresizingMaskIntoConstraints = false
        goButton.setTitle("Đi ▶", for: .normal)
        goButton.setTitleColor(UIColor(red: 0.35, green: 0.13, blue: 0.20, alpha: 1), for: .normal)
        goButton.titleLabel?.font = .boldSystemFont(ofSize: 15)
        goButton.backgroundColor = accentColor()
        goButton.layer.cornerRadius = 14
        goButton.addTarget(self, action: #selector(goTapped), for: .touchUpInside)
        topBar.addSubview(goButton)

        NSLayoutConstraint.activate([
            qrButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 8),
            qrButton.topAnchor.constraint(equalTo: topBar.topAnchor, constant: 8),
            qrButton.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -8),
            qrButton.widthAnchor.constraint(equalToConstant: 50),

            destinationField.leadingAnchor.constraint(equalTo: qrButton.trailingAnchor, constant: 8),
            destinationField.topAnchor.constraint(equalTo: topBar.topAnchor, constant: 8),
            destinationField.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -8),

            goButton.leadingAnchor.constraint(equalTo: destinationField.trailingAnchor, constant: 8),
            goButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -8),
            goButton.topAnchor.constraint(equalTo: topBar.topAnchor, constant: 8),
            goButton.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -8),
            goButton.widthAnchor.constraint(equalToConstant: 62)
        ])

        // ---- Banner dẫn đường đen (hiện khi đang chạy) ----
        navBanner.translatesAutoresizingMaskIntoConstraints = false
        navBanner.isHidden = true
        navBanner.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)
        navBanner.layer.borderWidth = 1
        navBanner.layer.borderColor = UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 0.35).cgColor
        navBanner.layer.cornerRadius = 18
        navBanner.layer.shadowColor = UIColor.black.cgColor
        navBanner.layer.shadowOpacity = 0.25
        navBanner.layer.shadowOffset = CGSize(width: 0, height: 4)
        navBanner.layer.shadowRadius = 10
        view.addSubview(navBanner)
        NSLayoutConstraint.activate([
            navBanner.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 34),
            navBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            navBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            navBanner.heightAnchor.constraint(equalToConstant: 60)
        ])

        navBannerArrow.translatesAutoresizingMaskIntoConstraints = false
        navBannerArrow.font = .systemFont(ofSize: 26, weight: .bold)
        navBannerArrow.textColor = UIColor(red: 0.35, green: 0.13, blue: 0.20, alpha: 1)
        navBannerArrow.text = "↑"
        navBannerArrow.textAlignment = .center
        navBannerArrow.backgroundColor = accentColor()
        navBannerArrow.layer.cornerRadius = 22
        navBannerArrow.clipsToBounds = true
        navBanner.addSubview(navBannerArrow)

        navBannerText.translatesAutoresizingMaskIntoConstraints = false
        navBannerText.font = .systemFont(ofSize: 15, weight: .semibold)
        navBannerText.textColor = .white
        navBannerText.numberOfLines = 2
        navBannerText.text = ""
        navBanner.addSubview(navBannerText)

        NSLayoutConstraint.activate([
            navBannerArrow.leadingAnchor.constraint(equalTo: navBanner.leadingAnchor, constant: 10),
            navBannerArrow.centerYAnchor.constraint(equalTo: navBanner.centerYAnchor),
            navBannerArrow.widthAnchor.constraint(equalToConstant: 44),
            navBannerArrow.heightAnchor.constraint(equalToConstant: 44),

            navBannerText.leadingAnchor.constraint(equalTo: navBannerArrow.trailingAnchor, constant: 12),
            navBannerText.trailingAnchor.constraint(equalTo: navBanner.trailingAnchor, constant: -12),
            navBannerText.centerYAnchor.constraint(equalTo: navBanner.centerYAnchor)
        ])

        // Bảng gợi ý địa chỉ (ẩn mặc định) — nền trắng bo tròn
        suggestionTable.translatesAutoresizingMaskIntoConstraints = false
        suggestionTable.isHidden = true
        suggestionTable.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1)
        suggestionTable.layer.cornerRadius = 16
        suggestionTable.layer.shadowColor = UIColor.black.cgColor
        suggestionTable.layer.shadowOpacity = 0.1
        suggestionTable.layer.shadowOffset = CGSize(width: 0, height: 4)
        suggestionTable.layer.shadowRadius = 10
        suggestionTable.separatorColor = UIColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1)
        suggestionTable.dataSource = self
        suggestionTable.delegate = self
        view.addSubview(suggestionTable)
        NSLayoutConstraint.activate([
            suggestionTable.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 8),
            suggestionTable.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            suggestionTable.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            suggestionTable.heightAnchor.constraint(equalToConstant: 260)
        ])

        // Trạng thái (chip nhỏ)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.text = "Đang tìm HUD..."
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        statusLabel.layer.cornerRadius = 12
        statusLabel.clipsToBounds = true
        statusLabel.textAlignment = .center
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 6),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
            statusLabel.heightAnchor.constraint(equalToConstant: 24)
        ])

        // ---- HUD card: bottom sheet trắng hiện đại ----
        hudCard.translatesAutoresizingMaskIntoConstraints = false
        hudCard.isHidden = true
        hudCard.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1)
        hudCard.layer.cornerRadius = 26
        hudCard.layer.shadowColor = UIColor.black.cgColor
        hudCard.layer.shadowOpacity = 0.15
        hudCard.layer.shadowOffset = CGSize(width: 0, height: -4)
        hudCard.layer.shadowRadius = 16
        view.addSubview(hudCard)
        NSLayoutConstraint.activate([
            hudCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            hudCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            hudCard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            hudCard.heightAnchor.constraint(equalToConstant: 160)
        ])

        arrowLabel.translatesAutoresizingMaskIntoConstraints = false
        arrowLabel.font = .systemFont(ofSize: 48, weight: .bold)
        arrowLabel.textColor = accentColor()
        arrowLabel.text = "↑"
        arrowLabel.textAlignment = .center
        hudCard.addSubview(arrowLabel)

        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        speedLabel.font = .monospacedDigitSystemFont(ofSize: 44, weight: .bold)
        speedLabel.textColor = .white
        speedLabel.text = "--"
        speedLabel.textAlignment = .right
        hudCard.addSubview(speedLabel)

        speedUnitLabel.translatesAutoresizingMaskIntoConstraints = false
        speedUnitLabel.font = .systemFont(ofSize: 13, weight: .medium)
        speedUnitLabel.textColor = .systemGray
        speedUnitLabel.text = "km/h"
        speedUnitLabel.textAlignment = .right
        hudCard.addSubview(speedUnitLabel)

        roadLabel.translatesAutoresizingMaskIntoConstraints = false
        roadLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        roadLabel.textColor = .white
        roadLabel.numberOfLines = 2
        roadLabel.text = ""
        hudCard.addSubview(roadLabel)

        etaLabel.translatesAutoresizingMaskIntoConstraints = false
        etaLabel.font = .systemFont(ofSize: 12, weight: .medium)
        etaLabel.textColor = .systemGray2
        etaLabel.text = ""
        hudCard.addSubview(etaLabel)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = accentColor()
        progressView.trackTintColor = UIColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1)
        progressView.layer.cornerRadius = 3
        progressView.clipsToBounds = true
        hudCard.addSubview(progressView)

        NSLayoutConstraint.activate([
            arrowLabel.leadingAnchor.constraint(equalTo: hudCard.leadingAnchor, constant: 16),
            arrowLabel.topAnchor.constraint(equalTo: hudCard.topAnchor, constant: 10),
            arrowLabel.widthAnchor.constraint(equalToConstant: 56),
            arrowLabel.heightAnchor.constraint(equalToConstant: 52),

            speedLabel.trailingAnchor.constraint(equalTo: hudCard.trailingAnchor, constant: -18),
            speedLabel.topAnchor.constraint(equalTo: hudCard.topAnchor, constant: 6),
            speedLabel.heightAnchor.constraint(equalToConstant: 48),

            speedUnitLabel.trailingAnchor.constraint(equalTo: hudCard.trailingAnchor, constant: -18),
            speedUnitLabel.topAnchor.constraint(equalTo: speedLabel.bottomAnchor, constant: -6),

            roadLabel.leadingAnchor.constraint(equalTo: hudCard.leadingAnchor, constant: 18),
            roadLabel.trailingAnchor.constraint(equalTo: hudCard.trailingAnchor, constant: -18),
            roadLabel.topAnchor.constraint(equalTo: arrowLabel.bottomAnchor, constant: 4),

            etaLabel.leadingAnchor.constraint(equalTo: hudCard.leadingAnchor, constant: 18),
            etaLabel.trailingAnchor.constraint(equalTo: hudCard.trailingAnchor, constant: -18),
            etaLabel.topAnchor.constraint(equalTo: roadLabel.bottomAnchor, constant: 4),

            progressView.leadingAnchor.constraint(equalTo: hudCard.leadingAnchor, constant: 18),
            progressView.trailingAnchor.constraint(equalTo: hudCard.trailingAnchor, constant: -18),
            progressView.bottomAnchor.constraint(equalTo: hudCard.bottomAnchor, constant: -16),
            progressView.heightAnchor.constraint(equalToConstant: 6)
        ])

        // ---- Overlay đến nơi + QR ----
        arriveOverlay.translatesAutoresizingMaskIntoConstraints = false
        arriveOverlay.isHidden = true
        arriveOverlay.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 0.97)
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
        arriveTitle.textColor = accentColor()
        arriveTitle.textAlignment = .center
        arriveOverlay.addSubview(arriveTitle)

        qrImageView.translatesAutoresizingMaskIntoConstraints = false
        qrImageView.contentMode = .scaleAspectFit
        qrImageView.backgroundColor = .white
        qrImageView.layer.cornerRadius = 16
        qrImageView.layer.shadowColor = UIColor.black.cgColor
        qrImageView.layer.shadowOpacity = 0.12
        qrImageView.layer.shadowOffset = CGSize(width: 0, height: 4)
        qrImageView.layer.shadowRadius = 12
        qrImageView.clipsToBounds = true
        arriveOverlay.addSubview(qrImageView)

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("Đóng", for: .normal)
        closeButton.setTitleColor(UIColor(red: 0.35, green: 0.13, blue: 0.20, alpha: 1), for: .normal)
        closeButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        closeButton.backgroundColor = accentColor()
        closeButton.layer.cornerRadius = 14
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
            closeButton.heightAnchor.constraint(equalToConstant: 46)
        ])
    }

    /// Màu chủ đạo hồng #FCB5C4 (giống thiết kế tham khảo)
    private func accentColor() -> UIColor {
        UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 1)
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
                self?.statusLabel.textColor = connected ? .white : .white
                self?.statusLabel.backgroundColor = connected
                    ? UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 0.9)
                    : UIColor.black.withAlphaComponent(0.65)
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
        navBanner.isHidden = false
        arriveOverlay.isHidden = true
        statusLabel.text = "Đang lấy tuyến đường..."
        nav.fetchRoute(from: origin, to: destination) { [weak self] steps, _, totalDistanceText, coords in
            guard let self = self, !steps.isEmpty else {
                self?.statusLabel.text = "Không có tuyến đường"
                self?.hudCard.isHidden = true
                self?.navBanner.isHidden = true
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
        navBanner.isHidden = true
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
            renderer.strokeColor = UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 0.9)
            renderer.lineWidth = 6
            renderer.lineCap = .round
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
        cell.detailTextLabel?.textColor = .systemGray2
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
                "qr": qrString,
                "next": ""
            ]
            ble.send(json: json)
            showArriveOverlay()
            return
        }

        // Cập nhật banner đen dẫn đường (phía trên)
        let arrow = arrowSymbol(for: step.maneuver)
        navBannerArrow.text = arrow
        navBannerArrow.textColor = UIColor(red: 0.35, green: 0.13, blue: 0.20, alpha: 1)
        let distanceText = bestDistance >= 1000
            ? String(format: "%.1f km", bestDistance / 1000)
            : "\(Int(bestDistance)) m"
        navBannerText.text = "\(distanceText) · \(step.instruction)"

        // Cập nhật HUD card trên app
        arrowLabel.text = arrow
        arrowLabel.textColor = step.maneuver == "arrive" ? .systemYellow : accentColor()
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
                "maneuver": step.maneuver,
                "next": nextManeuversList()
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
