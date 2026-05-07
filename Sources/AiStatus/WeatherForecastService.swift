import CodexStatusCore
import CoreLocation
import Foundation

enum WeatherServiceSnapshot {
    case idle
    case waitingForPermission
    case locating
    case loading(previous: WeatherForecast?)
    case forecast(WeatherForecast)
    case failed(message: String, previous: WeatherForecast?)
    case permissionDenied
    case locationUnavailable(String)

    var forecast: WeatherForecast? {
        switch self {
        case let .forecast(forecast):
            return forecast
        case let .loading(previous), let .failed(_, previous):
            return previous
        case .idle, .waitingForPermission, .locating, .permissionDenied, .locationUnavailable:
            return nil
        }
    }
}

final class WeatherForecastService: NSObject, CLLocationManagerDelegate {
    private let locationManager: CLLocationManager
    private let session: URLSession
    private let refreshInterval: TimeInterval
    private var latestLocation: CLLocation?
    private var latestForecast: WeatherForecast?
    private var lastFetchAt: Date?
    private var lastFetchedLocation: CLLocation?
    private var inFlightTask: URLSessionDataTask?
    private var isRequestingLocation = false
    private var didRequestAuthorization = false

    private(set) var snapshot: WeatherServiceSnapshot = .idle
    var onSnapshotChange: ((WeatherServiceSnapshot) -> Void)?

    init(
        locationManager: CLLocationManager = CLLocationManager(),
        session: URLSession = .shared,
        refreshInterval: TimeInterval = 10 * 60
    ) {
        self.locationManager = locationManager
        self.session = session
        self.refreshInterval = refreshInterval
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        self.locationManager.distanceFilter = 10_000
    }

    func start() {
        requestLocationIfAllowed()
    }

    func stop() {
        inFlightTask?.cancel()
        inFlightTask = nil
        locationManager.stopUpdatingLocation()
    }

    func refreshIfNeeded(force: Bool = false) {
        if let latestLocation {
            fetchWeather(for: latestLocation, force: force)
        } else {
            requestLocationIfAllowed()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        requestLocationIfAllowed()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isRequestingLocation = false
        guard let location = locations.last else {
            updateSnapshot(.locationUnavailable("无法读取当前位置"))
            return
        }

        latestLocation = location
        fetchWeather(for: location, force: false)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isRequestingLocation = false
        if let locationError = error as? CLError, locationError.code == .denied {
            updateSnapshot(.permissionDenied)
            return
        }

        updateSnapshot(.locationUnavailable("定位失败：\(error.localizedDescription)"))
    }

    private func requestLocationIfAllowed() {
        guard CLLocationManager.locationServicesEnabled() else {
            updateSnapshot(.locationUnavailable("系统定位服务未开启"))
            return
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            updateSnapshot(.waitingForPermission)
            guard !didRequestAuthorization else {
                return
            }
            didRequestAuthorization = true
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            guard !isRequestingLocation else {
                return
            }
            updateSnapshot(.locating)
            isRequestingLocation = true
            locationManager.requestLocation()
        case .denied, .restricted:
            isRequestingLocation = false
            updateSnapshot(.permissionDenied)
        @unknown default:
            isRequestingLocation = false
            updateSnapshot(.locationUnavailable("未知定位权限状态"))
        }
    }

    private func fetchWeather(for location: CLLocation, force: Bool) {
        guard force || shouldFetchWeather(for: location) else {
            if let latestForecast {
                updateSnapshot(.forecast(latestForecast))
            }
            return
        }

        guard inFlightTask == nil else {
            return
        }

        guard let url = weatherURL(for: location.coordinate) else {
            updateSnapshot(.failed(message: "天气请求地址无效", previous: latestForecast))
            return
        }

        updateSnapshot(.loading(previous: latestForecast))
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self else {
                return
            }

            if let error = error as NSError?, error.domain == NSURLErrorDomain, error.code == NSURLErrorCancelled {
                DispatchQueue.main.async {
                    self.inFlightTask = nil
                }
                return
            }

            do {
                if let error {
                    throw error
                }
                if let httpResponse = response as? HTTPURLResponse,
                   !(200..<300).contains(httpResponse.statusCode) {
                    throw WeatherServiceError.httpStatus(httpResponse.statusCode)
                }
                guard let data else {
                    throw WeatherServiceError.emptyResponse
                }

                let forecast = try WeatherForecastParser.parse(data: data, fetchedAt: Date())
                DispatchQueue.main.async {
                    self.inFlightTask = nil
                    self.latestForecast = forecast
                    self.lastFetchAt = Date()
                    self.lastFetchedLocation = location
                    self.updateSnapshot(.forecast(forecast))
                }
            } catch {
                DispatchQueue.main.async {
                    self.inFlightTask = nil
                    self.updateSnapshot(.failed(message: error.localizedDescription, previous: self.latestForecast))
                }
            }
        }

        inFlightTask = task
        task.resume()
    }

    private func shouldFetchWeather(for location: CLLocation) -> Bool {
        if let lastFetchedLocation, location.distance(from: lastFetchedLocation) > 10_000 {
            return true
        }

        guard let lastFetchAt else {
            return true
        }

        return Date().timeIntervalSince(lastFetchAt) >= refreshInterval
    }

    private func weatherURL(for coordinate: CLLocationCoordinate2D) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: formattedCoordinate(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: formattedCoordinate(coordinate.longitude)),
            URLQueryItem(name: "current", value: [
                "temperature_2m",
                "apparent_temperature",
                "relative_humidity_2m",
                "precipitation",
                "weather_code",
                "wind_speed_10m",
                "is_day"
            ].joined(separator: ",")),
            URLQueryItem(name: "hourly", value: [
                "temperature_2m",
                "weather_code",
                "precipitation_probability"
            ].joined(separator: ",")),
            URLQueryItem(name: "daily", value: [
                "weather_code",
                "temperature_2m_max",
                "temperature_2m_min",
                "precipitation_probability_max"
            ].joined(separator: ",")),
            URLQueryItem(name: "forecast_days", value: "7"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "precipitation_unit", value: "mm")
        ]
        return components?.url
    }

    private func formattedCoordinate(_ value: CLLocationDegrees) -> String {
        String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private func updateSnapshot(_ snapshot: WeatherServiceSnapshot) {
        let update = { [weak self] in
            guard let self else {
                return
            }
            self.snapshot = snapshot
            self.onSnapshotChange?(snapshot)
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }
}

private enum WeatherServiceError: LocalizedError {
    case emptyResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "天气服务返回空响应"
        case let .httpStatus(statusCode):
            return "天气服务 HTTP \(statusCode)"
        }
    }
}
