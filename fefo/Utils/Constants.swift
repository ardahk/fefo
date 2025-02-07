import CoreLocation

enum Constants {
    static let berkeleyLandmarks: [MapLandmark] = [
        MapLandmark(name: "Sather Gate", coordinate: CLLocationCoordinate2D(latitude: 37.87031128938746, longitude: -122.25952714457256), type: .landmark, visibilityRange: 500),
        MapLandmark(name: "Campanile", coordinate: CLLocationCoordinate2D(latitude: 37.8721, longitude: -122.2578), type: .landmark, visibilityRange: 1000),
        MapLandmark(name: "Memorial Stadium", coordinate: CLLocationCoordinate2D(latitude: 37.8705, longitude: -122.2507), type: .athletics, visibilityRange: 800),
        MapLandmark(name: "Doe Library", coordinate: CLLocationCoordinate2D(latitude: 37.87223786566174, longitude: -122.259292081415), type: .library, visibilityRange: 500),
        MapLandmark(name: "Sproul Plaza", coordinate: CLLocationCoordinate2D(latitude: 37.86960277132627, longitude: -122.25882572406812), type: .landmark, visibilityRange: 500),
        MapLandmark(name: "MLK Student Union", coordinate: CLLocationCoordinate2D(latitude: 37.8692, longitude: -122.2595), type: .student, visibilityRange: 500),
        MapLandmark(name: "Wheeler Hall", coordinate: CLLocationCoordinate2D(latitude: 37.87134037442237, longitude: -122.2591762415743), type: .academic, visibilityRange: 500),
        MapLandmark(name: "Dwinelle Hall", coordinate: CLLocationCoordinate2D(latitude: 37.87080993758247, longitude: -122.26063656612418), type: .academic, visibilityRange: 500),
        MapLandmark(name: "Valley Life Sciences", coordinate: CLLocationCoordinate2D(latitude: 37.87144132714982, longitude: -122.26219095473874), type: .academic, visibilityRange: 500),
        MapLandmark(name: "Haas Pavilion", coordinate: CLLocationCoordinate2D(latitude: 37.86944789161089, longitude: -122.26218429366875), type: .athletics, visibilityRange: 600),
        // ... rest of the landmarks ...
    ]
} 