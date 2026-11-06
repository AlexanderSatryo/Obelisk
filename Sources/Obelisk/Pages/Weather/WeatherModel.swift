import Foundation

public struct HourlyForecast: Identifiable, Sendable, Codable {
    public var id: UUID
    public let time: String
    public let temperature: Int
    public let precipitationChance: Int
    public let iconName: String

    public init(id: UUID = UUID(), time: String, temperature: Int, precipitationChance: Int = 0, iconName: String) {
        self.id = id
        self.time = time
        self.temperature = temperature
        self.precipitationChance = precipitationChance
        self.iconName = iconName
    }
}

public struct WeatherData: Sendable, Codable {
    public var cityName: String
    public var temperature: Int
    public var feelsLike: Int
    public var conditionText: String
    public var iconName: String
    public var highTemp: Int
    public var lowTemp: Int
    public var humidity: Int
    public var windSpeed: Int
    public var windDirection: String
    public var uvIndex: Int
    public var uvDescription: String
    public var precipitationChance: Int
    public var airPressure: Int
    public var isDeviceLocation: Bool
    public var hourly: [HourlyForecast]

    public init(
        cityName: String,
        temperature: Int,
        feelsLike: Int,
        conditionText: String,
        iconName: String,
        highTemp: Int,
        lowTemp: Int,
        humidity: Int,
        windSpeed: Int,
        windDirection: String = "WSW",
        uvIndex: Int,
        uvDescription: String = "Very High",
        precipitationChance: Int = 20,
        airPressure: Int = 1006,
        isDeviceLocation: Bool = true,
        hourly: [HourlyForecast]
    ) {
        self.cityName = cityName
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.conditionText = conditionText
        self.iconName = iconName
        self.highTemp = highTemp
        self.lowTemp = lowTemp
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.uvIndex = uvIndex
        self.uvDescription = uvDescription
        self.precipitationChance = precipitationChance
        self.airPressure = airPressure
        self.isDeviceLocation = isDeviceLocation
        self.hourly = hourly
    }

    public static var placeholder: WeatherData {
        if let data = UserDefaults.standard.data(forKey: "cachedWeatherData"),
           let cached = try? JSONDecoder().decode(WeatherData.self, from: data) {
            return cached
        }

        let nowHour = Calendar.current.component(.hour, from: Date())
        var hours: [HourlyForecast] = []
        for offset in 0..<5 {
            let h = (nowHour + offset) % 24
            let label = offset == 0 ? "Now" : String(format: "%02d:00", h)
            hours.append(HourlyForecast(time: label, temperature: 30, precipitationChance: 25, iconName: "cloud.sun.fill"))
        }

        return WeatherData(
            cityName: "South Jakarta",
            temperature: 30,
            feelsLike: 34,
            conditionText: "Partly Cloudy",
            iconName: "cloud.sun.fill",
            highTemp: 35,
            lowTemp: 25,
            humidity: 67,
            windSpeed: 9,
            windDirection: "WSW",
            uvIndex: 9,
            uvDescription: "Very High",
            precipitationChance: 25,
            airPressure: 1006,
            isDeviceLocation: true,
            hourly: hours
        )
    }
}
