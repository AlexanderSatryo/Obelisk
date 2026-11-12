import SwiftUI

/// Weather page of the expanded notch.
/// Three typographic zones separated by hairlines, using the same system font as every other page:
/// - Hero: location, a large light-weight temperature, condition, and daily range
/// - Hourly: a temperature curve with condition symbols above and hour labels below
/// - Details: a quiet label and value list (feels like, rain, humidity, wind, UV, pressure)
/// All values come from `WeatherService`, which mirrors the data shown by the macOS Weather app.
@MainActor
public struct DetailedWeatherView: View {
    @ObservedObject var weatherService: WeatherService
    @ObservedObject var settings: ObeliskSettings = .shared

    public init(weatherService: WeatherService? = nil) {
        self.weatherService = weatherService ?? .shared
    }

    public var body: some View {
        let w = weatherService.weather

        HStack(alignment: .center, spacing: 0) {
            hero(w)
                .frame(width: 168, alignment: .leading)

            hairline

            HourlyCurve(
                hours: Array(w.hourly.prefix(6)),
                temperature: { settings.convertedTemperature($0) },
                iconRendering: settings.colorTheme == .monochrome ? .monochrome : .multicolor,
                iconColor: settings.resolvedColor(for: .weatherPrimary)
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)

            hairline

            details(w)
                .frame(width: 128, alignment: .leading)
        }
        .frame(height: contentHeight)
        .padding(.top, 2)
        .onAppear {
            weatherService.fetchWeather()
        }
    }

    private var contentHeight: CGFloat {
        max(90, 114 + CGFloat(settings.expandedHeightOffset))
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: max(70, contentHeight - 18))
            .padding(.horizontal, 10)
    }

    // MARK: - Hero

    private func hero(_ w: WeatherData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Text(w.cityName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)

                if w.isDeviceLocation {
                    Image(systemName: "location.fill")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Text("\(settings.convertedTemperature(w.temperature))°")
                .font(.system(size: 52, weight: .thin))
                .foregroundColor(.white)
                .padding(.top, -2)

            Text(w.conditionText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
                .padding(.top, -2)

            Text("H \(settings.convertedTemperature(w.highTemp))°   L \(settings.convertedTemperature(w.lowTemp))°")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 3)
        }
    }

    // MARK: - Details

    private func details(_ w: WeatherData) -> some View {
        VStack(spacing: 7) {
            detailRow("Feels like", "\(settings.convertedTemperature(w.feelsLike))°")
            detailRow("Rain", "\(w.precipitationChance)%")
            detailRow("Humidity", "\(w.humidity)%")
            detailRow("Wind", settings.formattedWindSpeed(w.windSpeed))
            detailRow("UV Index", "\(w.uvIndex)")
            detailRow("Pressure", "\(w.airPressure) hPa")
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10.5, weight: .regular))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(value)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

// MARK: - Hourly Temperature Curve

/// Draws the next hours as a smooth temperature curve. Hotter hours sit higher on the curve.
/// Condition symbols run along the top and hour labels along the bottom.
struct HourlyCurve: View {
    let hours: [HourlyForecast]
    let temperature: (Int) -> Int
    let iconRendering: SymbolRenderingMode
    let iconColor: Color

    var body: some View {
        GeometryReader { geo in
            let count = max(hours.count, 1)
            let colW = geo.size.width / CGFloat(count)
            let temps = hours.map { $0.temperature }
            let tMax = temps.max() ?? 0
            let tMin = temps.min() ?? 0
            let curveTop: CGFloat = 42
            let curveBottom: CGFloat = 78
            let points: [CGPoint] = hours.enumerated().map { index, hour in
                let x = (CGFloat(index) + 0.5) * colW
                let y: CGFloat
                if tMax == tMin {
                    y = (curveTop + curveBottom) / 2
                } else {
                    let ratio = CGFloat(tMax - hour.temperature) / CGFloat(tMax - tMin)
                    y = curveTop + ratio * (curveBottom - curveTop)
                }
                return CGPoint(x: x, y: y)
            }

            ZStack(alignment: .topLeading) {
                if points.count > 1 {
                    curveFill(points: points, bottom: geo.size.height - 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.16), Color.white.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    curveLine(points: points)
                        .stroke(
                            Color.white.opacity(0.7),
                            style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
                        )
                }

                ForEach(Array(hours.enumerated()), id: \.element.id) { index, hour in
                    let point = points[index]

                    Image(systemName: hour.iconName)
                        .font(.system(size: 13))
                        .symbolRenderingMode(iconRendering)
                        .foregroundColor(iconColor)
                        .position(x: point.x, y: 10)

                    Text("\(temperature(hour.temperature))°")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .position(x: point.x, y: point.y - 12)

                    Text(hour.time)
                        .font(.system(size: 10, weight: index == 0 ? .medium : .regular))
                        .foregroundColor(.white.opacity(index == 0 ? 0.9 : 0.5))
                        .position(x: point.x, y: geo.size.height - 7)
                }
            }
        }
        .frame(height: 100)
    }

    private func curveLine(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for i in 1..<points.count {
            let previous = points[i - 1]
            let current = points[i]
            let midX = (previous.x + current.x) / 2
            path.addCurve(
                to: current,
                control1: CGPoint(x: midX, y: previous.y),
                control2: CGPoint(x: midX, y: current.y)
            )
        }
        return path
    }

    private func curveFill(points: [CGPoint], bottom: CGFloat) -> Path {
        var path = curveLine(points: points)
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: bottom))
        path.addLine(to: CGPoint(x: first.x, y: bottom))
        path.closeSubpath()
        return path
    }
}
