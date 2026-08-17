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
        map.overrideUserInterfaceStyle = .light
        map.mapType = model.mapType
        mapView = map
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.mapType = model.mapType
        if model.followUser, let loc = model.currentLocation?.coordinate {
            let span = MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
            map.setRegion(MKCoordinateRegion(center: loc, span: span), animated: true)
        }
        context.coordinator.syncRoute(on: map, coordinates: model.routeCoordinates)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        let parent: DriveMapView
        var routeOverlay: MKPolyline?
        var lastCenteredLocation: CLLocationCoordinate2D?
        init(_ parent: DriveMapView) { self.parent = parent }

        func syncRoute(on map: MKMapView, coordinates: [CLLocationCoordinate2D]) {
            if let old = routeOverlay { map.removeOverlay(old) }
            guard coordinates.count > 1 else { routeOverlay = nil; return }
            let poly = MKPolyline(coordinates: coordinates, count: coordinates.count)
            routeOverlay = poly
            map.addOverlay(poly)
            if !parent.model.isNavigating {
                map.setVisibleMapRect(poly.boundingMapRect, edgePadding: UIEdgeInsets(top: 110, left: 40, bottom: 220, right: 40), animated: true)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: poly)
            renderer.strokeColor = UIColor(red: 0.39, green: 0.34, blue: 0.92, alpha: 1)
            renderer.lineWidth = 6
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }
    }
}
