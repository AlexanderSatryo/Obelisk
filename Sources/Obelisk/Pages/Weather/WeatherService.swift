import Foundation
import Combine
import CoreLocation
import AppKit

/// Live weather service powered by CoreLocation, IP geolocation fallback, and the Open-Meteo API.
/// Supports both automatic device GPS tracking and user-configured manual city override.
@MainActor
public final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = WeatherService()

    @Published public var weather: WeatherData = .placeholder
    @Published public var isLoading: Bool = false
    @Published public var isUsingDeviceLocation: Bool = true

    private var locationManager: CLLocationManager?
    private var lastKnownCoordinate: CLLocationCoordinate2D?
    private var lastKnownCity: String?
    private var manualCoordinate: CLLocationCoordinate2D?
    private var manualResolvedCity: String?
    private var refreshTimer: Timer?
    private var lastWeatherFetchTime: Date = .distantPast

    private override init() {
        super.init()

        let savedLat = UserDefaults.standard.double(forKey: "weather_lat")
        let savedLon = UserDefaults.standard.double(forKey: "weather_lon")
        let savedCity = UserDefaults.standard.string(forKey: "weather_city")
        if savedLat != 0 && savedLon != 0 {
            self.lastKnownCoordinate = CLLocationCoordinate2D(latitude: savedLat, longitude: savedLon)
            self.lastKnownCity = savedCity
        } else {
            self.lastKnownCoordinate = CLLocationCoordinate2D(latitude: -6.2366, longitude: 106.8227)
            self.lastKnownCity = "South Jakarta"
            UserDefaults.standard.set("South Jakarta", forKey: "weather_city")
            UserDefaults.standard.set(-6.2366, forKey: "weather_lat")
            UserDefaults.standard.set(106.8227, forKey: "weather_lon")
        }

        setupLocationManager()
        resolveLiveLocationAndWeather()
        restartPeriodicRefresh()
    }

    /// Re-evaluates location mode and refreshes weather data immediately after a Settings change.
    public func refreshForSettingsChange() {
        let settings = ObeliskSettings.shared
        if settings.weatherLocationMode == .manualCity {
            geocodeManualCityAndFetch(settings.manualCityName)
        } else {
            resolveLiveLocationAndWeather()
        }
    }

    /// Restarts the periodic background refresh timer using the user's configured interval.
    public func restartPeriodicRefresh() {
        refreshTimer?.invalidate()
        let minutes = max(1, ObeliskSettings.shared.weatherRefreshMinutes)
        let interval = TimeInterval(minutes * 60)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchWeather()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.refreshTimer = timer
    }

    private func setupLocationManager() {
        let lm = CLLocationManager()
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyHundredMeters
        let status = lm.authorizationStatus
        if status == .authorizedAlways || status == .authorized {
            lm.startUpdatingLocation()
            lm.requestLocation()
            if let loc = lm.location {
                self.lastKnownCoordinate = loc.coordinate
                reverseGeocodeAndFetch(location: loc)
            }
        } else if status == .notDetermined {
            lm.requestWhenInUseAuthorization()
        }
        self.locationManager = lm
    }

    /// Inspects the macOS native Weather application via System Events to mirror its active displayed city title.
    public nonisolated static func detectNativeWeatherAppCity() -> String? {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.weather").isEmpty else {
            return nil
        }

        let script = """
        tell application "System Events"
            if exists (process "Weather") then
                tell process "Weather"
                    if (count of windows) > 0 then
                        return title of window 1
                    end if
                end tell
            end if
            return ""
        end tell
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let output = appleScript.executeAndReturnError(&error)
            if error == nil, let title = output.stringValue, !title.isEmpty, title.lowercased() != "weather" {
                return title
            }
        }
        return nil
    }

    public nonisolated static func extractAccurateCity(from placemark: CLPlacemark) -> String {
        // If the macOS native Weather app is open, match its city directly
        if let nativeCity = detectNativeWeatherAppCity(), !nativeCity.isEmpty {
            return nativeCity
        }

        // Check subAdministrativeArea first (e.g. "Kota Administrasi Jakarta Selatan")
        if let subAdmin = placemark.subAdministrativeArea, !subAdmin.isEmpty {
            let lower = subAdmin.lowercased()
            if lower.contains("jakarta selatan") || lower.contains("south jakarta") {
                return "South Jakarta"
            } else if lower.contains("jakarta pusat") || lower.contains("central jakarta") {
                return "Central Jakarta"
            } else if lower.contains("jakarta barat") || lower.contains("west jakarta") {
                return "West Jakarta"
            } else if lower.contains("jakarta timur") || lower.contains("east jakarta") {
                return "East Jakarta"
            } else if lower.contains("jakarta utara") || lower.contains("north jakarta") {
                return "North Jakarta"
            } else if lower.contains("tangerang selatan") || lower.contains("south tangerang") {
                return "South Tangerang"
            } else if lower != "jakarta" {
                let clean = subAdmin
                    .replacingOccurrences(of: "Kota Administrasi ", with: "")
                    .replacingOccurrences(of: "Kota ", with: "")
                    .replacingOccurrences(of: "Kabupaten ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    return clean
                }
            }
        }

        if let locality = placemark.locality, !locality.isEmpty {
            let lower = locality.lowercased()
            if lower == "jakarta" || lower.contains("jakarta") {
                if let subLoc = placemark.subLocality, !subLoc.isEmpty {
                    let subLower = subLoc.lowercased()
                    if ["kebayoran", "mampang", "cilandak", "tebet", "pasar minggu", "pancoran", "jagakarsa", "pesanggrahan", "setiabudi"].contains(where: { subLower.contains($0) }) {
                        return "South Jakarta"
                    }
                    return "\(subLoc), South Jakarta"
                }
                return "South Jakarta"
            }
            return locality
        }

        if let subLoc = placemark.subLocality, !subLoc.isEmpty {
            let subLower = subLoc.lowercased()
            if ["kebayoran", "mampang", "cilandak", "tebet", "pasar minggu", "pancoran", "jagakarsa", "pesanggrahan", "setiabudi"].contains(where: { subLower.contains($0) }) {
                return "South Jakarta"
            }
            return subLoc
        }
        if let admin = placemark.administrativeArea, !admin.isEmpty {
            return admin
        }
        return "South Jakarta"
    }

    private func reverseGeocodeAndFetch(location: CLLocation) {
        let coord = location.coordinate
        let fallbackCity = self.lastKnownCity ?? "South Jakarta"
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            let city: String
            if let p = placemarks?.first {
                city = WeatherService.extractAccurateCity(from: p)
            } else {
                city = fallbackCity
            }

            Task { @MainActor in
                WeatherService.shared.lastKnownCoordinate = coord
                if !city.isEmpty {
                    WeatherService.shared.lastKnownCity = city
                    UserDefaults.standard.set(city, forKey: "weather_city")
                }
                UserDefaults.standard.set(coord.latitude, forKey: "weather_lat")
                UserDefaults.standard.set(coord.longitude, forKey: "weather_lon")
                if ObeliskSettings.shared.weatherLocationMode == .deviceGPS {
                    WeatherService.shared.isUsingDeviceLocation = true
                    WeatherService.shared.fetchWeather()
                }
            }
        }
    }

    private func geocodeManualCityAndFetch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true

        Task.detached(priority: .userInitiated) {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            guard let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=en&format=json") else {
                await MainActor.run { WeatherService.shared.isLoading = false }
                return
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let first = results.first,
                   let lat = WeatherService.numDouble(first["latitude"]),
                   let lon = WeatherService.numDouble(first["longitude"]) {
                    let resolvedName = (first["name"] as? String) ?? trimmed
                    await MainActor.run {
                        WeatherService.shared.manualCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        WeatherService.shared.manualResolvedCity = resolvedName
                        WeatherService.shared.isUsingDeviceLocation = false
                        WeatherService.shared.fetchWeather()
                    }
                    return
                }
            } catch {}
            await MainActor.run {
                WeatherService.shared.isLoading = false
            }
        }
    }

    private func resolveLiveLocationAndWeather() {
        if ObeliskSettings.shared.weatherLocationMode == .manualCity {
            geocodeManualCityAndFetch(ObeliskSettings.shared.manualCityName)
            return
        }

        // 1. First priority: Sync directly with macOS native Weather app if it is running
        if let nativeCity = WeatherService.detectNativeWeatherAppCity(), !nativeCity.isEmpty {
            self.lastKnownCity = nativeCity
            UserDefaults.standard.set(nativeCity, forKey: "weather_city")
            if nativeCity == "South Jakarta" {
                let defaultCoord = CLLocationCoordinate2D(latitude: -6.2366, longitude: 106.8227)
                self.lastKnownCoordinate = defaultCoord
                UserDefaults.standard.set(defaultCoord.latitude, forKey: "weather_lat")
                UserDefaults.standard.set(defaultCoord.longitude, forKey: "weather_lon")
            }
            fetchWeather()
            return
        }

        // 2. Second priority: CoreLocation hardware fix if authorized
        if let lm = locationManager {
            let status = lm.authorizationStatus
            if status == .authorizedAlways || status == .authorized {
                lm.requestLocation()
                if let loc = lm.location {
                    self.lastKnownCoordinate = loc.coordinate
                    reverseGeocodeAndFetch(location: loc)
                    return
                }
            } else if status == .notDetermined {
                lm.requestWhenInUseAuthorization()
            }
        }

        // 3. Third priority: Known saved coordinate
        if lastKnownCoordinate != nil, let city = lastKnownCity, !city.isEmpty {
            fetchWeather()
            return
        }

        // 4. Default anchor: South Jakarta
        let fallbackCoord = CLLocationCoordinate2D(latitude: -6.2366, longitude: 106.8227)
        self.lastKnownCoordinate = fallbackCoord
        self.lastKnownCity = "South Jakarta"
        UserDefaults.standard.set("South Jakarta", forKey: "weather_city")
        UserDefaults.standard.set(fallbackCoord.latitude, forKey: "weather_lat")
        UserDefaults.standard.set(fallbackCoord.longitude, forKey: "weather_lon")
        fetchWeather()
    }

    // MARK: - CoreLocation Delegate

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            WeatherService.shared.reverseGeocodeAndFetch(location: loc)
        }
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedAlways || status == .authorized {
            manager.startUpdatingLocation()
            manager.requestLocation()
            if let loc = manager.location {
                Task { @MainActor in
                    WeatherService.shared.reverseGeocodeAndFetch(location: loc)
                }
            }
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    /// Fetches real-time meteorological telemetry from Open-Meteo for the active coordinates.
    public func fetchWeather(force: Bool = false) {
        let settings = ObeliskSettings.shared
        if settings.weatherLocationMode == .manualCity && manualCoordinate == nil {
            geocodeManualCityAndFetch(settings.manualCityName)
            return
        }

        // Cache guard: avoid spawning subprocess runners during interactive tab swipes if data is fresh (< 5 mins)
        let now = Date()
        if !force && now.timeIntervalSince(lastWeatherFetchTime) < 300 && weather.temperature != 0 && !weather.cityName.isEmpty {
            return
        }
        lastWeatherFetchTime = now

        isLoading = true

        let lat: Double
        let lon: Double
        var city: String
        let isDevice: Bool

        if settings.weatherLocationMode == .manualCity, let mCoord = manualCoordinate {
            lat = mCoord.latitude
            lon = mCoord.longitude
            city = manualResolvedCity ?? settings.manualCityName
            isDevice = false
        } else {
            // Re-check native Weather app window title so Obelisk continuously mirrors macOS Weather
            if let nativeCity = WeatherService.detectNativeWeatherAppCity(), !nativeCity.isEmpty {
                self.lastKnownCity = nativeCity
                UserDefaults.standard.set(nativeCity, forKey: "weather_city")
            }

            if let coord = lastKnownCoordinate {
                lat = coord.latitude
                lon = coord.longitude
                city = lastKnownCity ?? "South Jakarta"
                isDevice = true
            } else {
                lat = -6.2366
                lon = 106.8227
                city = lastKnownCity ?? "South Jakarta"
                isDevice = true
            }
        }

        Task.detached(priority: .userInitiated) {
            // 1. Primary: Native Apple Weather (WeatherKit) via macOS system runner
            if let appleData = WeatherService.runAppleWeatherFetcher(lat: lat, lon: lon, city: city, isDevice: isDevice),
               let parsed = try? JSONDecoder().decode(WeatherData.self, from: appleData) {
                await MainActor.run {
                    WeatherService.shared.weather = parsed
                    WeatherService.shared.isLoading = false
                    if let encoded = try? JSONEncoder().encode(parsed) {
                        UserDefaults.standard.set(encoded, forKey: "cachedWeatherData")
                    }
                }
                return
            }

            // 2. Secondary Fallback: Open-Meteo API
            let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,surface_pressure,wind_speed_10m,wind_direction_10m&hourly=temperature_2m,precipitation_probability,weather_code&daily=temperature_2m_max,temperature_2m_min,uv_index_max&forecast_days=2&timezone=auto"
            guard let url = URL(string: urlString) else {
                await MainActor.run {
                    WeatherService.shared.isLoading = false
                }
                return
            }

            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 8

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    if let parsed = WeatherService.parseOpenMeteo(data, city: city, isDevice: isDevice) {
                        await MainActor.run {
                            WeatherService.shared.weather = parsed
                            WeatherService.shared.isLoading = false
                            if let encoded = try? JSONEncoder().encode(parsed) {
                                UserDefaults.standard.set(encoded, forKey: "cachedWeatherData")
                            }
                        }
                        return
                    }
                }
            } catch {}

            await MainActor.run {
                WeatherService.shared.isLoading = false
            }
        }
    }

    private nonisolated static func numDouble(_ any: Any?) -> Double? {
        if let n = any as? NSNumber { return n.doubleValue }
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        return nil
    }

    private nonisolated static func numInt(_ any: Any?) -> Int? {
        if let n = any as? NSNumber { return Int(round(n.doubleValue)) }
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(round(d)) }
        return nil
    }

    private nonisolated static func parseOpenMeteo(_ data: Data, city: String, isDevice: Bool) -> WeatherData? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = json["current"] as? [String: Any] else {
            return nil
        }

        let temp = numInt(current["temperature_2m"]) ?? 30
        let feels = numInt(current["apparent_temperature"]) ?? temp
        let humidity = numInt(current["relative_humidity_2m"]) ?? 67
        let wind = numInt(current["wind_speed_10m"]) ?? 9
        let windDeg = numDouble(current["wind_direction_10m"]) ?? 240.0
        let windDir = degreesToDirection(windDeg)
        let pressure = numInt(current["surface_pressure"]) ?? 1006
        let code = numInt(current["weather_code"]) ?? 1

        let (condText, icon) = mapWeatherCode(code)

        var uv = 8
        var dailyHigh: Int? = nil
        var dailyLow: Int? = nil
        if let daily = json["daily"] as? [String: Any] {
            if let uvArr = daily["uv_index_max"] as? [Any], let firstUV = numInt(uvArr.first) {
                uv = firstUV
            }
            if let maxArr = daily["temperature_2m_max"] as? [Any], let firstMax = numInt(maxArr.first) {
                dailyHigh = firstMax
            }
            if let minArr = daily["temperature_2m_min"] as? [Any], let firstMin = numInt(minArr.first) {
                dailyLow = firstMin
            }
        }
        let uvDesc = uvToDescription(uv)

        var hourlyList: [HourlyForecast] = []
        var currentRainChance = 0

        if let hourly = json["hourly"] as? [String: Any],
           let times = hourly["time"] as? [String],
           let tempsRaw = hourly["temperature_2m"] as? [Any],
           let codesRaw = hourly["weather_code"] as? [Any] {

            let rainProbsRaw = hourly["precipitation_probability"] as? [Any] ?? []
            let nowHour = Calendar.current.component(.hour, from: Date())

            var startIndex = nowHour
            for (idx, timeStr) in times.prefix(24).enumerated() {
                if timeStr.hasSuffix(String(format: "T%02d:00", nowHour)) {
                    startIndex = idx
                    break
                }
            }

            var count = 0
            for i in startIndex..<times.count {
                if count < 5 {
                    let hTemp = (count == 0) ? temp : (numInt(tempsRaw[i]) ?? temp)
                    let hCode = (count == 0) ? code : (numInt(codesRaw[i]) ?? code)
                    let (_, hIcon) = mapWeatherCode(hCode)
                    let rainChance = (i < rainProbsRaw.count) ? (numInt(rainProbsRaw[i]) ?? 0) : 0
                    if count == 0 {
                        currentRainChance = rainChance
                    }

                    let hourNum = (nowHour + count) % 24
                    let timeLabel = count == 0 ? "Now" : String(format: "%02d:00", hourNum)
                    hourlyList.append(
                        HourlyForecast(
                            time: timeLabel,
                            temperature: hTemp,
                            precipitationChance: rainChance,
                            iconName: hIcon
                        )
                    )
                    count += 1
                }
            }
        }

        if hourlyList.isEmpty {
            hourlyList = WeatherData.placeholder.hourly
        }

        let high = max(temp, dailyHigh ?? (hourlyList.map { $0.temperature }.max() ?? (temp + 3)))
        let low = min(temp, dailyLow ?? (hourlyList.map { $0.temperature }.min() ?? (temp - 4)))

        return WeatherData(
            cityName: city,
            temperature: temp,
            feelsLike: feels,
            conditionText: condText,
            iconName: icon,
            highTemp: high,
            lowTemp: low,
            humidity: humidity,
            windSpeed: wind,
            windDirection: windDir,
            uvIndex: uv,
            uvDescription: uvDesc,
            precipitationChance: currentRainChance,
            airPressure: pressure,
            isDeviceLocation: isDevice,
            hourly: hourlyList
        )
    }

    private nonisolated static func degreesToDirection(_ degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int(round(degrees.truncatingRemainder(dividingBy: 360) / 22.5)) % 16
        return directions[max(0, min(index, 15))]
    }

    private nonisolated static func uvToDescription(_ uv: Int) -> String {
        switch uv {
        case 0...2: return "Low"
        case 3...5: return "Moderate"
        case 6...7: return "High"
        case 8...10: return "Very High"
        default: return "Extreme"
        }
    }

    private nonisolated static func mapWeatherCode(_ code: Int) -> (String, String) {
        switch code {
        case 0:
            return ("Clear Sky", "sun.max.fill")
        case 1, 2:
            return ("Mainly Clear", "cloud.sun.fill")
        case 3:
            return ("Overcast", "cloud.fill")
        case 45, 48:
            return ("Foggy", "cloud.fog.fill")
        case 51, 53, 55:
            return ("Drizzle", "cloud.drizzle.fill")
        case 61, 63, 65:
            return ("Rain", "cloud.rain.fill")
        case 80, 81, 82:
            return ("Rain Showers", "cloud.heavyrain.fill")
        case 95, 96, 99:
            return ("Thunderstorm", "cloud.bolt.rain.fill")
        default:
            return ("Partly Cloudy", "cloud.sun.fill")
        }
    }

    // MARK: - Apple WeatherKit Runner Integration

    nonisolated private static var scriptURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Obelisk", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("apple_weather_fetcher.swift")
    }

    nonisolated private static func ensureScriptExists() {
        let url = scriptURL
        if let existing = try? String(contentsOf: url, encoding: .utf8),
           existing == appleWeatherFetcherScriptSource {
            return
        }
        try? appleWeatherFetcherScriptSource.write(to: url, atomically: true, encoding: .utf8)
    }

    private nonisolated static func runAppleWeatherFetcher(lat: Double, lon: Double, city: String, isDevice: Bool) -> Data? {
        guard SwiftToolchainProbe.isAvailable else { return nil }
        ensureScriptExists()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = [
            scriptURL.path,
            String(lat),
            String(lon),
            city,
            isDevice ? "true" : "false"
        ]

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()

        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now() + 5.0)
        timer.setEventHandler {
            if process.isRunning {
                process.terminate()
            }
        }
        timer.resume()

        do {
            try process.run()
            process.waitUntilExit()
            timer.cancel()
            if process.terminationStatus == 0 {
                let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                if !data.isEmpty {
                    return data
                }
            }
        } catch {
            timer.cancel()
        }
        return nil
    }

    nonisolated private static let appleWeatherFetcherScriptSource: String = #"""
