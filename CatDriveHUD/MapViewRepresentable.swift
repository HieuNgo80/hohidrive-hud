import SwiftUI
import MapKit

struct DriveMapView: UIViewRepresentable {
    @ObservedObject var model: DriveViewModel
    @Binding var mapView: MKMapView?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.pointOfInterestFilter = .includingAll
        map.isRotateEnabled = true
        map.isPitchEnabled = true
        map.showsCompass = false
        map.overrideUserInterfaceStyle = model.isNavigating ? .dark : .light
        map.mapType = model.mapType
        mapView = map
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.mapType = model.mapType
        map.overrideUserInterfaceStyle = model.isNavigating ? .dark : .light

        if context.coordinator.lastCenterRequest != model.centerRequest {
            context.coordinator.lastCenterRequest = model.centerRequest
            map.setUserTrackingMode(model.headingMode ? .followWithHeading : .follow, animated: true)
        }

        context.coordinator.syncRoute(on: map, coordinates: model.routeCoordinates)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        let parent: DriveMapView
        var routeOverlay: MKPolyline?
        var lastCenterRequest = -1

        init(_ parent: DriveMapView) { self.parent = parent }

        func syncRoute(on map: MKMapView, coordinates: [CLLocationCoordinate2D]) {
            if let old = routeOverlay { map.removeOverlay(old) }
            guard coordinates.count > 1 else { routeOverlay = nil; return }
            let poly = MKPolyline(coordinates: coordinates, count: coordinates.count)
            routeOverlay = poly
            map.addOverlay(poly)
            if !parent.model.isNavigating {
                map.setVisibleMapRect(poly.boundingMapRect, edgePadding: UIEdgeInsets(top: 220, left: 35, bottom: 180, right: 70), animated: true)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: poly)
            renderer.strokeColor = parent.model.isNavigating ? UIColor(red: 0.94, green: 0.20, blue: 0.47, alpha: 1) : UIColor(red: 0.39, green: 0.34, blue: 0.92, alpha: 1)
            renderer.lineWidth = 6
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }
    }
}
