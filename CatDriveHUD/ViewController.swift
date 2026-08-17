import UIKit
import MapKit
import CoreLocation
import CoreImage

final class ViewController: UIViewController {

    // MARK: - Theme — Neon Glass
    private let pink = UIColor(red: 1.00, green: 0.30, blue: 0.62, alpha: 1)
    private let purple = UIColor(red: 0.55, green: 0.36, blue: 1.00, alpha: 1)
    private let cyan = UIColor(red: 0.30, green: 0.84, blue: 1.00, alpha: 1)
    private let panel = UIColor(red: 0.055, green: 0.072, blue: 0.115, alpha: 0.86)
    private let softPanel = UIColor(red: 0.09, green: 0.115, blue: 0.17, alpha: 0.92)
    private let rowSurface = UIColor(red: 0.10, green: 0.125, blue: 0.185, alpha: 1)

    // MARK: - Map / top UI
    private let mapView = MKMapView()
    private let header = UIView()
    private let logoLabel = UILabel()
    private let titleLabel = UILabel()
    private let connectionDot = UIView()
    private let connectionLabel = UILabel()
    private let qrButton = UIButton(type: .system)

    // MARK: - Destination UI
    private let destinationCard = UIView()
    private let destinationTitle = UILabel()
    private let destinationStack = UIStackView()
    private let addDestinationButton = UIButton(type: .system)
    private let startButton = UIButton(type: .system)
    private let suggestionTable = UITableView()
    private let statusLabel = UILabel()

    // MARK: - Map controls
    private let layersButton = UIButton(type: .system)
    private let locationButton = UIButton(type: .system)
    private let headingButton = UIButton(type: .system)
    private let zoomStack = UIStackView()
    private let zoomInButton = UIButton(type: .system)
    private let zoomOutButton = UIButton(type: .system)

    // MARK: - Navigation HUD
    private let navigationCard = UIView()
    private let navHandle = UIView()
    private let navArrow = UILabel()
    private let navDistance = UILabel()
    private let navRoad = UILabel()
    private let navEta = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let stopButton = UIButton(type: .system)

    // MARK: - Trip summary
    private let summaryCard = UIView()
    private let distanceValue = UILabel()
    private let distanceCaption = UILabel()
    private let etaValue = UILabel()
    private let etaCaption = UILabel()
    private let destinationValue = UILabel()
    private let destinationCaption = UILabel()

    // MARK: - Bottom tabs
    private let bottomBar = UIView()
    private let mapTabButton = UIButton(type: .system)
    private let ordersTabButton = UIButton(type: .system)
    private let mapTabIcon = UIImageView()
    private let ordersTabIcon = UIImageView()
    private let mapTabLabel = UILabel()
    private let ordersTabLabel = UILabel()
    private let ordersPanel = UIView()
    private let ordersScroll = UIScrollView()
    private let ordersStack = UIStackView()
    private var showingOrders = false

    // MARK: - Arrival / QR
    private let arriveOverlay = UIView()
    private let arriveTitle = UILabel()
    private let arriveSubtitle = UILabel()
    private let qrImageView = UIImageView()
    private let arriveCheckIcon = UIImageView()
    private let arriveCloseButton = UIButton(type: .system)

    // MARK: - Services
    private let locationManager = CLLocationManager()
    private let ble = BLEManager()
    private let nav = NavigationManager()
    private let completer = MKLocalSearchCompleter()

    // MARK: - Navigation state
    private var destinationFields: [UITextField] = []
    private var destinationCoords: [CLLocationCoordinate2D?] = []
    private var stopCompleted: [Bool] = []
    private var activeFieldIndex = 0
    private var suggestions: [MKLocalSearchCompletion] = []
    private var steps: [RouteStep] = []
    private var currentStepIndex = 0
    private var isNavigating = false
    private var totalDistanceText = ""
    private var routePolyline: MKPolyline?
    private var routeCoordinates: [CLLocationCoordinate2D] = []
    private var pendingDestination: CLLocationCoordinate2D?
    private var lastSendTime: TimeInterval = 0
    private var currentStopIndex = 0
    private var totalStopsWithText = 0
    private let turnPreviewDistanceM: Double = 100.0

