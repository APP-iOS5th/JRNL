//
//  MapViewController.swift
//  JRNL
//
//  Created by Jungman Bae on 5/14/24.
//

import UIKit
import CoreLocation
import MapKit
import SwiftData
import SwiftUI

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    @IBOutlet var mapView: MKMapView!
    let locationManager = CLLocationManager()
    var selectedJournalEntry: JournalEntry?
    
    let globeView = UIHostingController(rootView: GlobeView())
    
    var container: ModelContainer?
    var context: ModelContext?
    
    var annotations: [JournalMapAnnotation] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        self.navigationItem.title = "Loading..."
        mapView.delegate = self
        
        guard let _container = try? ModelContainer(for: JournalEntry.self) else {
            fatalError("Could not initialize Container")
        }
        container = _container
        context = ModelContext(_container)
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        mapView.removeAnnotations(annotations)
        locationManager.requestLocation()
        
        #if os(visionOS)
        addChild(globeView)
        view.addSubview(globeView.view)
        setupConstraints()
        #endif
    }
    
    override func viewDidDisappear(_ animated: Bool) {
      super.viewDidDisappear(animated)
      #if os(visionOS)
      self.children.forEach {
        $0.willMove(toParent: nil)
        $0.view.removeFromSuperview()
        $0.removeFromParent()
      }
      #endif
    } 
    
    private func setupConstraints() {
      globeView.view.translatesAutoresizingMaskIntoConstraints = false
      globeView.view.centerXAnchor.constraint(equalTo:
      view.centerXAnchor).isActive = true
      globeView.view.centerYAnchor.constraint(equalTo:
      view.centerYAnchor).isActive = true
      globeView.view.heightAnchor.constraint(equalToConstant: 600.0).isActive =
      true
      globeView.view.widthAnchor.constraint(equalToConstant: 600.0).isActive =
      true
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let myLocation = locations.first {
            let lat = myLocation.coordinate.latitude
            let long = myLocation.coordinate.longitude
            self.navigationItem.title = "Map"
            mapView.region = setInitialRegion(lat: lat, long: long)
            let descrptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.latitude != nil && $0.longitude != nil })
            guard let journalEntries = try? context?.fetch(descrptor) else {
                return
            }
            annotations = journalEntries.map { JournalMapAnnotation(journal: $0) }
            mapView.addAnnotations(annotations)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
      print("Failed to find user's location: \(error.localizedDescription)")
    }
    
    // MARK: - MKMapViewDelegate
    func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
        let identifier = "mapAnnotation"
        if annotation is JournalMapAnnotation {
            if let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) {
                annotationView.annotation = annotation
                return annotationView
            } else {
                let annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView.canShowCallout = true
                let calloutButton = UIButton(type: .detailDisclosure) 
                annotationView.rightCalloutAccessoryView = calloutButton
                return annotationView
            }
        }
        return nil
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView,
                 calloutAccessoryControlTapped control: UIControl) {
        guard let annotation = mapView.selectedAnnotations.first else {
            return
        }
        selectedJournalEntry = (annotation as? JournalMapAnnotation)?.journal
        self.performSegue(withIdentifier: "showMapDetail", sender: self)
    }
    
    // MARK: - navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        guard segue.identifier == "showMapDetail" else {
            fatalError("Unexpected segue identifier")
        }
        guard let entryDetailViewController = segue.destination as? JournalEntryDetailViewController else {
            fatalError("Unexpected view controller")
        }
        entryDetailViewController.selectedJournalEntry = selectedJournalEntry
    }
    
    // MARK: - Methods
    func setInitialRegion(lat: CLLocationDegrees, long: CLLocationDegrees) -> MKCoordinateRegion {
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: long),
                           span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    }
}