import Foundation
import CoreLocation
import WeatherKit
import AppKit

struct HourlyForecastPayload: Codable {
    let id: UUID
    let time: String
    let temperature: Int
    let precipitationChance: Int
    let iconName: String
}

struct WeatherDataPayload: Codable {
    let cityName: String
    let temperature: Int
    let feelsLike: Int
    let conditionText: String
    let iconName: String
    let highTemp: Int
    let lowTemp: Int
    let humidity: Int
    let windSpeed: Int
    let windDirection: String
    let uvIndex: Int
    let uvDescription: String
    let precipitationChance: Int
    let airPressure: Int
    let isDeviceLocation: Bool
    let hourly: [HourlyForecastPayload]
}

func resolveSymbolName(_ name: String) -> String {
    if name.hasSuffix(".fill") {
        return name
    }
    let filled = name + ".fill"
    if NSImage(systemSymbolName: filled, accessibilityDescription: nil) != nil {
        return filled
    }
    if NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil {
        return name
    }
    return "cloud.fill"
}

let args = CommandLine.arguments
guard args.count >= 3,
      let lat = Double(args[1]),
      let lon = Double(args[2]) else {
    exit(1)
}

let rawCity = args.count >= 4 ? args[3] : "South Jakarta"
let isDevice = args.count >= 5 ? (args[4] == "true" || args[4] == "1") : true
var city = (rawCity.isEmpty || rawCity.lowercased() == "jakarta" || rawCity == "Current Location") ? "South Jakarta" : rawCity