    // MARK: - Persistent QR / order history
    private var qrString: String {
        get { UserDefaults.standard.string(forKey: "qrString") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "qrString") }
    }

    private struct CompletedTrip: Codable {
        let destination: String
        let distance: String
        let duration: String
        let completedAt: Date
        let stopNumber: Int
    }

    private var completedTrips: [CompletedTrip] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "completedTrips"),
                  let value = try? JSONDecoder().decode([CompletedTrip].self, from: data) else { return [] }
            return value
        }
        set {
            let limited = Array(newValue.prefix(100))
            if let data = try? JSONEncoder().encode(limited) {
                UserDefaults.standard.set(data, forKey: "completedTrips")
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        setupLocation()
        setupBLE()
        setupCompleter()
        addDestinationRow(focus: false)
        updateBottomTabs()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let gradient = startButton.layer.sublayers?.first(where: { $0.name == "startGradient" }) as? CAGradientLayer {
            gradient.frame = startButton.bounds
        }
        if let gradient = logoLabel.layer.sublayers?.first(where: { $0.name == "logoGradient" }) as? CAGradientLayer {
            gradient.frame = logoLabel.bounds
        }
        if let gradient = arriveCloseButton.layer.sublayers?.first(where: { $0.name == "closeGradient" }) as? CAGradientLayer {
            gradient.frame = arriveCloseButton.bounds
        }
        if let gradient = header.layer.sublayers?.first(where: { $0.name == "headerGradient" }) as? CAGradientLayer {
            gradient.frame = header.bounds
        }
    }

    // MARK: - UI setup

    private func setupUI() {
        setupMap()
        setupHeader()
        setupDestinationCard()
        // bottomBar must be in the view hierarchy before setupMapControls()
        // because the map controls are constrained relative to bottomBar.topAnchor.
        setupBottomBar()
        setupMapControls()
        // QUAN TRỌNG: setupSummaryCard() phải chạy TRƯỚC setupNavigationCard()
        // vì navigationCard có constraint tới summaryCard.topAnchor —
        // nếu summaryCard chưa addSubview, activate constraint sẽ crash
        // (NSLayoutAnchor _nearestAncestorLayoutItem / SIGABRT)
        setupSummaryCard()
        setupNavigationCard()
        setupOrdersPanel()
        setupArrivalOverlay()
    }

    private func setupMap() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.delegate = self
        mapView.overrideUserInterfaceStyle = .dark
        mapView.pointOfInterestFilter = .includingAll
        view.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupHeader() {
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 116)
        ])

        let gradient = CAGradientLayer()
        gradient.name = "headerGradient"
        gradient.colors = [
            UIColor.black.withAlphaComponent(0.92).cgColor,
            UIColor.black.withAlphaComponent(0.55).cgColor,
            UIColor.clear.cgColor
        ]
        gradient.locations = [0.0, 0.65, 1.0]
        header.layer.insertSublayer(gradient, at: 0)

        logoLabel.translatesAutoresizingMaskIntoConstraints = false
        logoLabel.text = "H"
        logoLabel.textAlignment = .center
        logoLabel.font = roundedFont(24, .black)
        logoLabel.textColor = .white
        logoLabel.layer.cornerRadius = 15
        let logoGradient = CAGradientLayer()
        logoGradient.name = "logoGradient"
        logoGradient.cornerRadius = 15
        logoGradient.colors = [pink.cgColor, purple.cgColor]
        logoGradient.startPoint = CGPoint(x: 0, y: 0)
        logoGradient.endPoint = CGPoint(x: 1, y: 1)
        logoLabel.layer.insertSublayer(logoGradient, at: 0)
        logoLabel.layer.shadowColor = pink.cgColor
        logoLabel.layer.shadowOpacity = 0.45
        logoLabel.layer.shadowRadius = 10
        logoLabel.layer.shadowOffset = CGSize(width: 0, height: 4)
        header.addSubview(logoLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "HOHI DRIVE"
        titleLabel.font = roundedFont(22, .heavy)
        titleLabel.textColor = .white
        header.addSubview(titleLabel)

        connectionDot.translatesAutoresizingMaskIntoConstraints = false
        connectionDot.backgroundColor = .systemGreen
        connectionDot.layer.cornerRadius = 4
        connectionDot.layer.shadowColor = UIColor.systemGreen.cgColor
        connectionDot.layer.shadowOpacity = 0.8
        connectionDot.layer.shadowRadius = 4
        connectionDot.layer.shadowOffset = .zero
        header.addSubview(connectionDot)

        connectionLabel.translatesAutoresizingMaskIntoConstraints = false
        connectionLabel.text = "Đã kết nối"
        connectionLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        connectionLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        header.addSubview(connectionLabel)

        qrButton.translatesAutoresizingMaskIntoConstraints = false
        qrButton.setImage(UIImage(systemName: "qrcode"), for: .normal)
        qrButton.tintColor = .white
        qrButton.backgroundColor = softPanel
        qrButton.layer.cornerRadius = 19
        qrButton.layer.borderWidth = 1
        qrButton.layer.borderColor = pink.withAlphaComponent(0.40).cgColor
        qrButton.addTarget(self, action: #selector(qrTapped), for: .touchUpInside)
        header.addSubview(qrButton)

        NSLayoutConstraint.activate([
            logoLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 22),
            logoLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -22),
            logoLabel.widthAnchor.constraint(equalToConstant: 48),
            logoLabel.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.leadingAnchor.constraint(equalTo: logoLabel.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: logoLabel.topAnchor, constant: 2),

            connectionDot.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            connectionDot.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            connectionDot.widthAnchor.constraint(equalToConstant: 8),
            connectionDot.heightAnchor.constraint(equalToConstant: 8),

            connectionLabel.leadingAnchor.constraint(equalTo: connectionDot.trailingAnchor, constant: 7),
            connectionLabel.centerYAnchor.constraint(equalTo: connectionDot.centerYAnchor),

            qrButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -18),
            qrButton.centerYAnchor.constraint(equalTo: logoLabel.centerYAnchor),
            qrButton.widthAnchor.constraint(equalToConstant: 58),
            qrButton.heightAnchor.constraint(equalToConstant: 58)
        ])
    }

    private func setupDestinationCard() {
        destinationCard.translatesAutoresizingMaskIntoConstraints = false
        applyGlass(to: destinationCard, cornerRadius: 26)
        view.addSubview(destinationCard)
        NSLayoutConstraint.activate([
            destinationCard.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            destinationCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            destinationCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18)
        ])

        destinationTitle.translatesAutoresizingMaskIntoConstraints = false
        destinationTitle.attributedText = NSAttributedString(
            string: "ĐIỂM ĐẾN",
            attributes: [
                .kern: 1.8,
                .font: roundedFont(12, .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.62)
            ]
        )
        destinationCard.addSubview(destinationTitle)

        destinationStack.translatesAutoresizingMaskIntoConstraints = false
        destinationStack.axis = .vertical
        destinationStack.spacing = 10
        destinationCard.addSubview(destinationStack)

        addDestinationButton.translatesAutoresizingMaskIntoConstraints = false
        addDestinationButton.setTitle("＋  Thêm điểm đến", for: .normal)
        addDestinationButton.setTitleColor(pink, for: .normal)
        addDestinationButton.titleLabel?.font = roundedFont(15, .semibold)
        addDestinationButton.contentHorizontalAlignment = .left
        addDestinationButton.addTarget(self, action: #selector(addDestTapped), for: .touchUpInside)
        destinationCard.addSubview(addDestinationButton)

        styleGradientButton(startButton, title: "BẮT ĐẦU", symbol: "location.north.fill")
        startButton.addTarget(self, action: #selector(goTapped), for: .touchUpInside)
        destinationCard.addSubview(startButton)

        NSLayoutConstraint.activate([
            destinationTitle.topAnchor.constraint(equalTo: destinationCard.topAnchor, constant: 18),
            destinationTitle.leadingAnchor.constraint(equalTo: destinationCard.leadingAnchor, constant: 22),

            destinationStack.topAnchor.constraint(equalTo: destinationTitle.bottomAnchor, constant: 12),
            destinationStack.leadingAnchor.constraint(equalTo: destinationCard.leadingAnchor, constant: 16),
            destinationStack.trailingAnchor.constraint(equalTo: destinationCard.trailingAnchor, constant: -16),

            addDestinationButton.topAnchor.constraint(equalTo: destinationStack.bottomAnchor, constant: 8),
            addDestinationButton.leadingAnchor.constraint(equalTo: destinationCard.leadingAnchor, constant: 22),
            addDestinationButton.trailingAnchor.constraint(equalTo: destinationCard.trailingAnchor, constant: -22),
            addDestinationButton.heightAnchor.constraint(equalToConstant: 36),

            startButton.topAnchor.constraint(equalTo: addDestinationButton.bottomAnchor, constant: 8),
            startButton.leadingAnchor.constraint(equalTo: destinationCard.leadingAnchor, constant: 16),
            startButton.trailingAnchor.constraint(equalTo: destinationCard.trailingAnchor, constant: -16),
            startButton.heightAnchor.constraint(equalToConstant: 60),
            startButton.bottomAnchor.constraint(equalTo: destinationCard.bottomAnchor, constant: -16)
        ])

        suggestionTable.translatesAutoresizingMaskIntoConstraints = false
        suggestionTable.isHidden = true
        suggestionTable.backgroundColor = UIColor(red: 0.05, green: 0.065, blue: 0.10, alpha: 0.98)
        suggestionTable.separatorColor = UIColor.white.withAlphaComponent(0.08)
        suggestionTable.layer.cornerRadius = 18
        suggestionTable.clipsToBounds = true
        suggestionTable.dataSource = self
        suggestionTable.delegate = self
        view.addSubview(suggestionTable)
        NSLayoutConstraint.activate([
            suggestionTable.topAnchor.constraint(equalTo: destinationCard.bottomAnchor, constant: 6),
            suggestionTable.leadingAnchor.constraint(equalTo: destinationCard.leadingAnchor),
            suggestionTable.trailingAnchor.constraint(equalTo: destinationCard.trailingAnchor),
            suggestionTable.heightAnchor.constraint(equalToConstant: 260)
        ])

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Đang tìm HUD..."
        statusLabel.font = .systemFont(ofSize: 11.5, weight: .medium)
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        statusLabel.numberOfLines = 2
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: destinationCard.bottomAnchor, constant: 6),
            statusLabel.leadingAnchor.constraint(equalTo: destinationCard.leadingAnchor, constant: 4),
            statusLabel.trailingAnchor.constraint(equalTo: destinationCard.trailingAnchor, constant: -4)
        ])
    }

    private func setupMapControls() {
        let buttons = [
            (layersButton, "square.3.layers.3d", "Lớp bản đồ", #selector(layersTapped)),
            (locationButton, "location.fill", "Vị trí", #selector(locationTapped)),
            (headingButton, "location.north.line.fill", "Định hướng", #selector(headingTapped))
        ]
        for (button, icon, title, action) in buttons {
            styleMapControl(button, systemName: icon, title: title)
            button.addTarget(self, action: action, for: .touchUpInside)
            view.addSubview(button)
        }

        NSLayoutConstraint.activate([
            layersButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            layersButton.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -272),
            layersButton.widthAnchor.constraint(equalToConstant: 88),
            layersButton.heightAnchor.constraint(equalToConstant: 66),

            locationButton.leadingAnchor.constraint(equalTo: layersButton.leadingAnchor),
            locationButton.topAnchor.constraint(equalTo: layersButton.bottomAnchor, constant: 10),
            locationButton.widthAnchor.constraint(equalTo: layersButton.widthAnchor),
            locationButton.heightAnchor.constraint(equalTo: layersButton.heightAnchor),

            headingButton.leadingAnchor.constraint(equalTo: layersButton.leadingAnchor),
            headingButton.topAnchor.constraint(equalTo: locationButton.bottomAnchor, constant: 10),
            headingButton.widthAnchor.constraint(equalTo: layersButton.widthAnchor),
            headingButton.heightAnchor.constraint(equalTo: layersButton.heightAnchor)
        ])

        zoomStack.translatesAutoresizingMaskIntoConstraints = false
        zoomStack.axis = .vertical
        zoomStack.spacing = 1
        zoomStack.backgroundColor = softPanel
        zoomStack.layer.cornerRadius = 18
        zoomStack.clipsToBounds = true
        view.addSubview(zoomStack)
        stylePlainIconButton(zoomInButton, systemName: "plus")
        stylePlainIconButton(zoomOutButton, systemName: "minus")
        zoomInButton.addTarget(self, action: #selector(zoomInTapped), for: .touchUpInside)
        zoomOutButton.addTarget(self, action: #selector(zoomOutTapped), for: .touchUpInside)
        zoomStack.addArrangedSubview(zoomInButton)
        zoomStack.addArrangedSubview(zoomOutButton)
        NSLayoutConstraint.activate([
            zoomStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            zoomStack.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -170),
            zoomStack.widthAnchor.constraint(equalToConstant: 56),
            zoomStack.heightAnchor.constraint(equalToConstant: 112)
        ])
    }

    private func setupNavigationCard() {
        navigationCard.translatesAutoresizingMaskIntoConstraints = false
        navigationCard.isHidden = true
        applyGlass(to: navigationCard, cornerRadius: 26)
        view.addSubview(navigationCard)
        NSLayoutConstraint.activate([
            navigationCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            navigationCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            navigationCard.bottomAnchor.constraint(equalTo: summaryCard.topAnchor, constant: -10),
            navigationCard.heightAnchor.constraint(equalToConstant: 118)
        ])

        navHandle.translatesAutoresizingMaskIntoConstraints = false
        navHandle.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        navHandle.layer.cornerRadius = 2.5
        navigationCard.addSubview(navHandle)

        navArrow.translatesAutoresizingMaskIntoConstraints = false
        navArrow.text = "↑"
        navArrow.font = roundedFont(38, .heavy)
        navArrow.textColor = pink
        navArrow.textAlignment = .center
        navArrow.backgroundColor = pink.withAlphaComponent(0.14)
        navArrow.layer.cornerRadius = 20
        navArrow.clipsToBounds = true
        navigationCard.addSubview(navArrow)

        navDistance.translatesAutoresizingMaskIntoConstraints = false
        navDistance.text = "— m"
        navDistance.font = monoFont(32, .bold)
        navDistance.textColor = .white
        navDistance.textAlignment = .right
        navigationCard.addSubview(navDistance)

        navRoad.translatesAutoresizingMaskIntoConstraints = false
        navRoad.text = "Đang dẫn đường"
        navRoad.font = roundedFont(15, .semibold)
        navRoad.textColor = .white
        navRoad.numberOfLines = 1
        navRoad.lineBreakMode = .byTruncatingTail
        navigationCard.addSubview(navRoad)

        navEta.translatesAutoresizingMaskIntoConstraints = false
        navEta.font = .systemFont(ofSize: 11.5, weight: .medium)
        navEta.textColor = UIColor.white.withAlphaComponent(0.55)
        navigationCard.addSubview(navEta)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = pink
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.12)
        navigationCard.addSubview(progressView)

        styleStopButton()
        navigationCard.addSubview(stopButton)

        NSLayoutConstraint.activate([
            navHandle.centerXAnchor.constraint(equalTo: navigationCard.centerXAnchor),
            navHandle.topAnchor.constraint(equalTo: navigationCard.topAnchor, constant: 9),
            navHandle.widthAnchor.constraint(equalToConstant: 36),
            navHandle.heightAnchor.constraint(equalToConstant: 5),

            navArrow.leadingAnchor.constraint(equalTo: navigationCard.leadingAnchor, constant: 14),
            navArrow.topAnchor.constraint(equalTo: navigationCard.topAnchor, constant: 20),
            navArrow.widthAnchor.constraint(equalToConstant: 62),
            navArrow.heightAnchor.constraint(equalToConstant: 62),

            navDistance.trailingAnchor.constraint(equalTo: navigationCard.trailingAnchor, constant: -18),
            navDistance.topAnchor.constraint(equalTo: navigationCard.topAnchor, constant: 24),
            navDistance.widthAnchor.constraint(equalToConstant: 128),
            navDistance.heightAnchor.constraint(equalToConstant: 42),

            navRoad.leadingAnchor.constraint(equalTo: navArrow.trailingAnchor, constant: 12),
            navRoad.trailingAnchor.constraint(equalTo: navDistance.leadingAnchor, constant: -10),
            navRoad.topAnchor.constraint(equalTo: navigationCard.topAnchor, constant: 30),

            navEta.leadingAnchor.constraint(equalTo: navRoad.leadingAnchor),
            navEta.trailingAnchor.constraint(equalTo: navRoad.trailingAnchor),
            navEta.topAnchor.constraint(equalTo: navRoad.bottomAnchor, constant: 5),

            progressView.leadingAnchor.constraint(equalTo: navigationCard.leadingAnchor, constant: 18),
            progressView.trailingAnchor.constraint(equalTo: navigationCard.trailingAnchor, constant: -18),
            progressView.bottomAnchor.constraint(equalTo: navigationCard.bottomAnchor, constant: -14),

            stopButton.trailingAnchor.constraint(equalTo: navigationCard.trailingAnchor, constant: -14),
            stopButton.bottomAnchor.constraint(equalTo: navigationCard.bottomAnchor, constant: -30),
            stopButton.widthAnchor.constraint(equalToConstant: 96),
            stopButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func setupSummaryCard() {
        summaryCard.translatesAutoresizingMaskIntoConstraints = false
        applyGlass(to: summaryCard, cornerRadius: 26)
        view.addSubview(summaryCard)
        NSLayoutConstraint.activate([
            summaryCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            summaryCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            summaryCard.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -16),
            summaryCard.heightAnchor.constraint(equalToConstant: 98)
        ])

        let columns = [
            (distanceValue, distanceCaption, "arrow.up.right", "Quãng đường"),
            (etaValue, etaCaption, "clock", "Thời gian dự kiến"),
            (destinationValue, destinationCaption, "flag.fill", "Điểm đến")
        ]
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 10
        summaryCard.addSubview(stack)

        for (value, caption, symbol, text) in columns {
            let card = UIView()
            card.backgroundColor = UIColor.white.withAlphaComponent(0.03)
            card.layer.cornerRadius = 18
            card.layer.borderWidth = 1
            card.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
            stack.addArrangedSubview(card)

            let bubble = UIView()
            bubble.translatesAutoresizingMaskIntoConstraints = false
            bubble.backgroundColor = pink.withAlphaComponent(0.16)
            bubble.layer.cornerRadius = 11
            card.addSubview(bubble)

            let icon = UIImageView(image: UIImage(systemName: symbol))
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.tintColor = pink
            icon.contentMode = .scaleAspectFit
            bubble.addSubview(icon)

            value.translatesAutoresizingMaskIntoConstraints = false
            value.text = "—"
            value.font = roundedFont(17, .bold)
            value.textColor = .white
            card.addSubview(value)

            caption.translatesAutoresizingMaskIntoConstraints = false
            caption.text = text
            caption.font = .systemFont(ofSize: 10, weight: .medium)
            caption.textColor = UIColor.white.withAlphaComponent(0.55)
            card.addSubview(caption)

            NSLayoutConstraint.activate([
                bubble.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
                bubble.centerYAnchor.constraint(equalTo: card.centerYAnchor),
                bubble.widthAnchor.constraint(equalToConstant: 32),
                bubble.heightAnchor.constraint(equalToConstant: 32),
                icon.centerXAnchor.constraint(equalTo: bubble.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: bubble.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 17),
                icon.heightAnchor.constraint(equalToConstant: 17),
                caption.leadingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: 9),
                caption.topAnchor.constraint(equalTo: card.topAnchor, constant: 17),
                caption.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6),
                value.leadingAnchor.constraint(equalTo: caption.leadingAnchor),
                value.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: 3),
                value.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6)
            ])
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: summaryCard.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -10)
        ])
    }

    private func setupBottomBar() {
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.backgroundColor = UIColor(red: 0.045, green: 0.06, blue: 0.095, alpha: 0.95)
        bottomBar.layer.cornerRadius = 28
        bottomBar.layer.borderWidth = 1
        bottomBar.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        bottomBar.layer.shadowColor = UIColor.black.cgColor
        bottomBar.layer.shadowOpacity = 0.5
        bottomBar.layer.shadowRadius = 24
        bottomBar.layer.shadowOffset = CGSize(width: 0, height: 10)
        view.addSubview(bottomBar)
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),
            bottomBar.heightAnchor.constraint(equalToConstant: 78)
        ])

        setupTab(mapTabButton, icon: mapTabIcon, label: mapTabLabel, title: "Bản đồ", symbol: "map.fill", action: #selector(mapTabTapped))
        setupTab(ordersTabButton, icon: ordersTabIcon, label: ordersTabLabel, title: "Đơn hàng", symbol: "list.clipboard.fill", action: #selector(ordersTabTapped))

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        bottomBar.addSubview(divider)

        NSLayoutConstraint.activate([
            mapTabButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 12),
            mapTabButton.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 8),
            mapTabButton.bottomAnchor.constraint(equalTo: bottomBar.bottomAnchor, constant: -8),
            mapTabButton.widthAnchor.constraint(equalTo: bottomBar.widthAnchor, multiplier: 0.5, constant: -18),

            ordersTabButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -12),
            ordersTabButton.topAnchor.constraint(equalTo: mapTabButton.topAnchor),
            ordersTabButton.bottomAnchor.constraint(equalTo: mapTabButton.bottomAnchor),
            ordersTabButton.widthAnchor.constraint(equalTo: mapTabButton.widthAnchor),

            divider.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            divider.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupTab(_ button: UIButton, icon: UIImageView, label: UILabel, title: String, symbol: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
        bottomBar.addSubview(button)

        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.image = UIImage(systemName: symbol)
        icon.contentMode = .scaleAspectFit
        button.addSubview(icon)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = roundedFont(12, .semibold)
        button.addSubview(label)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            icon.topAnchor.constraint(equalTo: button.topAnchor, constant: 10),
            icon.widthAnchor.constraint(equalToConstant: 26),
            icon.heightAnchor.constraint(equalToConstant: 26),
            label.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 4)
        ])
    }

    private func setupOrdersPanel() {
        ordersPanel.translatesAutoresizingMaskIntoConstraints = false
        ordersPanel.isHidden = true
        applyGlass(to: ordersPanel, cornerRadius: 28)
        view.addSubview(ordersPanel)
        NSLayoutConstraint.activate([
            ordersPanel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            ordersPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            ordersPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            ordersPanel.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -18)
        ])

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Đơn hàng & lịch sử"
        title.font = roundedFont(20, .bold)
        title.textColor = .white
        ordersPanel.addSubview(title)

        let subtitle = UILabel()
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.text = "Lưu các quãng đường đã hoàn thành — phần sản phẩm, số lượng và tiền sẽ phát triển sau."
        subtitle.font = .systemFont(ofSize: 12.5, weight: .medium)
        subtitle.textColor = UIColor.white.withAlphaComponent(0.55)
        subtitle.numberOfLines = 2
        ordersPanel.addSubview(subtitle)

        ordersScroll.translatesAutoresizingMaskIntoConstraints = false
        ordersPanel.addSubview(ordersScroll)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: ordersPanel.topAnchor, constant: 24),
            title.leadingAnchor.constraint(equalTo: ordersPanel.leadingAnchor, constant: 20),
            title.trailingAnchor.constraint(equalTo: ordersPanel.trailingAnchor, constant: -20),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.trailingAnchor.constraint(equalTo: title.trailingAnchor),

            ordersScroll.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 16),
            ordersScroll.leadingAnchor.constraint(equalTo: ordersPanel.leadingAnchor, constant: 14),
            ordersScroll.trailingAnchor.constraint(equalTo: ordersPanel.trailingAnchor, constant: -14),
            ordersScroll.bottomAnchor.constraint(equalTo: ordersPanel.bottomAnchor, constant: -14)
        ])

        ordersStack.axis = .vertical
        ordersStack.spacing = 10
        ordersStack.translatesAutoresizingMaskIntoConstraints = false
        ordersScroll.addSubview(ordersStack)
        NSLayoutConstraint.activate([
            ordersStack.topAnchor.constraint(equalTo: ordersScroll.contentLayoutGuide.topAnchor),
            ordersStack.leadingAnchor.constraint(equalTo: ordersScroll.contentLayoutGuide.leadingAnchor),
            ordersStack.trailingAnchor.constraint(equalTo: ordersScroll.contentLayoutGuide.trailingAnchor),
            ordersStack.bottomAnchor.constraint(equalTo: ordersScroll.contentLayoutGuide.bottomAnchor),
            ordersStack.widthAnchor.constraint(equalTo: ordersScroll.frameLayoutGuide.widthAnchor)
        ])
    }

    private func setupArrivalOverlay() {
        arriveOverlay.translatesAutoresizingMaskIntoConstraints = false
        arriveOverlay.isHidden = true
        arriveOverlay.backgroundColor = UIColor(red: 0.035, green: 0.045, blue: 0.08, alpha: 0.98)
        view.addSubview(arriveOverlay)
        NSLayoutConstraint.activate([
            arriveOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            arriveOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arriveOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arriveOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        arriveCheckIcon.translatesAutoresizingMaskIntoConstraints = false
        arriveCheckIcon.image = UIImage(systemName: "checkmark.circle.fill")
        arriveCheckIcon.tintColor = .systemGreen
        arriveCheckIcon.contentMode = .scaleAspectFit
        arriveCheckIcon.layer.shadowColor = UIColor.systemGreen.cgColor
        arriveCheckIcon.layer.shadowOpacity = 0.55
        arriveCheckIcon.layer.shadowRadius = 18
        arriveCheckIcon.layer.shadowOffset = .zero
        arriveOverlay.addSubview(arriveCheckIcon)

        arriveTitle.translatesAutoresizingMaskIntoConstraints = false
        arriveTitle.font = roundedFont(26, .bold)
        arriveTitle.textColor = .white
        arriveTitle.textAlignment = .center
        arriveOverlay.addSubview(arriveTitle)

        arriveSubtitle.translatesAutoresizingMaskIntoConstraints = false
        arriveSubtitle.font = .systemFont(ofSize: 14, weight: .medium)
        arriveSubtitle.textColor = UIColor.white.withAlphaComponent(0.65)
        arriveSubtitle.numberOfLines = 3
        arriveSubtitle.textAlignment = .center
        arriveOverlay.addSubview(arriveSubtitle)

        qrImageView.translatesAutoresizingMaskIntoConstraints = false
        qrImageView.contentMode = .scaleAspectFit
        qrImageView.backgroundColor = .white
        qrImageView.layer.cornerRadius = 24
        qrImageView.clipsToBounds = true
        arriveOverlay.addSubview(qrImageView)

        arriveCloseButton.translatesAutoresizingMaskIntoConstraints = false
        arriveCloseButton.setTitle("HOÀN TẤT", for: .normal)
        arriveCloseButton.setTitleColor(.white, for: .normal)
        arriveCloseButton.titleLabel?.font = roundedFont(16, .bold)
        arriveCloseButton.layer.cornerRadius = 26
        let closeGradient = CAGradientLayer()
        closeGradient.name = "closeGradient"
        closeGradient.cornerRadius = 26
        closeGradient.colors = [pink.cgColor, purple.cgColor]
        closeGradient.startPoint = CGPoint(x: 0, y: 0.5)
        closeGradient.endPoint = CGPoint(x: 1, y: 0.5)
        arriveCloseButton.layer.insertSublayer(closeGradient, at: 0)
        arriveCloseButton.layer.shadowColor = pink.cgColor
        arriveCloseButton.layer.shadowOpacity = 0.4
        arriveCloseButton.layer.shadowRadius = 14
        arriveCloseButton.layer.shadowOffset = CGSize(width: 0, height: 6)
        arriveCloseButton.addTarget(self, action: #selector(closeArriveOverlay), for: .touchUpInside)
        arriveOverlay.addSubview(arriveCloseButton)

        NSLayoutConstraint.activate([
            arriveCheckIcon.centerXAnchor.constraint(equalTo: arriveOverlay.centerXAnchor),
            arriveCheckIcon.topAnchor.constraint(equalTo: arriveOverlay.safeAreaLayoutGuide.topAnchor, constant: 52),
            arriveCheckIcon.widthAnchor.constraint(equalToConstant: 88),
            arriveCheckIcon.heightAnchor.constraint(equalToConstant: 88),

            arriveTitle.topAnchor.constraint(equalTo: arriveCheckIcon.bottomAnchor, constant: 16),
            arriveTitle.leadingAnchor.constraint(equalTo: arriveOverlay.leadingAnchor, constant: 20),
            arriveTitle.trailingAnchor.constraint(equalTo: arriveOverlay.trailingAnchor, constant: -20),

            arriveSubtitle.topAnchor.constraint(equalTo: arriveTitle.bottomAnchor, constant: 10),
            arriveSubtitle.leadingAnchor.constraint(equalTo: arriveOverlay.leadingAnchor, constant: 28),
            arriveSubtitle.trailingAnchor.constraint(equalTo: arriveOverlay.trailingAnchor, constant: -28),

            qrImageView.centerXAnchor.constraint(equalTo: arriveOverlay.centerXAnchor),
            qrImageView.topAnchor.constraint(equalTo: arriveSubtitle.bottomAnchor, constant: 26),
            qrImageView.widthAnchor.constraint(equalToConstant: 230),
            qrImageView.heightAnchor.constraint(equalToConstant: 230),

            arriveCloseButton.centerXAnchor.constraint(equalTo: arriveOverlay.centerXAnchor),
            arriveCloseButton.topAnchor.constraint(equalTo: qrImageView.bottomAnchor, constant: 26),
            arriveCloseButton.widthAnchor.constraint(equalToConstant: 180),
            arriveCloseButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    // MARK: - Styling helpers

    private func roundedFont(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }

    private func monoFont(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        .monospacedDigitSystemFont(ofSize: size, weight: weight)
    }

    private func applyGlass(to view: UIView, cornerRadius: CGFloat) {
        view.backgroundColor = panel
        view.layer.cornerRadius = cornerRadius
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.45
        view.layer.shadowRadius = 22
        view.layer.shadowOffset = CGSize(width: 0, height: 10)
    }

    private func stylePlainIconButton(_ button: UIButton, systemName: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = .white
        button.backgroundColor = .clear
    }

    private func styleMapControl(_ button: UIButton, systemName: String, title: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = softPanel
        button.layer.cornerRadius = 20
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        button.tintColor = .white
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.setTitle("\n\(title)", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 10, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.contentVerticalAlignment = .center
    }

    private func styleGradientButton(_ button: UIButton, title: String, symbol: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("  \(title)", for: .normal)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = .white
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = roundedFont(17, .bold)
        button.layer.cornerRadius = 20
        let gradient = CAGradientLayer()
        gradient.name = "startGradient"
        gradient.cornerRadius = 20
        gradient.colors = [pink.cgColor, purple.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        button.layer.insertSublayer(gradient, at: 0)
        button.layer.shadowColor = pink.cgColor
        button.layer.shadowOpacity = 0.4
        button.layer.shadowRadius = 14
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
    }

    private func styleStopButton() {
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.setTitle("■  DỪNG", for: .normal)
        stopButton.setTitleColor(.white, for: .normal)
        stopButton.titleLabel?.font = roundedFont(12, .bold)
        stopButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        stopButton.layer.cornerRadius = 18
        stopButton.layer.shadowColor = UIColor.systemRed.cgColor
        stopButton.layer.shadowOpacity = 0.35
        stopButton.layer.shadowRadius = 8
        stopButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
    }

    // MARK: - Destination rows

    private func makeDestinationRow() -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.backgroundColor = rowSurface
        row.layer.cornerRadius = 18
        row.layer.borderWidth = 1
        row.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        row.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let index = UILabel()
        index.translatesAutoresizingMaskIntoConstraints = false
        index.text = "\(destinationFields.count + 1)"
        index.textAlignment = .center
        index.font = roundedFont(13, .bold)
        index.textColor = .white
        index.backgroundColor = pink
        index.layer.cornerRadius = 10
        index.clipsToBounds = true
        row.addSubview(index)

        let pin = UIImageView(image: UIImage(systemName: "mappin.fill"))
        pin.translatesAutoresizingMaskIntoConstraints = false
        pin.tintColor = pink
        pin.contentMode = .scaleAspectFit
        row.addSubview(pin)

        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.textColor = .white
        field.font = roundedFont(15, .medium)
        field.attributedPlaceholder = NSAttributedString(string: "Nhập điểm đến...", attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.40)])
        field.returnKeyType = .go
        field.delegate = self
        field.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        row.addSubview(field)

        let remove = UIButton(type: .system)
        remove.translatesAutoresizingMaskIntoConstraints = false
        remove.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        remove.tintColor = UIColor.white.withAlphaComponent(0.40)
        remove.addTarget(self, action: #selector(removeDestTapped(_:)), for: .touchUpInside)
        remove.tag = destinationFields.count
        row.addSubview(remove)

        NSLayoutConstraint.activate([
            index.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            index.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            index.widthAnchor.constraint(equalToConstant: 30),
            index.heightAnchor.constraint(equalToConstant: 30),

            pin.leadingAnchor.constraint(equalTo: index.trailingAnchor, constant: 10),
            pin.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            pin.widthAnchor.constraint(equalToConstant: 16),
            pin.heightAnchor.constraint(equalToConstant: 20),

            field.leadingAnchor.constraint(equalTo: pin.trailingAnchor, constant: 8),
            field.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            field.trailingAnchor.constraint(equalTo: remove.leadingAnchor, constant: -8),

            remove.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            remove.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            remove.widthAnchor.constraint(equalToConstant: 24),
            remove.heightAnchor.constraint(equalToConstant: 24)
        ])

        destinationFields.append(field)
        destinationCoords.append(nil)
        stopCompleted.append(false)
        return row
    }

    private func addDestinationRow(focus: Bool = true) {
        guard destinationFields.count < 5 else {
            statusLabel.text = "Tối đa 5 điểm đến"
            return
        }
        let row = makeDestinationRow()
        destinationStack.addArrangedSubview(row)
        updateRemoveButtons()
        if focus { destinationFields.last?.becomeFirstResponder() }
    }

    private func updateRemoveButtons() {
        let show = destinationFields.count > 1
        for row in destinationStack.arrangedSubviews {
            row.subviews.compactMap { $0 as? UIButton }.first?.isHidden = !show
        }
        for (i, row) in destinationStack.arrangedSubviews.enumerated() {
            if let label = row.subviews.compactMap({ $0 as? UILabel }).first {
                label.text = stopCompleted.indices.contains(i) && stopCompleted[i] ? "✓" : "\(i + 1)"
                label.backgroundColor = stopCompleted.indices.contains(i) && stopCompleted[i] ? .systemGreen : pink
            }
            if let button = row.subviews.compactMap({ $0 as? UIButton }).first { button.tag = i }
        }
    }

    private func resetStopUI() {
        for i in 0..<stopCompleted.count { stopCompleted[i] = false }
        updateRemoveButtons()
        for row in destinationStack.arrangedSubviews {
            if let field = row.subviews.compactMap({ $0 as? UITextField }).first {
                field.isEnabled = true
                field.textColor = .white
            }
        }
    }

    private func markStopCompletedUI(at index: Int) {
        guard index < destinationStack.arrangedSubviews.count else { return }
        let row = destinationStack.arrangedSubviews[index]
        if let label = row.subviews.compactMap({ $0 as? UILabel }).first {
            label.text = "✓"
            label.backgroundColor = .systemGreen
        }
        if let field = row.subviews.compactMap({ $0 as? UITextField }).first {
            field.isEnabled = false
            field.textColor = UIColor.white.withAlphaComponent(0.45)
        }
    }

    // MARK: - Services

    private func setupLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestAlwaysAuthorization()
    }

    private func setupBLE() {
        ble.onStatusChange = { [weak self] text in
            DispatchQueue.main.async {
                self?.statusLabel.text = text
                self?.connectionLabel.text = text.contains("Đã kết nối") ? "Đã kết nối" : "Đang kết nối"
            }
        }
        ble.onConnectedChange = { [weak self] connected in
            DispatchQueue.main.async {
                self?.connectionDot.backgroundColor = connected ? .systemGreen : .systemRed
                self?.connectionLabel.text = connected ? "Đã kết nối" : "Mất kết nối"
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
        let alert = UIAlertController(title: "Mã QR thanh toán", message: "Dán chuỗi VietQR. Khi hoàn thành điểm đến, mã QR sẽ hiện trên màn hình.", preferredStyle: .alert)
        alert.addTextField { field in
            field.text = self.qrString
            field.placeholder = "000201..."
            field.keyboardType = .asciiCapable
        }
        alert.addAction(UIAlertAction(title: "Lưu", style: .default) { [weak self] _ in
            let value = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self?.qrString = value
            self?.statusLabel.text = value.isEmpty ? "Đã xóa mã QR" : "Đã lưu mã QR ✓"
        })
        alert.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func addDestTapped() { addDestinationRow() }

    @objc private func removeDestTapped(_ sender: UIButton) {
        let idx = sender.tag
        guard idx < destinationFields.count, destinationFields.count > 1 else { return }
        let row = destinationStack.arrangedSubviews[idx]
        destinationStack.removeArrangedSubview(row)
        row.removeFromSuperview()
        destinationFields.remove(at: idx)
        destinationCoords.remove(at: idx)
        stopCompleted.remove(at: idx)
        updateRemoveButtons()
    }

    @objc private func textChanged(_ sender: UITextField) {
        if let idx = destinationFields.firstIndex(of: sender) { activeFieldIndex = idx }
        let text = sender.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty {
            suggestionTable.isHidden = true
            suggestions = []
            return
        }
        completer.queryFragment = text
    }

    @objc private func goTapped() {
        view.endEditing(true)
        suggestionTable.isHidden = true

        let hasAny = destinationFields.contains { !($0.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty }
        guard hasAny else {
            statusLabel.text = "Nhập ít nhất 1 điểm đến"
            return
        }

        if firstIncompleteStop() == nil {
            resetStopUI()
        }

        var coords = Array<CLLocationCoordinate2D?>(repeating: nil, count: destinationFields.count)
        var needGeocode: [(String, Int)] = []
        for (i, field) in destinationFields.enumerated() {
            let text = field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty { continue }
            if let c = destinationCoords[i] { coords[i] = c } else { needGeocode.append((text, i)) }
        }

        if needGeocode.isEmpty {
            startFirstIncomplete(coords)
            return
        }

        statusLabel.text = "Đang tìm địa chỉ..."
        let group = DispatchGroup()
        var results: [Int: CLLocationCoordinate2D] = [:]
        let lock = NSLock()
        for (text, i) in needGeocode {
            group.enter()
            CLGeocoder().geocodeAddressString(text) { placemarks, _ in
                if let coordinate = placemarks?.first?.location?.coordinate {
                    lock.lock(); results[i] = coordinate; lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            for (text, i) in needGeocode {
                guard let coordinate = results[i] else {
                    self.statusLabel.text = "Không tìm thấy: \(text)"
                    return
                }
                coords[i] = coordinate
                self.destinationCoords[i] = coordinate
            }
            self.startFirstIncomplete(coords)
        }
    }

    @objc private func stopTapped() {
        isNavigating = false
        steps.removeAll()
        pendingDestination = nil
        navigationCard.isHidden = true
        summaryCard.isHidden = true
        destinationCard.isHidden = false
        statusLabel.isHidden = false
        suggestionTable.isHidden = true
        if let polyline = routePolyline {
            mapView.removeOverlay(polyline)
            routePolyline = nil
        }
        ble.send(json: [
            "speed": 0, "distance": 0,
            "next_road": "", "next_road_sub": "",
            "eta": "", "ete": "", "total_distance": "",
            "maneuver": "straight"
        ])
        statusLabel.text = "Đã dừng chuyến — chưa ghi vào Đơn hàng"
    }

    @objc private func layersTapped() {
        let alert = UIAlertController(title: "Lớp bản đồ", message: "Chọn kiểu hiển thị bản đồ", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Tiêu chuẩn", style: .default) { _ in self.mapView.mapType = .standard })
        alert.addAction(UIAlertAction(title: "Vệ tinh", style: .default) { _ in self.mapView.mapType = .satellite })
        alert.addAction(UIAlertAction(title: "Kết hợp", style: .default) { _ in self.mapView.mapType = .hybrid })
        alert.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        if let pop = alert.popoverPresentationController { pop.sourceView = layersButton; pop.sourceRect = layersButton.bounds }
        present(alert, animated: true)
    }

    @objc private func locationTapped() {
        guard let coordinate = locationManager.location?.coordinate else { return }
        mapView.setCenter(coordinate, animated: true)
        mapView.setUserTrackingMode(.follow, animated: true)
    }

    @objc private func headingTapped() {
        mapView.setUserTrackingMode(.followWithHeading, animated: true)
    }

    @objc private func zoomInTapped() { zoomMap(factor: 0.55) }
    @objc private func zoomOutTapped() { zoomMap(factor: 1.8) }

    private func zoomMap(factor: Double) {
        var region = mapView.region
        region.span.latitudeDelta *= factor
        region.span.longitudeDelta *= factor
        mapView.setRegion(region, animated: true)
    }

    @objc private func mapTabTapped() {
        showingOrders = false
        updateBottomTabs()
    }

    @objc private func ordersTabTapped() {
        showingOrders = true
        view.endEditing(true)
        suggestionTable.isHidden = true
        rebuildOrdersPanel()
        updateBottomTabs()
    }

    @objc private func closeArriveOverlay() {
        arriveOverlay.isHidden = true
        destinationCard.isHidden = false
        statusLabel.isHidden = false
        if let idx = firstIncompleteStop() {
            statusLabel.text = "Đã hoàn thành điểm \(currentStopIndex + 1) — chọn điểm \(idx + 1) và bấm BẮT ĐẦU"
        } else {
            statusLabel.text = "🎉 Đã hoàn thành tất cả điểm đến"
        }
    }

    // MARK: - Navigation

    private func firstIncompleteStop() -> Int? {
        for (i, field) in destinationFields.enumerated() {
            let text = field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty && !stopCompleted[i] { return i }
        }
        return nil
    }

    private func startFirstIncomplete(_ coords: [CLLocationCoordinate2D?]) {
        guard let idx = firstIncompleteStop() else {
            statusLabel.text = "Đã hoàn thành tất cả điểm đến"
            return
        }
        guard idx < coords.count, let destination = coords[idx] else {
            statusLabel.text = "Điểm \(idx + 1) chưa có tọa độ"
            return
        }

        currentStopIndex = idx
        totalStopsWithText = destinationFields.filter { !($0.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty }.count
        isNavigating = true
        showingOrders = false
        destinationCard.isHidden = true
        statusLabel.isHidden = true
        updateBottomTabs()
        navigationCard.isHidden = false
        arriveOverlay.isHidden = true
        distanceValue.text = "—"
        etaValue.text = "—"
        destinationValue.text = "\(currentStopIndex + 1)/\(max(totalStopsWithText, 1))"

        guard let origin = locationManager.location?.coordinate else {
            pendingDestination = destination
            statusLabel.text = "Đang chờ vị trí GPS..."
            return
        }
        fetchLeg(from: origin, to: destination)
    }

    private func fetchLeg(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        pendingDestination = nil
        statusLabel.text = "Đang tính tuyến..."
        nav.fetchRoute(from: origin, to: destination) { [weak self] steps, _, totalDistanceText, coordinates in
            guard let self else { return }
            guard !steps.isEmpty else {
                self.statusLabel.text = "Không có tuyến đường"
                self.navigationCard.isHidden = true
                return
            }
            self.steps = steps
            self.currentStepIndex = 0
            self.totalDistanceText = totalDistanceText
            self.routeCoordinates = coordinates
            self.drawRoute(coordinates: coordinates)
            self.distanceValue.text = totalDistanceText
            self.statusLabel.text = "Đang dẫn đường tới điểm \(self.currentStopIndex + 1)/\(max(self.totalStopsWithText, 1))"
        }
    }

    private func drawRoute(coordinates: [CLLocationCoordinate2D]) {
        if let polyline = routePolyline { mapView.removeOverlay(polyline) }
        guard coordinates.count > 1 else { return }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        routePolyline = polyline
        mapView.setVisibleMapRect(polyline.boundingMapRect,
                                  edgePadding: UIEdgeInsets(top: 150, left: 70, bottom: 260, right: 70),
                                  animated: true)
    }

    private func distanceMeters(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
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
        case "left": return "↰"
        case "right": return "↱"
        case "uturn": return "↶"
        case "arrive": return "✓"
        default: return "↑"
        }
    }

    private func roadNameForHUD(stepIndex: Int, distance: Double) -> String {
        guard stepIndex >= 0, stepIndex < steps.count else { return "" }
        let step = steps[stepIndex]
        if distance <= turnPreviewDistanceM, step.maneuver != "straight", step.maneuver != "arrive" {
            return step.roadName
        }
        if stepIndex > 0 {
            let previous = steps[stepIndex - 1].roadName
            if !previous.isEmpty { return previous }
        }
        return step.roadName
    }

    private func displayManeuverForHUD(step: RouteStep, distance: Double) -> String {
        if step.maneuver == "arrive" || step.maneuver == "straight" { return step.maneuver }
        return distance <= turnPreviewDistanceM ? step.maneuver : "straight"
    }

    private func nextManeuversList() -> String {
        let start = currentStepIndex + 1
        let end = min(start + 4, steps.count)
        guard start < end else { return "" }
        return (start..<end).map { steps[$0].maneuver }.joined(separator: ",")
    }

    // MARK: - Location update

    private func updateNavigation(location: CLLocation) {
        guard isNavigating, !steps.isEmpty else { return }

        var bestIndex = currentStepIndex
        var bestDistance = Double.greatestFiniteMagnitude
        for i in currentStepIndex..<steps.count {
            let end = CLLocationCoordinate2D(latitude: steps[i].endLat, longitude: steps[i].endLng)
            let distance = distanceMeters(from: location.coordinate, to: end)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = i
            }
        }
        if bestDistance < 30, bestIndex < steps.count - 1 { bestIndex += 1 }
        currentStepIndex = bestIndex
        let step = steps[currentStepIndex]

        var remainingSec = 0
        for i in currentStepIndex..<steps.count { remainingSec += steps[i].durationValue }
        let eta = Date().addingTimeInterval(TimeInterval(remainingSec))
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let displayManeuver = displayManeuverForHUD(step: step, distance: bestDistance)
        navArrow.text = arrowSymbol(for: displayManeuver)
        navArrow.textColor = displayManeuver == "arrive" ? .systemGreen : pink
        navDistance.text = bestDistance >= 1000 ? String(format: "%.1f km", bestDistance / 1000) : "\(Int(bestDistance)) m"
        navRoad.text = roadNameForHUD(stepIndex: currentStepIndex, distance: bestDistance).isEmpty ? "Đang dẫn đường" : roadNameForHUD(stepIndex: currentStepIndex, distance: bestDistance)
        navEta.text = "ETA \(formatter.string(from: eta)) · \(Self.formatDuration(remainingSec))"
        etaValue.text = formatter.string(from: eta)

        if let total = parseMeters(totalDistanceText) {
            let progress = max(0, min(1, 1 - bestDistance / max(total, 1)))
            progressView.progress = Float(progress)
        }

        let isArrive = step.maneuver == "arrive" || currentStepIndex == steps.count - 1
        if isArrive && bestDistance < 40 {
            let destinationName = destinationFields[currentStopIndex].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Điểm đến"
            ble.send(json: [
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
            ])
            saveCompletedTrip(destination: destinationName, duration: Self.formatDuration(remainingSec))
            showArriveOverlay()
            return
        }

        let speed = max(0, Int(location.speed * 3.6))
        let now = Date().timeIntervalSince1970
        if now - lastSendTime >= 1.0 {
            lastSendTime = now
            let roadForHUD = roadNameForHUD(stepIndex: currentStepIndex, distance: bestDistance)
            ble.send(json: [
                "speed": speed,
                "distance": Int(bestDistance),
                "next_road": roadForHUD,
                "next_road_sub": step.instruction,
                "current_road": currentStepIndex > 0 ? steps[currentStepIndex - 1].roadName : roadForHUD,
                "turn_road": step.roadName,
                "turn_text": step.instruction,
                "eta": formatter.string(from: eta),
                "ete": Self.formatDuration(remainingSec),
                "total_distance": totalDistanceText,
                "maneuver": displayManeuver,
                "actual_maneuver": step.maneuver,
                "next": nextManeuversList()
            ])
        }
    }

    private func parseMeters(_ text: String) -> Double? {
        let clean = text.replacingOccurrences(of: ",", with: ".")
        if clean.contains("km"), let number = Double(clean.replacingOccurrences(of: " km", with: "").replacingOccurrences(of: "km", with: "")) {
            return number * 1000
        }
        if clean.contains("m"), let number = Double(clean.replacingOccurrences(of: " m", with: "").replacingOccurrences(of: "m", with: "")) {
            return number
        }
        return nil
    }

    // MARK: - Arrival / QR

    private func makeQRImage(from text: String) -> UIImage? {
        guard !text.isEmpty, let data = text.data(using: .utf8), let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scale = output.extent.width > 0 ? 520 / output.extent.width : 10
        return UIImage(ciImage: output.transformed(by: CGAffineTransform(scaleX: scale, y: scale)))
    }

    private func showArriveOverlay() {
        navigationCard.isHidden = true
        isNavigating = false
        if currentStopIndex < stopCompleted.count { stopCompleted[currentStopIndex] = true }
        markStopCompletedUI(at: currentStopIndex)
        updateRemoveButtons()

        let orderNo = currentStopIndex + 1
        if let qr = makeQRImage(from: qrString) {
            qrImageView.image = qr
            qrImageView.isHidden = false
        } else {
            qrImageView.image = nil
            qrImageView.isHidden = true
        }

        arriveTitle.text = "✓  HOÀN THÀNH ĐIỂM \(orderNo)"
        if qrString.isEmpty {
            arriveSubtitle.text = "Đã lưu quãng đường. Bạn có thể thêm mã QR thanh toán ở nút QR."
        } else if let next = firstIncompleteStop() {
            arriveSubtitle.text = "Mã QR thanh toán đang hiển thị. Sau khi đóng, chọn điểm \(next + 1) để đi tiếp."
        } else {
            arriveSubtitle.text = "Mã QR thanh toán đang hiển thị. Bạn đã hoàn thành tất cả điểm đến."
        }
        arriveOverlay.isHidden = false
        rebuildOrdersPanel()
    }

    private func saveCompletedTrip(destination: String, duration: String) {
        let trip = CompletedTrip(destination: destination,
                                 distance: totalDistanceText,
                                 duration: duration,
                                 completedAt: Date(),
                                 stopNumber: currentStopIndex + 1)
        var history = completedTrips
        history.insert(trip, at: 0)
        completedTrips = history
    }

    // MARK: - Orders tab

    private func updateBottomTabs() {
        ordersPanel.isHidden = !showingOrders
        let active = pink
        mapTabIcon.tintColor = showingOrders ? UIColor.white.withAlphaComponent(0.45) : active
        mapTabLabel.textColor = showingOrders ? UIColor.white.withAlphaComponent(0.55) : active
        ordersTabIcon.tintColor = showingOrders ? active : UIColor.white.withAlphaComponent(0.45)
        ordersTabLabel.textColor = showingOrders ? active : UIColor.white.withAlphaComponent(0.55)

        mapTabIcon.image = UIImage(systemName: showingOrders ? "map" : "map.fill")
        ordersTabIcon.image = UIImage(systemName: showingOrders ? "list.clipboard.fill" : "list.clipboard")

        destinationCard.isHidden = showingOrders || isNavigating
        statusLabel.isHidden = showingOrders || isNavigating
        suggestionTable.isHidden = true
        layersButton.isHidden = showingOrders
        locationButton.isHidden = showingOrders
        headingButton.isHidden = showingOrders
        zoomStack.isHidden = showingOrders
        summaryCard.isHidden = showingOrders || !isNavigating
        navigationCard.isHidden = showingOrders || !isNavigating
    }

    private func rebuildOrdersPanel() {
        ordersStack.arrangedSubviews.forEach {
            ordersStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let trips = completedTrips
        if trips.isEmpty {
            let empty = UILabel()
            empty.text = "Chưa có chuyến hoàn thành.\nKhi một điểm đến hoàn tất, quãng đường sẽ được lưu tại đây."
            empty.font = roundedFont(15, .medium)
            empty.textColor = UIColor.white.withAlphaComponent(0.55)
            empty.textAlignment = .center
            empty.numberOfLines = 3
            empty.heightAnchor.constraint(equalToConstant: 120).isActive = true
            ordersStack.addArrangedSubview(empty)
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy · HH:mm"
        for trip in trips {
            let card = UIView()
            card.backgroundColor = UIColor.white.withAlphaComponent(0.035)
            card.layer.cornerRadius = 20
            card.layer.borderWidth = 1
            card.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
            card.heightAnchor.constraint(equalToConstant: 88).isActive = true

            let bubble = UIView()
            bubble.translatesAutoresizingMaskIntoConstraints = false
            bubble.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
            bubble.layer.cornerRadius = 13
            card.addSubview(bubble)

            let icon = UIImageView(image: UIImage(systemName: "checkmark"))
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.tintColor = .systemGreen
            icon.contentMode = .scaleAspectFit
            bubble.addSubview(icon)

            let destination = UILabel()
            destination.translatesAutoresizingMaskIntoConstraints = false
            destination.text = "Điểm \(trip.stopNumber) · \(trip.destination)"
            destination.font = roundedFont(14, .bold)
            destination.textColor = .white
            destination.numberOfLines = 1
            destination.lineBreakMode = .byTruncatingTail
            card.addSubview(destination)

            let meta = UILabel()
            meta.translatesAutoresizingMaskIntoConstraints = false
            meta.text = "\(trip.distance) · \(trip.duration)\n\(formatter.string(from: trip.completedAt))"
            meta.font = .systemFont(ofSize: 11, weight: .medium)
            meta.textColor = UIColor.white.withAlphaComponent(0.55)
            meta.numberOfLines = 2
            card.addSubview(meta)

            NSLayoutConstraint.activate([
                bubble.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
                bubble.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
                bubble.widthAnchor.constraint(equalToConstant: 34),
                bubble.heightAnchor.constraint(equalToConstant: 34),
                icon.centerXAnchor.constraint(equalTo: bubble.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: bubble.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 17),
                icon.heightAnchor.constraint(equalToConstant: 17),
                destination.leadingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: 12),
                destination.topAnchor.constraint(equalTo: card.topAnchor, constant: 13),
                destination.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
                meta.leadingAnchor.constraint(equalTo: destination.leadingAnchor),
                meta.topAnchor.constraint(equalTo: destination.bottomAnchor, constant: 4),
                meta.trailingAnchor.constraint(equalTo: destination.trailingAnchor)
            ])
            ordersStack.addArrangedSubview(card)
        }
    }
}

// MARK: - Map delegate
extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = pink
            renderer.lineWidth = 6
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}

// MARK: - Search suggestions
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

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { suggestions.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let item = suggestions[indexPath.row]
        cell.backgroundColor = .clear
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.textColor = UIColor.white.withAlphaComponent(0.50)
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.subtitle
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let completion = suggestions[indexPath.row]
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { [weak self] response, _ in
            guard let self, let item = response?.mapItems.first, self.activeFieldIndex < self.destinationFields.count else { return }
            self.destinationFields[self.activeFieldIndex].text = completion.title
            self.destinationCoords[self.activeFieldIndex] = item.placemark.coordinate
            self.suggestionTable.isHidden = true
            self.destinationFields[self.activeFieldIndex].resignFirstResponder()
        }
    }
}

// MARK: - Location
extension ViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            statusLabel.text = "Bật quyền vị trí trong Settings để dẫn đường"
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        if let pending = pendingDestination {
            fetchLeg(from: location.coordinate, to: pending)
            return
        }
        if !isNavigating && !showingOrders {
            if mapView.userTrackingMode == .none { mapView.setCenter(location.coordinate, animated: true) }
            return
        }
        updateNavigation(location: location)
    }
}

// MARK: - Text field
extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let idx = destinationFields.firstIndex(of: textField), idx < destinationFields.count - 1 {
            destinationFields[idx + 1].becomeFirstResponder()
        } else {
            goTapped()
        }
        return true
    }
}
