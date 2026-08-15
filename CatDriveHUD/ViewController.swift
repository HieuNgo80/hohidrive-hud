import UIKit
import MapKit
import CoreLocation
import CoreImage

class ViewController: UIViewController {

    // MARK: - UI

    // Bản đồ
    private let mapView = MKMapView()

    // Thanh trên
    private let topBar = UIView()
    private let titleLabel = UILabel()
    private let qrButton = UIButton(type: .system)

    // Card nhập điểm đến
    private let destCard = UIView()
    private let destStack = UIStackView()
    private let addDestButton = UIButton(type: .system)
    private let goButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let suggestionTable = UITableView()

    // HUD card (hiện khi đang dẫn đường)
    private let hudCard = UIView()
    private let arrowLabel = UILabel()
    private let speedLabel = UILabel()
    private let roadLabel = UILabel()
    private let etaLabel = UILabel()
    private let progressView = UIProgressView()
    private let stopButton = UIButton(type: .system)

    // Overlay đến nơi + QR
    private let arriveOverlay = UIView()
    private let arriveTitle = UILabel()
    private let arriveSubtitle = UILabel()
    private let qrImageView = UIImageView()

    // MARK: - Services

    private let locationManager = CLLocationManager()
    private let ble = BLEManager()
    private let nav = NavigationManager()
    private let completer = MKLocalSearchCompleter()

    // MARK: - Điểm đến (nhiều điểm)

    private var destinationFields: [UITextField] = []
    private var destinationCoords: [CLLocationCoordinate2D?] = []
    /// Đánh dấu từng điểm đã hoàn thành (hiện QR) hay chưa
    private var stopCompleted: [Bool] = []
    private var activeFieldIndex = 0

    // Tìm kiếm gợi ý
    private var suggestions: [MKLocalSearchCompletion] = []

    // Trạng thái dẫn đường
    private var steps: [RouteStep] = []
    private var currentStepIndex = 0
    private var isNavigating = false
    private var totalDistanceText = ""
    private var routePolyline: MKPolyline?
    private var pendingDestination: CLLocationCoordinate2D?
    private var lastSendTime: TimeInterval = 0

