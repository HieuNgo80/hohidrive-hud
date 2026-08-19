import SwiftUI
import MapKit

enum MainTab: String, CaseIterable, Hashable {
    case home = "Home"
    case map = "Map"
    case orders = "Order"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .map: return "location.fill"
        case .orders: return "bag.fill"
        }
    }
}

struct ContentView: View {
    @StateObject private var model = DriveViewModel()
    @State private var tab: MainTab = .home
    @State private var mapView: MKMapView?
    @State private var showMapOptions = false

    private var showBottomBar: Bool {
        !(tab == .map && model.isNavigating && !model.showArrival)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .home:
                    HomeView(model: model) {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            tab = .map
                        }
                    }
                    .transition(.opacity)

                case .map:
                    MapScreen(
                        model: model,
                        mapView: $mapView,
                        showMapOptions: $showMapOptions,
                        goHome: {
                            withAnimation(.easeInOut(duration: 0.24)) {
                                tab = .home
                            }
                        }
                    )
                    .transition(.opacity)

                case .orders:
                    OrdersView(model: model)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showBottomBar {
                BottomBar(tab: $tab)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(HOHITheme.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.24), value: tab)
        .animation(.easeInOut(duration: 0.24), value: showBottomBar)
        .onChange(of: model.isNavigating) { navigating in
            if navigating {
                withAnimation(.easeInOut(duration: 0.24)) { tab = .map }
            }
        }
        .onChange(of: model.showArrival) { arrived in
            if arrived {
                withAnimation(.easeInOut(duration: 0.24)) { tab = .map }
            }
        }
    }
}

#Preview { ContentView() }
