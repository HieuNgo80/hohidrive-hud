import UIKit
import MapKit
import CoreLocation
import CoreImage

final class ViewController: UIViewController {

    // MARK: - Theme
    private let pink = UIColor(red: 0.98, green: 0.28, blue: 0.68, alpha: 1)
    private let purple = UIColor(red: 0.39, green: 0.25, blue: 0.95, alpha: 1)
    private let panel = UIColor(red: 0.045, green: 0.065, blue: 0.10, alpha: 0.94)
    private let softPanel = UIColor(red: 0.08, green: 0.10, blue: 0.15, alpha: 0.92)

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
        setupNavigationCard()
        setupSummaryCard()
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
        header.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        view.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 108)
        ])

        logoLabel.translatesAutoresizingMaskIntoConstraints = false
        logoLabel.text = "H"
        logoLabel.textAlignment = .center
        logoLabel.font = .systemFont(ofSize: 27, weight: .black)
        logoLabel.textColor = .white
        logoLabel.backgroundColor = pink
        logoLabel.layer.cornerRadius = 13
        logoLabel.clipsToBounds = true
        header.addSubview(logoLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "HOHI DRIVE"
        titleLabel.font = .systemFont(ofSize: 23, weight: .bold)
        titleLabel.textColor = .white
        header.addSubview(titleLabel)

        connectionDot.translatesAutoresizingMaskIntoConstraints = false
        connectionDot.backgroundColor = .systemGreen
        connectionDot.layer.cornerRadius = 5
        header.addSubview(connectionDot)

        connectionLabel.translatesAutoresizingMaskIntoConstraints = false
        connectionLabel.text = "Đã kết nối"
        connectionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        connectionLabel.textColor = .lightGray
        header.addSubview(connectionLabel)

        styleIconButton(qrButton, systemName: "qrcode", title: "QR", filled: true)
        qrButton.addTarget(self, action: #selector(qrTapped), for: .touchUpInside)
        header.addSubview(qrButton)

        NSLayoutConstraint.activate([
            logoLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 22),
            logoLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -20),
            logoLabel.widthAnchor.constraint(equalToConstant: 52),
            logoLabel.heightAnchor.constraint(equalToConstant: 52),

            titleLabel.leadingAnchor.constraint(equalTo: logoLabel.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: logoLabel.topAnchor, constant: 1),

            connectionDot.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            connectionDot.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 7),
            connectionDot.widthAnchor.constraint(equalToConstant: 10),
            connectionDot.heightAnchor.constraint(equalToConstant: 10),

            connectionLabel.leadingAnchor.constraint(equalTo: connectionDot.trailingAnchor, constant: 6),
            connectionLabel.centerYAnchor.constraint(equalTo: connectionDot.centerYAnchor),

            qrButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -18),
            qrButton.centerYAnchor.constraint(equalTo: logoLabel.centerYAnchor),
            qrButton.widthAnchor.constraint(equalToConstant: 72),
            qrButton.heightAnchor.constraint(equalToConstant: 58)
        ])
    }

    private func setupDestinationCard() {
        destinationCard.translatesAutoresizingMaskIntoConstraints = false
        destinationCard.backgroundColor = panel
        destinationCard.layer.cornerRadius = 24
        destinationCard.layer.borderWidth = 1
        destinationCard.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        view.addSubview(destinationCard)
        NSLayoutConstraint.activate([
            destinationCard.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            destinationCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            destinationCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18)
        ])

        destinationTitle.translatesAutoresizingMaskIntoConstraints = false
        destinationTitle.text = "ĐIỂM ĐẾN"
        destinationTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        destinationTitle.textColor = UIColor.white.withAlphaComponent(0.72)
        destinationCard.addSubview(destinationTitle)

        destinationStack.translatesAutoresizingMaskIntoConstraints = false
        destinationStack.axis = .vertical
        destinationStack.spacing = 8
        destinationCard.addSubview(destinationStack)

        addDestinationButton.translatesAutoresizingMaskIntoConstraints = false
        addDestinationButton.setTitle("＋  Thêm điểm đến", for: .normal)
        addDestinationButton.setTitleColor(pink, for: .normal)
        addDestinationButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
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
            startButton.heightAnchor.constraint(equalToConstant: 58),
            startButton.bottomAnchor.constraint(equalTo: destinationCard.bottomAnchor, constant: -16)
        ])

        suggestionTable.translatesAutoresizingMaskIntoConstraints = false
        suggestionTable.isHidden = true
        suggestionTable.backgroundColor = UIColor(red: 0.055, green: 0.07, blue: 0.11, alpha: 0.98)
        suggestionTable.separatorColor = UIColor.white.withAlphaComponent(0.08)
        suggestionTable.layer.cornerRadius = 16
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
        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.70)
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
            layersButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            layersButton.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -262),
            layersButton.widthAnchor.constraint(equalToConstant: 86),
            layersButton.heightAnchor.constraint(equalToConstant: 72),

            locationButton.leadingAnchor.constraint(equalTo: layersButton.leadingAnchor),
            locationButton.topAnchor.constraint(equalTo: layersButton.bottomAnchor, constant: 8),
            locationButton.widthAnchor.constraint(equalTo: layersButton.widthAnchor),
            locationButton.heightAnchor.constraint(equalTo: layersButton.heightAnchor),

            headingButton.leadingAnchor.constraint(equalTo: layersButton.leadingAnchor),
            headingButton.topAnchor.constraint(equalTo: locationButton.bottomAnchor, constant: 8),
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
            zoomStack.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -160),
            zoomStack.widthAnchor.constraint(equalToConstant: 54),
            zoomStack.heightAnchor.constraint(equalToConstant: 108)
        ])
    }

    private func setupNavigationCard() {
        navigationCard.translatesAutoresizingMaskIntoConstraints = false
        navigationCard.isHidden = true
        navigationCard.backgroundColor = panel
        navigationCard.layer.cornerRadius = 22
        navigationCard.layer.borderWidth = 1
        navigationCard.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        view.addSubview(navigationCard)
        NSLayoutConstraint.activate([
            navigationCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            navigationCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            navigationCard.bottomAnchor.constraint(equalTo: summaryCard.topAnchor, constant: -8),
            navigationCard.heightAnchor.constraint(equalToConstant: 108)
        ])

        navHandle.translatesAutoresizingMaskIntoConstraints = false
        navHandle.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        navHandle.layer.cornerRadius = 3
        navigationCard.addSubview(navHandle)

        navArrow.translatesAutoresizingMaskIntoConstraints = false
        navArrow.text = "↑"
        navArrow.font = .systemFont(ofSize: 46, weight: .bold)
        navArrow.textColor = pink
        navArrow.textAlignment = .center
        navigationCard.addSubview(navArrow)

        navDistance.translatesAutoresizingMaskIntoConstraints = false
        navDistance.text = "— m"
        navDistance.font = .monospacedDigitSystemFont(ofSize: 28, weight: .bold)
        navDistance.textColor = .white
        navDistance.textAlignment = .right
        navigationCard.addSubview(navDistance)

        navRoad.translatesAutoresizingMaskIntoConstraints = false
        navRoad.text = "Đang dẫn đường"
        navRoad.font = .systemFont(ofSize: 14, weight: .semibold)
        navRoad.textColor = .white
        navRoad.numberOfLines = 1
        navRoad.lineBreakMode = .byTruncatingTail
        navigationCard.addSubview(navRoad)

        navEta.translatesAutoresizingMaskIntoConstraints = false
        navEta.font = .systemFont(ofSize: 11, weight: .medium)
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
            navHandle.topAnchor.constraint(equalTo: navigationCard.topAnchor, constant: 8),
            navHandle.widthAnchor.constraint(equalToConstant: 34),
            navHandle.heightAnchor.constraint(equalToConstant: 5),

            navArrow.leadingAnchor.constraint(equalTo: navigationCard.leadingAnchor, constant: 12),
            navArrow.topAnchor.constraint(equalTo: navigationCard.topAnchor, constant: 17),
            navArrow.widthAnchor.constraint(equalToConstant: 58),
            navArrow.heightAnchor.constraint(equalToConstant: 52),

            navDistance.trailingAnchor.constraint(equalTo: navigationCard.trailingAnchor, constant: -18),
            navDistance.topAnchor.constraint(equalTo: navigationCard.topAnchor, constant: 22),
            navDistance.widthAnchor.constraint(equalToConstant: 125),
            navDistance.heightAnchor.constraint(equalToConstant: 40),

            navRoad.leadingAnchor.constraint(equalTo: navArrow.trailingAnchor, constant: 5),
            navRoad.trailingAnchor.constraint(equalTo: navDistance.leadingAnchor, constant: -10),
            navRoad.topAnchor.constraint(equalTo: navigationCard.topAnchor, constant: 27),

            navEta.leadingAnchor.constraint(equalTo: navRoad.leadingAnchor),
            navEta.trailingAnchor.constraint(equalTo: navRoad.trailingAnchor),
            navEta.topAnchor.constraint(equalTo: navRoad.bottomAnchor, constant: 3),

            progressView.leadingAnchor.constraint(equalTo: navigationCard.leadingAnchor, constant: 18),
            progressView.trailingAnchor.constraint(equalTo: navigationCard.trailingAnchor, constant: -18),
            progressView.bottomAnchor.constraint(equalTo: navigationCard.bottomAnchor, constant: -12),

            stopButton.trailingAnchor.constraint(equalTo: navigationCard.trailingAnchor, constant: -14),
            stopButton.bottomAnchor.constraint(equalTo: navigationCard.bottomAnchor, constant: -27),
            stopButton.widthAnchor.constraint(equalToConstant: 92),
            stopButton.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    private func setupSummaryCard() {
        summaryCard.translatesAutoresizingMaskIntoConstraints = false
        summaryCard.backgroundColor = panel
        summaryCard.layer.cornerRadius = 24
        summaryCard.layer.borderWidth = 1
        summaryCard.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        view.addSubview(summaryCard)
        NSLayoutConstraint.activate([
            summaryCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            summaryCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            summaryCard.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8),
            summaryCard.heightAnchor.constraint(equalToConstant: 94)
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
        stack.spacing = 8
        summaryCard.addSubview(stack)

        for (value, caption, symbol, text) in columns {
            let card = UIView()
            card.backgroundColor = UIColor.white.withAlphaComponent(0.025)
            card.layer.cornerRadius = 16
            card.layer.borderWidth = 1
            card.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
            stack.addArrangedSubview(card)

            let icon = UIImageView(image: UIImage(systemName: symbol))
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.tintColor = pink
            icon.contentMode = .scaleAspectFit
            card.addSubview(icon)

            value.translatesAutoresizingMaskIntoConstraints = false
            value.text = "—"
            value.font = .systemFont(ofSize: 16, weight: .bold)
            value.textColor = .white
            card.addSubview(value)

            caption.translatesAutoresizingMaskIntoConstraints = false
            caption.text = text
            caption.font = .systemFont(ofSize: 9, weight: .medium)
            caption.textColor = UIColor.white.withAlphaComponent(0.58)
            card.addSubview(caption)

            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
                icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 25),
                icon.heightAnchor.constraint(equalToConstant: 25),
                caption.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
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
        bottomBar.backgroundColor = UIColor(red: 0.035, green: 0.05, blue: 0.08, alpha: 0.98)
        bottomBar.layer.borderWidth = 1
        bottomBar.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        view.addSubview(bottomBar)
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 88)
        ])

        setupTab(mapTabButton, icon: mapTabIcon, label: mapTabLabel, title: "Bản đồ", symbol: "map.fill", action: #selector(mapTabTapped))
        setupTab(ordersTabButton, icon: ordersTabIcon, label: ordersTabLabel, title: "Đơn hàng", symbol: "list.clipboard.fill", action: #selector(ordersTabTapped))

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        bottomBar.addSubview(divider)

        NSLayoutConstraint.activate([
            mapTabButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 12),
            mapTabButton.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 8),
            mapTabButton.bottomAnchor.constraint(equalTo: bottomBar.bottomAnchor, constant: -10),
            mapTabButton.widthAnchor.constraint(equalTo: bottomBar.widthAnchor, multiplier: 0.5, constant: -18),

            ordersTabButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -12),
            ordersTabButton.topAnchor.constraint(equalTo: mapTabButton.topAnchor),
            ordersTabButton.bottomAnchor.constraint(equalTo: mapTabButton.bottomAnchor),
            ordersTabButton.widthAnchor.constraint(equalTo: mapTabButton.widthAnchor),

            divider.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            divider.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalToConstant: 50)
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
        label.font = .systemFont(ofSize: 12, weight: .semibold)
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
        ordersPanel.backgroundColor = panel
        ordersPanel.layer.cornerRadius = 24
        ordersPanel.layer.borderWidth = 1
        ordersPanel.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        view.addSubview(ordersPanel)
        NSLayoutConstraint.activate([
            ordersPanel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            ordersPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            ordersPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            ordersPanel.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -12)
        ])

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "ĐƠN HÀNG / LỊCH SỬ CHUYẾN"
        title.font = .systemFont(ofSize: 18, weight: .bold)
        title.textColor = .white
        ordersPanel.addSubview(title)

        let subtitle = UILabel()
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.text = "Lưu các quãng đường đã hoàn thành — phần sản phẩm, số lượng và tiền sẽ phát triển sau."
        subtitle.font = .systemFont(ofSize: 12, weight: .medium)
        subtitle.textColor = UIColor.white.withAlphaComponent(0.55)
        subtitle.numberOfLines = 2
        ordersPanel.addSubview(subtitle)

        ordersScroll.translatesAutoresizingMaskIntoConstraints = false
        ordersPanel.addSubview(ordersScroll)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: ordersPanel.topAnchor, constant: 22),
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
        arriveOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.96)
        view.addSubview(arriveOverlay)
        NSLayoutConstraint.activate([
            arriveOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            arriveOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arriveOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arriveOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        arriveTitle.translatesAutoresizingMaskIntoConstraints = false
        arriveTitle.font = .systemFont(ofSize: 28, weight: .bold)
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
        qrImageView.layer.cornerRadius = 18
        qrImageView.clipsToBounds = true
        arriveOverlay.addSubview(qrImageView)

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("ĐÓNG", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        closeButton.backgroundColor = pink
        closeButton.layer.cornerRadius = 15
        closeButton.addTarget(self, action: #selector(closeArriveOverlay), for: .touchUpInside)
        arriveOverlay.addSubview(closeButton)

        NSLayoutConstraint.activate([
            arriveTitle.topAnchor.constraint(equalTo: arriveOverlay.safeAreaLayoutGuide.topAnchor, constant: 60),
            arriveTitle.leadingAnchor.constraint(equalTo: arriveOverlay.leadingAnchor, constant: 20),
            arriveTitle.trailingAnchor.constraint(equalTo: arriveOverlay.trailingAnchor, constant: -20),

            arriveSubtitle.topAnchor.constraint(equalTo: arriveTitle.bottomAnchor, constant: 10),
            arriveSubtitle.leadingAnchor.constraint(equalTo: arriveOverlay.leadingAnchor, constant: 28),
            arriveSubtitle.trailingAnchor.constraint(equalTo: arriveOverlay.trailingAnchor, constant: -28),

            qrImageView.centerXAnchor.constraint(equalTo: arriveOverlay.centerXAnchor),
            qrImageView.topAnchor.constraint(equalTo: arriveSubtitle.bottomAnchor, constant: 24),
            qrImageView.widthAnchor.constraint(equalToConstant: 250),
            qrImageView.heightAnchor.constraint(equalToConstant: 250),

            closeButton.centerXAnchor.constraint(equalTo: arriveOverlay.centerXAnchor),
            closeButton.topAnchor.constraint(equalTo: qrImageView.bottomAnchor, constant: 24),
            closeButton.widthAnchor.constraint(equalToConstant: 150),
            closeButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    // MARK: - Styling helpers

    private func styleIconButton(_ button: UIButton, systemName: String, title: String, filled: Bool) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .white
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.setTitle("  \(title)", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = filled ? UIColor(red: 0.45, green: 0.08, blue: 0.34, alpha: 0.92) : softPanel
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.layer.borderColor = pink.withAlphaComponent(0.45).cgColor
    }

    private func stylePlainIconButton(_ button: UIButton, systemName: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.clear
    }

    private func styleMapControl(_ button: UIButton, systemName: String, title: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = softPanel
        button.layer.cornerRadius = 17
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
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        button.layer.cornerRadius = 18
        button.clipsToBounds = true
        let gradient = CAGradientLayer()
        gradient.name = "startGradient"
        gradient.colors = [pink.cgColor, purple.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        button.layer.insertSublayer(gradient, at: 0)
    }

    private func styleStopButton() {
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.setTitle("■  STOP", for: .normal)
        stopButton.setTitleColor(.white, for: .normal)
        stopButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        stopButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.88)
        stopButton.layer.cornerRadius = 17
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
    }

    // MARK: - Destination rows

    private func makeDestinationRow() -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.backgroundColor = UIColor(red: 0.09, green: 0.11, blue: 0.17, alpha: 1)
        row.layer.cornerRadius = 15
        row.layer.borderWidth = 1
        row.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        row.heightAnchor.constraint(equalToConstant: 54).isActive = true

        let index = UILabel()
        index.translatesAutoresizingMaskIntoConstraints = false
        index.text = "\(destinationFields.count + 1)"
        index.textAlignment = .center
        index.font = .systemFont(ofSize: 14, weight: .bold)
        index.textColor = .white
        index.backgroundColor = pink
        index.layer.cornerRadius = 13
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
        field.font = .systemFont(ofSize: 15, weight: .medium)
        field.attributedPlaceholder = NSAttributedString(string: "Nhập điểm đến...", attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.42)])
        field.returnKeyType = .go
        field.delegate = self
        field.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        row.addSubview(field)

        let remove = UIButton(type: .system)
        remove.translatesAutoresizingMaskIntoConstraints = false
        remove.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        remove.tintColor = UIColor.white.withAlphaComponent(0.42)
        remove.addTarget(self, action: #selector(removeDestTapped(_:)), for: .touchUpInside)
        remove.tag = destinationFields.count
        row.addSubview(remove)

        NSLayoutConstraint.activate([
            index.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
            index.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            index.widthAnchor.constraint(equalToConstant: 28),
            index.heightAnchor.constraint(equalToConstant: 28),

            pin.leadingAnchor.constraint(equalTo: index.trailingAnchor, constant: 10),
            pin.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            pin.widthAnchor.constraint(equalToConstant: 18),
            pin.heightAnchor.constraint(equalToConstant: 22),

            field.leadingAnchor.constraint(equalTo: pin.trailingAnchor, constant: 8),
            field.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            field.trailingAnchor.constraint(equalTo: remove.leadingAnchor, constant: -8),

            remove.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
            remove.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            remove.widthAnchor.constraint(equalToConstant: 26),
            remove.heightAnchor.constraint(equalToConstant: 26)
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
            empty.font = .systemFont(ofSize: 15, weight: .medium)
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
            card.layer.cornerRadius = 18
            card.layer.borderWidth = 1
            card.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
            card.heightAnchor.constraint(equalToConstant: 86).isActive = true

            let icon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.tintColor = .systemGreen
            card.addSubview(icon)

            let destination = UILabel()
            destination.translatesAutoresizingMaskIntoConstraints = false
            destination.text = "Điểm \(trip.stopNumber) · \(trip.destination)"
            destination.font = .systemFont(ofSize: 14, weight: .bold)
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
                icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
                icon.topAnchor.constraint(equalTo: card.topAnchor, constant: 17),
                icon.widthAnchor.constraint(equalToConstant: 25),
                icon.heightAnchor.constraint(equalToConstant: 25),
                destination.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
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