    /// Chỉ số điểm đến đang được dẫn đường (trong destinationFields)
    private var currentStopIndex = 0
    /// Tổng số điểm đến có nội dung (để hiển thị X/Y)
    private var totalStopsWithText = 0



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
        addDestinationRow()
    }

    // MARK: - UI

    private func setupUI() {
        view.backgroundColor = .black

        // ---- Bản đồ Apple (miễn phí, không cần key) ----
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

        // ---- Thanh trên ----
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = UIColor(white: 0.08, alpha: 0.96)
        view.addSubview(topBar)
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 52)
        ])

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "HOHI DRIVE"
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 1)
        topBar.addSubview(titleLabel)

        qrButton.translatesAutoresizingMaskIntoConstraints = false
        qrButton.setTitle("◧ QR", for: .normal)
        qrButton.setTitleColor(UIColor(red: 0.35, green: 0.13, blue: 0.20, alpha: 1), for: .normal)
        qrButton.titleLabel?.font = .boldSystemFont(ofSize: 13)
        qrButton.backgroundColor = UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 1)
        qrButton.layer.cornerRadius = 10
        qrButton.addTarget(self, action: #selector(qrTapped), for: .touchUpInside)
        topBar.addSubview(qrButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            qrButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -12),
            qrButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            qrButton.widthAnchor.constraint(equalToConstant: 56),
            qrButton.heightAnchor.constraint(equalToConstant: 34)
        ])

        // ---- Card nhập điểm đến ----
        destCard.translatesAutoresizingMaskIntoConstraints = false
        destCard.backgroundColor = UIColor(white: 0.12, alpha: 0.96)
        destCard.layer.cornerRadius = 18
        destCard.layer.borderWidth = 1
        destCard.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        view.addSubview(destCard)
        NSLayoutConstraint.activate([
            destCard.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 8),
            destCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            destCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
        ])

        // Stack các ô điểm đến
        destStack.translatesAutoresizingMaskIntoConstraints = false
        destStack.axis = .vertical
        destStack.spacing = 8
        destCard.addSubview(destStack)
        NSLayoutConstraint.activate([
            destStack.topAnchor.constraint(equalTo: destCard.topAnchor, constant: 14),
            destStack.leadingAnchor.constraint(equalTo: destCard.leadingAnchor, constant: 12),
            destStack.trailingAnchor.constraint(equalTo: destCard.trailingAnchor, constant: -12)
        ])

        // Nút + thêm điểm đến
        addDestButton.translatesAutoresizingMaskIntoConstraints = false
        addDestButton.setTitle("＋ Thêm điểm đến", for: .normal)
        addDestButton.setTitleColor(UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 1), for: .normal)
        addDestButton.titleLabel?.font = .boldSystemFont(ofSize: 15)
        addDestButton.contentHorizontalAlignment = .leading
        addDestButton.addTarget(self, action: #selector(addDestTapped), for: .touchUpInside)
        destCard.addSubview(addDestButton)
        NSLayoutConstraint.activate([
            addDestButton.topAnchor.constraint(equalTo: destStack.bottomAnchor, constant: 10),
            addDestButton.leadingAnchor.constraint(equalTo: destCard.leadingAnchor, constant: 16),
            addDestButton.trailingAnchor.constraint(equalTo: destCard.trailingAnchor, constant: -12),
            addDestButton.heightAnchor.constraint(equalToConstant: 34)
        ])

        // Nút bắt đầu
        goButton.translatesAutoresizingMaskIntoConstraints = false
        goButton.setTitle("▶ BẮT ĐẦU", for: .normal)
        goButton.setTitleColor(UIColor(red: 0.35, green: 0.13, blue: 0.20, alpha: 1), for: .normal)
        goButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        goButton.backgroundColor = UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 1)
        goButton.layer.cornerRadius = 14
        goButton.addTarget(self, action: #selector(goTapped), for: .touchUpInside)
        destCard.addSubview(goButton)
        NSLayoutConstraint.activate([
            goButton.topAnchor.constraint(equalTo: addDestButton.bottomAnchor, constant: 10),
            goButton.leadingAnchor.constraint(equalTo: destCard.leadingAnchor, constant: 16),
            goButton.trailingAnchor.constraint(equalTo: destCard.trailingAnchor, constant: -16),
            goButton.heightAnchor.constraint(equalToConstant: 46),
            goButton.bottomAnchor.constraint(equalTo: destCard.bottomAnchor, constant: -14)
        ])

        // Bảng gợi ý địa chỉ (ẩn mặc định)
        suggestionTable.translatesAutoresizingMaskIntoConstraints = false
        suggestionTable.isHidden = true
        suggestionTable.backgroundColor = UIColor(white: 0.1, alpha: 0.98)
        suggestionTable.separatorColor = .darkGray
        suggestionTable.layer.cornerRadius = 14
        suggestionTable.clipsToBounds = true
        suggestionTable.dataSource = self
        suggestionTable.delegate = self
        view.addSubview(suggestionTable)
        NSLayoutConstraint.activate([
            suggestionTable.topAnchor.constraint(equalTo: destCard.bottomAnchor, constant: 6),
            suggestionTable.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            suggestionTable.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            suggestionTable.heightAnchor.constraint(equalToConstant: 280)
        ])

        // Trạng thái
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.text = "Đang tìm HUD..."
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        statusLabel.layer.cornerRadius = 6
        statusLabel.clipsToBounds = true
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: destCard.bottomAnchor, constant: 6),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12)
        ])

        // ---- HUD card dưới đáy ----
        hudCard.translatesAutoresizingMaskIntoConstraints = false
        hudCard.isHidden = true
        hudCard.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        hudCard.layer.cornerRadius = 18
        hudCard.layer.borderWidth = 1
        hudCard.layer.borderColor = UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 0.6).cgColor
        view.addSubview(hudCard)
        NSLayoutConstraint.activate([
            hudCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            hudCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            hudCard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            hudCard.heightAnchor.constraint(equalToConstant: 150)
        ])

        arrowLabel.translatesAutoresizingMaskIntoConstraints = false
        arrowLabel.font = .systemFont(ofSize: 52, weight: .bold)
        arrowLabel.textColor = UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 1)
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
        progressView.progressTintColor = UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 1)
        progressView.trackTintColor = .darkGray
        hudCard.addSubview(progressView)

        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.setTitle("■ Dừng", for: .normal)
        stopButton.setTitleColor(.systemRed, for: .normal)
        stopButton.titleLabel?.font = .boldSystemFont(ofSize: 13)
        stopButton.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        stopButton.layer.cornerRadius = 8
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        hudCard.addSubview(stopButton)

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
            progressView.bottomAnchor.constraint(equalTo: hudCard.bottomAnchor, constant: -14),

            stopButton.trailingAnchor.constraint(equalTo: hudCard.trailingAnchor, constant: -12),
            stopButton.topAnchor.constraint(equalTo: hudCard.topAnchor, constant: 10),
            stopButton.widthAnchor.constraint(equalToConstant: 58),
            stopButton.heightAnchor.constraint(equalToConstant: 28)
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
        arriveTitle.textColor = UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 1)
        arriveTitle.textAlignment = .center
        arriveOverlay.addSubview(arriveTitle)

        arriveSubtitle.translatesAutoresizingMaskIntoConstraints = false
        arriveSubtitle.text = ""
        arriveSubtitle.font = .systemFont(ofSize: 14)
        arriveSubtitle.textColor = .lightGray
        arriveSubtitle.textAlignment = .center
        arriveSubtitle.numberOfLines = 2
        arriveOverlay.addSubview(arriveSubtitle)

        qrImageView.translatesAutoresizingMaskIntoConstraints = false
        qrImageView.contentMode = .scaleAspectFit
        qrImageView.backgroundColor = .white
        qrImageView.layer.cornerRadius = 12
        qrImageView.clipsToBounds = true
        arriveOverlay.addSubview(qrImageView)

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("Đóng", for: .normal)
        closeButton.setTitleColor(UIColor(red: 0.35, green: 0.13, blue: 0.20, alpha: 1), for: .normal)
        closeButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        closeButton.backgroundColor = UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 1)
        closeButton.layer.cornerRadius = 12
        closeButton.addTarget(self, action: #selector(closeArriveOverlay), for: .touchUpInside)
        arriveOverlay.addSubview(closeButton)

        NSLayoutConstraint.activate([
            arriveTitle.centerXAnchor.constraint(equalTo: arriveOverlay.centerXAnchor),
            arriveTitle.topAnchor.constraint(equalTo: arriveOverlay.safeAreaLayoutGuide.topAnchor, constant: 60),

            arriveSubtitle.centerXAnchor.constraint(equalTo: arriveOverlay.centerXAnchor),
            arriveSubtitle.topAnchor.constraint(equalTo: arriveTitle.bottomAnchor, constant: 8),
            arriveSubtitle.leadingAnchor.constraint(equalTo: arriveOverlay.leadingAnchor, constant: 32),
            arriveSubtitle.trailingAnchor.constraint(equalTo: arriveOverlay.trailingAnchor, constant: -32),

            qrImageView.centerXAnchor.constraint(equalTo: arriveOverlay.centerXAnchor),
            qrImageView.topAnchor.constraint(equalTo: arriveSubtitle.bottomAnchor, constant: 20),
            qrImageView.widthAnchor.constraint(equalToConstant: 250),
            qrImageView.heightAnchor.constraint(equalToConstant: 250),

            closeButton.centerXAnchor.constraint(equalTo: arriveOverlay.centerXAnchor),
            closeButton.topAnchor.constraint(equalTo: qrImageView.bottomAnchor, constant: 24),
            closeButton.widthAnchor.constraint(equalToConstant: 140),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // MARK: - Hàng điểm đến (động)

    /// Tạo 1 hàng: [số] [ô nhập] [✕]
    private func makeDestinationRow() -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        row.layer.cornerRadius = 10
        row.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let indexLabel = UILabel()
        indexLabel.translatesAutoresizingMaskIntoConstraints = false
        indexLabel.text = "\(destinationFields.count + 1)"
        indexLabel.font = .boldSystemFont(ofSize: 13)
        indexLabel.textColor = UIColor(red: 0.35, green: 0.13, blue: 0.20, alpha: 1)
        indexLabel.textAlignment = .center
        indexLabel.backgroundColor = UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 1)
        indexLabel.layer.cornerRadius = 11
        indexLabel.clipsToBounds = true
        row.addSubview(indexLabel)

        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.textColor = .black
        field.attributedPlaceholder = NSAttributedString(
            string: "Nhập điểm đến \(destinationFields.count + 1)...",
            attributes: [.foregroundColor: UIColor.darkGray]
        )
        field.returnKeyType = .go
        field.delegate = self
        field.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        row.addSubview(field)

        let removeButton = UIButton(type: .system)
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.setTitle("✕", for: .normal)
        removeButton.setTitleColor(.systemRed, for: .normal)
        removeButton.titleLabel?.font = .boldSystemFont(ofSize: 15)
        removeButton.addTarget(self, action: #selector(removeDestTapped(_:)), for: .touchUpInside)
        removeButton.tag = destinationFields.count
        removeButton.isHidden = destinationFields.isEmpty  // giữ ít nhất 1 hàng
        row.addSubview(removeButton)

        NSLayoutConstraint.activate([
            indexLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 8),
            indexLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            indexLabel.widthAnchor.constraint(equalToConstant: 22),
            indexLabel.heightAnchor.constraint(equalToConstant: 22),

            field.leadingAnchor.constraint(equalTo: indexLabel.trailingAnchor, constant: 8),
            field.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            field.trailingAnchor.constraint(equalTo: removeButton.leadingAnchor, constant: -6),

            removeButton.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8),
            removeButton.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 26)
        ])

        destinationFields.append(field)
        destinationCoords.append(nil)
        stopCompleted.append(false)
        return row
    }

    /// Đồng bộ nút ✕: chỉ hiện khi có từ 2 hàng trở lên
    private func updateRemoveButtons() {
        let show = destinationFields.count > 1
        for view in destStack.arrangedSubviews {
            if let btn = view.subviews.compactMap({ $0 as? UIButton }).first {
                btn.isHidden = !show
            }
        }
    }

    /// Đưa toàn bộ ô về trạng thái chưa hoàn thành (số thứ tự thường)
    private func resetStopUI() {
        for (i, row) in destStack.arrangedSubviews.enumerated() {
            if let lbl = row.subviews.first as? UILabel {
                lbl.text = "\(i + 1)"
                lbl.backgroundColor = UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 1)
            }
            if let field = row.subviews.compactMap({ $0 as? UITextField }).first {
                field.isEnabled = true
                field.textColor = .black
            }
        }
        updateRemoveButtons()
    }

    /// Đánh dấu 1 điểm đã hoàn thành (hiện QR): số → ✓ màu xanh lá
    private func markStopCompletedUI(at index: Int) {
        guard index < destStack.arrangedSubviews.count else { return }
        let row = destStack.arrangedSubviews[index]
        if let lbl = row.subviews.first as? UILabel {
            lbl.text = "✓"
            lbl.backgroundColor = .systemGreen
        }
        if let field = row.subviews.compactMap({ $0 as? UITextField }).first {
            field.isEnabled = false
            field.textColor = .systemGray
        }
    }

    @objc private func addDestTapped() {
        guard destinationFields.count < 5 else {
            statusLabel.text = "Tối đa 5 điểm đến"
            return
        }
        addDestinationRow()
    }

    private func addDestinationRow() {
        let row = makeDestinationRow()
        destStack.addArrangedSubview(row)
        updateRemoveButtons()
        // Cuộn focus xuống ô mới
        destinationFields.last?.becomeFirstResponder()
    }

    @objc private func removeDestTapped(_ sender: UIButton) {
        let idx = sender.tag
        guard idx < destinationFields.count, destinationFields.count > 1 else { return }
        // Gỡ khỏi stack
        let row = destStack.arrangedSubviews[idx]
        destStack.removeArrangedSubview(row)
        row.removeFromSuperview()
        destinationFields.remove(at: idx)
        destinationCoords.remove(at: idx)
        stopCompleted.remove(at: idx)
        // Đánh lại số + tag
        resetStopUI()
        for (i, view) in destStack.arrangedSubviews.enumerated() {
            if let btn = view.subviews.compactMap({ $0 as? UIButton }).first { btn.tag = i }
        }
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
                self?.statusLabel.textColor = connected ? UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 1) : .white
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
        // Còn điểm nào chưa hoàn thành thì hướng dẫn người dùng tự chọn
        if let idx = firstIncompleteStop() {
            statusLabel.text = "Đã hoàn thành điểm \(currentStopIndex + 1) — chọn điểm \(idx + 1) và bấm BẮT ĐẦU"
            destinationFields[idx].becomeFirstResponder()
        } else {
            statusLabel.text = "🎉 Đã hoàn thành TẤT CẢ điểm đến! Bấm BẮT ĐẦU để chạy lại từ đầu"
        }
    }

    @objc private func textChanged(_ sender: UITextField) {
        if let idx = destinationFields.firstIndex(of: sender) {
            activeFieldIndex = idx
        }
        guard let text = sender.text, !text.isEmpty else {
            suggestionTable.isHidden = true
            suggestions = []
            return
        }
        completer.queryFragment = text
    }

    @objc private func stopTapped() {
        isNavigating = false
        steps = []
        suggestionTable.isHidden = true
        hudCard.isHidden = true
        if let poly = routePolyline {
            mapView.removeOverlay(poly)
            routePolyline = nil
        }
        statusLabel.text = "Đã dừng dẫn đường — bấm BẮT ĐẦU khi muốn đi tiếp"
        ble.send(json: [
            "speed": 0, "distance": 0,
            "next_road": "", "next_road_sub": "",
            "eta": "", "ete": "", "total_distance": "",
            "maneuver": "straight"
        ])
    }

    /// Điểm đến chưa hoàn thành đầu tiên có nội dung (theo thứ tự ô)
    private func firstIncompleteStop() -> Int? {
        for (i, field) in destinationFields.enumerated() {
            let text = field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty && !stopCompleted[i] {
                return i
            }
        }
        return nil
    }

    @objc private func goTapped() {
        view.endEditing(true)
        suggestionTable.isHidden = true

        // Chưa nhập điểm nào → báo nhập
        let hasAnyText = destinationFields.contains {
            !($0.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
        }
        if !hasAnyText {
            statusLabel.text = "Nhập ít nhất 1 điểm đến"
            return
        }

        // Nếu tất cả đã hoàn thành → reset để chạy lại từ đầu
        if firstIncompleteStop() == nil {
            for i in 0..<stopCompleted.count { stopCompleted[i] = false }
            resetStopUI()
            statusLabel.text = "Bắt đầu lượt mới — nhập/chọn điểm đến rồi bấm BẮT ĐẦU"
            return
        }

        // Xây danh sách tọa độ theo đúng thứ tự các ô
        var stopCoords: [CLLocationCoordinate2D?] = Array(repeating: nil, count: destinationFields.count)
        var needGeocode: [(String, Int)] = []
        for (i, field) in destinationFields.enumerated() {
            let text = field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty { continue }
            if let c = destinationCoords[i] {
                stopCoords[i] = c
            } else {
                needGeocode.append((text, i))
            }
        }

        guard stopCoords.contains(where: { $0 != nil }) else {
            statusLabel.text = "Nhập ít nhất 1 điểm đến"
            return
        }

        if needGeocode.isEmpty {
            startFirstIncomplete(stopCoords)
            return
        }

        statusLabel.text = "Đang tìm địa chỉ..."
        let group = DispatchGroup()
        var results: [Int: CLLocationCoordinate2D] = [:]
        for (text, i) in needGeocode {
            group.enter()
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(text) { placemarks, error in
                if let coord = placemarks?.first?.location?.coordinate {
                    results[i] = coord
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            for (text, i) in needGeocode {
                if let c = results[i] {
                    stopCoords[i] = c
                } else {
                    self.statusLabel.text = "Không tìm thấy: \(text)"
                    return
                }
            }
            self.startFirstIncomplete(stopCoords)
        }
    }

    /// Bắt đầu dẫn tới điểm chưa hoàn thành đầu tiên (chỉ 1 chặng)
    private func startFirstIncomplete(_ stopCoords: [CLLocationCoordinate2D?]) {
        guard let idx = firstIncompleteStop() else {
            statusLabel.text = "Đã hoàn thành tất cả điểm đến!"
            return
        }
        guard idx < stopCoords.count, let dest = stopCoords[idx] else {
            statusLabel.text = "Điểm \(idx + 1) chưa có tọa độ — chọn từ gợi ý"
            return
        }

        currentStopIndex = idx
        totalStopsWithText = destinationFields.filter {
            ($0.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty == false
        }.count

        isNavigating = true
        hudCard.isHidden = false
        arriveOverlay.isHidden = true

        guard let origin = locationManager.location?.coordinate else {
            pendingDestination = dest
            statusLabel.text = "Đang chờ vị trí GPS..."
            return
        }
        fetchLeg(from: origin, to: dest)
    }

    /// Tính tuyến cho chặng hiện tại (vị trí hiện tại → điểm đến đã chọn)
    private func fetchLeg(from origin: CLLocationCoordinate2D,
                          to destination: CLLocationCoordinate2D) {
        pendingDestination = nil
        let total = max(totalStopsWithText, 1)
        statusLabel.text = "Đang lấy tuyến tới điểm \(currentStopIndex + 1)/\(total)..."
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
            self.statusLabel.text = "Đang dẫn đường tới điểm \(self.currentStopIndex + 1)/\(total) (\(totalDistanceText))"
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

    /// Hiện overlay "ĐÃ ĐẾN NƠI / HOÀN THÀNH ĐƠN HÀNG" + mã QR thanh toán
    private func showArriveOverlay() {
        hudCard.isHidden = true
        isNavigating = false

        // Đánh dấu điểm vừa hoàn thành
        if currentStopIndex < stopCompleted.count {
            stopCompleted[currentStopIndex] = true
        }
        markStopCompletedUI(at: currentStopIndex)

        let orderNo = currentStopIndex + 1
        if let qr = makeQRImage(from: qrString) {
            qrImageView.image = qr
            qrImageView.isHidden = false
        } else {
            qrImageView.isHidden = true
        }

        arriveTitle.text = "🏁 HOÀN THÀNH ĐƠN \(orderNo)"
        if qrString.isEmpty {
            arriveSubtitle.text = "Đã đến điểm \(orderNo) — nhập mã QR ở nút ◧ QR để quét thanh toán"
        } else {
            if let idx = firstIncompleteStop() {
                arriveSubtitle.text = "Quét mã thanh toán xong → đóng, chọn điểm \(idx + 1) và bấm BẮT ĐẦU để đi tiếp"
            } else {
                arriveSubtitle.text = "Quét mã thanh toán xong → đóng. 🎉 Đã xong tất cả điểm đến!"
            }
        }
        arriveOverlay.isHidden = false
    }
}

// MARK: - MKMapViewDelegate

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 0.9)
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
            let idx = self.activeFieldIndex
            guard idx < self.destinationFields.count else { return }
            self.destinationFields[idx].text = completion.title
            self.destinationCoords[idx] = item.placemark.coordinate
            self.suggestionTable.isHidden = true
            self.destinationFields[idx].resignFirstResponder()
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
            fetchLeg(from: coord, to: pending)
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

        // ---- ĐẾN NƠI: hiện QR thanh toán (hoàn thành đơn hàng) và DỪNG ----
        // KHÔNG tự chuyển chặng — người dùng tự chọn điểm tiếp theo và bấm BẮT ĐẦU
        let isArriveStep = step.maneuver == "arrive" || currentStepIndex == steps.count - 1
        if isArriveStep && bestDistance < 40 {
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

        // Cập nhật HUD card trên app
        arrowLabel.text = arrowSymbol(for: step.maneuver)
        arrowLabel.textColor = step.maneuver == "arrive" ? .systemYellow : UIColor(red: 0.988, green: 0.710, blue: 0.769, alpha: 1)
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
        // Chuyển focus xuống ô tiếp theo, hoặc bắt đầu nếu là ô cuối
        if let idx = destinationFields.firstIndex(of: textField), idx < destinationFields.count - 1 {
            destinationFields[idx + 1].becomeFirstResponder()
        } else {
            goTapped()
        }
        return true
    }
}
