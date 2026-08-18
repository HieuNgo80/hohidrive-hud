import SwiftUI
import MapKit
import UIKit

struct DriveMapView: UIViewRepresentable {
    @ObservedObject var model: DriveViewModel
    @Binding var mapView: MKMapView?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.pointOfInterestFilter = .includingAll
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        map.isRotateEnabled = true
        map.isPitchEnabled = true
        map.showsCompass = false
        map.overrideUserInterfaceStyle = model.isNavigating ? .dark : .light
        map.mapType = model.mapType
        mapView = map
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        map.mapType = model.mapType
        map.overrideUserInterfaceStyle = model.isNavigating ? .dark : .light

        if context.coordinator.lastCenterRequest != model.centerRequest {
            context.coordinator.lastCenterRequest = model.centerRequest
            map.setUserTrackingMode(
                model.headingMode ? .followWithHeading : .follow,
                animated: true
            )
        }

        context.coordinator.syncRoute(
            on: map,
            coordinates: model.routeCoordinates,
            isNavigating: model.isNavigating
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: DriveMapView
        var routeOverlay: MKPolyline?
        var lastCenterRequest = -1
        private var routeSignature = ""

        init(parent: DriveMapView) {
            self.parent = parent
        }

        func syncRoute(
            on map: MKMapView,
            coordinates: [CLLocationCoordinate2D],
            isNavigating: Bool
        ) {
            let newSignature = signature(for: coordinates)
            guard newSignature != routeSignature else { return }
            routeSignature = newSignature

            if let old = routeOverlay {
                map.removeOverlay(old)
                routeOverlay = nil
            }

            guard coordinates.count > 1 else { return }

            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            routeOverlay = polyline
            map.addOverlay(polyline)

            if !isNavigating {
                map.setVisibleMapRect(
                    polyline.boundingMapRect,
                    edgePadding: UIEdgeInsets(top: 130, left: 40, bottom: 150, right: 85),
                    animated: true
                )
            }
        }

        private func signature(for coordinates: [CLLocationCoordinate2D]) -> String {
            guard let first = coordinates.first, let last = coordinates.last else { return "empty" }
            return "\(coordinates.count)-\(first.latitude)-\(first.longitude)-\(last.latitude)-\(last.longitude)"
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // Keep this intentionally simple. In Release + whole-module optimization,
            // the previous flatMap/contains chain could make Swift's type checker time out.
            if hasActiveUserGesture(in: mapView) {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.model.followUser = false
                }
            }
        }

        private func hasActiveUserGesture(in view: UIView) -> Bool {
            if let recognizers = view.gestureRecognizers {
                for recognizer in recognizers {
                    switch recognizer.state {
                    case .began, .changed:
                        return true
                    default:
                        break
                    }
                }
            }

            for subview in view.subviews {
                if hasActiveUserGesture(in: subview) {
                    return true
                }
            }

            return false
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = parent.model.isNavigating
                ? UIColor(red: 0.98, green: 0.20, blue: 0.48, alpha: 1)
                : UIColor(red: 0.34, green: 0.28, blue: 0.96, alpha: 1)
            renderer.lineWidth = parent.model.isNavigating ? 7 : 6
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }
    }
}