let sema = DispatchSemaphore(value: 0)

Task {
    do {
        let loc = CLLocation(latitude: lat, longitude: lon)
        let w = try await WeatherKit.WeatherService.shared.weather(for: loc)
        
        let curr = w.currentWeather
        let daily = w.dailyForecast
        let hourly = w.hourlyForecast
        
        let temp = Int(round(curr.temperature.converted(to: .celsius).value))
        let feels = Int(round(curr.apparentTemperature.converted(to: .celsius).value))
        let condText = curr.condition.description
        let iconName = resolveSymbolName(curr.symbolName)
        let humidity = Int(round(curr.humidity * 100))
        let wind = Int(round(curr.wind.speed.converted(to: .kilometersPerHour).value))
        let windDir = curr.wind.compassDirection.abbreviation
        let uv = curr.uvIndex.value
        let uvDesc = curr.uvIndex.category.description
        let pressure = Int(round(curr.pressure.converted(to: .hectopascals).value))
        
        let today = daily.first
        let high = today.map { Int(round($0.highTemperature.converted(to: .celsius).value)) } ?? (temp + 3)
        let low = today.map { Int(round($0.lowTemperature.converted(to: .celsius).value)) } ?? (temp - 4)
        
        let now = Date()
        let upcoming = hourly.filter { $0.date >= now.addingTimeInterval(-1800) }
        let currentHourPrecip = upcoming.first.map { Int(round($0.precipitationChance * 100)) } ?? 0
        let precipChance = curr.precipitationIntensity.value > 0 ? max(70, currentHourPrecip) : currentHourPrecip
        
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        
        var hourlyList: [HourlyForecastPayload] = []
        for (i, h) in upcoming.prefix(5).enumerated() {
            let label = (i == 0) ? "Now" : df.string(from: h.date)
            let hTemp = Int(round(h.temperature.converted(to: .celsius).value))
            let hPrecip = Int(round(h.precipitationChance * 100))
            let hIcon = resolveSymbolName(h.symbolName)
            hourlyList.append(HourlyForecastPayload(
                id: UUID(),
                time: label,
                temperature: hTemp,
                precipitationChance: hPrecip,
                iconName: hIcon
            ))
        }
        
        let payload = WeatherDataPayload(
            cityName: city,
            temperature: temp,
            feelsLike: feels,
            conditionText: condText,
            iconName: iconName,
            highTemp: high,
            lowTemp: low,
            humidity: humidity,
            windSpeed: wind,
            windDirection: windDir,
            uvIndex: uv,
            uvDescription: uvDesc,
            precipitationChance: precipChance,
            airPressure: pressure,
            isDeviceLocation: isDevice,
            hourly: hourlyList
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let data = try encoder.encode(payload)
        if let jsonStr = String(data: data, encoding: .utf8) {
            print(jsonStr)
        }
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(2)
    }
    sema.signal()
}

sema.wait()
"""#
}
