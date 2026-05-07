import Foundation

public struct WeatherForecast: Equatable {
    public let fetchedAt: Date
    public let timezone: String?
    public let current: WeatherCurrent
    public let hourly: [WeatherHourlyForecast]
    public let daily: [WeatherDailyForecast]
}

public struct WeatherCurrent: Equatable {
    public let time: String
    public let temperature: Double
    public let apparentTemperature: Double?
    public let humidity: Double?
    public let precipitation: Double?
    public let windSpeed: Double?
    public let condition: WeatherCondition
}

public struct WeatherHourlyForecast: Equatable {
    public let time: String
    public let temperature: Double
    public let precipitationProbability: Int?
    public let condition: WeatherCondition
}

public struct WeatherDailyForecast: Equatable {
    public let date: String
    public let minTemperature: Double
    public let maxTemperature: Double
    public let precipitationProbability: Int?
    public let condition: WeatherCondition
}

public struct WeatherCondition: Equatable {
    public let code: Int
    public let title: String
    public let symbolName: String

    public static func condition(for code: Int, isDay: Bool = true) -> WeatherCondition {
        switch code {
        case 0:
            return WeatherCondition(code: code, title: "晴", symbolName: isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1, 2:
            return WeatherCondition(code: code, title: "少云", symbolName: isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3:
            return WeatherCondition(code: code, title: "多云", symbolName: "cloud.fill")
        case 45, 48:
            return WeatherCondition(code: code, title: "雾", symbolName: "cloud.fog.fill")
        case 51, 53, 55, 56, 57:
            return WeatherCondition(code: code, title: "毛毛雨", symbolName: "cloud.drizzle.fill")
        case 61:
            return WeatherCondition(code: code, title: "小雨", symbolName: "cloud.rain.fill")
        case 63:
            return WeatherCondition(code: code, title: "中雨", symbolName: "cloud.rain.fill")
        case 65, 80, 81, 82:
            return WeatherCondition(code: code, title: "大雨", symbolName: "cloud.heavyrain.fill")
        case 66, 67:
            return WeatherCondition(code: code, title: "冻雨", symbolName: "cloud.sleet.fill")
        case 71, 73, 75, 77, 85, 86:
            return WeatherCondition(code: code, title: "雪", symbolName: "cloud.snow.fill")
        case 95, 96, 99:
            return WeatherCondition(code: code, title: "雷雨", symbolName: "cloud.bolt.rain.fill")
        default:
            return WeatherCondition(code: code, title: "天气", symbolName: "cloud.fill")
        }
    }
}

public enum WeatherForecastParser {
    public static func parse(data: Data, fetchedAt: Date = Date()) throws -> WeatherForecast {
        let response = try JSONDecoder().decode(OpenMeteoForecastResponse.self, from: data)
        guard let current = response.current else {
            throw WeatherForecastParsingError.missingCurrentWeather
        }

        let isDay = (current.isDay ?? 1) != 0
        let currentWeather = WeatherCurrent(
            time: current.time,
            temperature: current.temperature2m,
            apparentTemperature: current.apparentTemperature,
            humidity: current.relativeHumidity2m,
            precipitation: current.precipitation,
            windSpeed: current.windSpeed10m,
            condition: WeatherCondition.condition(for: current.weatherCode, isDay: isDay)
        )

        return WeatherForecast(
            fetchedAt: fetchedAt,
            timezone: response.timezone,
            current: currentWeather,
            hourly: hourlyForecasts(from: response.hourly, currentTime: current.time),
            daily: dailyForecasts(from: response.daily)
        )
    }

    private static func hourlyForecasts(
        from hourly: OpenMeteoHourly?,
        currentTime: String
    ) -> [WeatherHourlyForecast] {
        guard let hourly else {
            return []
        }

        let startIndex = hourly.time.firstIndex { $0 >= currentTime } ?? hourly.time.startIndex
        let endIndex = min(hourly.time.count, startIndex + 8)

        return (startIndex..<endIndex).compactMap { index in
            guard index < hourly.temperature2m.count,
                  index < hourly.weatherCode.count
            else {
                return nil
            }

            return WeatherHourlyForecast(
                time: hourly.time[index],
                temperature: hourly.temperature2m[index],
                precipitationProbability: hourly.precipitationProbability?[safe: index],
                condition: WeatherCondition.condition(for: hourly.weatherCode[index])
            )
        }
    }

    private static func dailyForecasts(from daily: OpenMeteoDaily?) -> [WeatherDailyForecast] {
        guard let daily else {
            return []
        }

        let endIndex = min(daily.time.count, 7)
        return (0..<endIndex).compactMap { index in
            guard index < daily.temperature2mMin.count,
                  index < daily.temperature2mMax.count,
                  index < daily.weatherCode.count
            else {
                return nil
            }

            return WeatherDailyForecast(
                date: daily.time[index],
                minTemperature: daily.temperature2mMin[index],
                maxTemperature: daily.temperature2mMax[index],
                precipitationProbability: daily.precipitationProbabilityMax?[safe: index],
                condition: WeatherCondition.condition(for: daily.weatherCode[index])
            )
        }
    }
}

public enum WeatherForecastParsingError: LocalizedError {
    case missingCurrentWeather

    public var errorDescription: String? {
        switch self {
        case .missingCurrentWeather:
            return "天气响应缺少 current 数据"
        }
    }
}

private struct OpenMeteoForecastResponse: Decodable {
    let timezone: String?
    let current: OpenMeteoCurrent?
    let hourly: OpenMeteoHourly?
    let daily: OpenMeteoDaily?
}

private struct OpenMeteoCurrent: Decodable {
    let time: String
    let temperature2m: Double
    let apparentTemperature: Double?
    let relativeHumidity2m: Double?
    let precipitation: Double?
    let weatherCode: Int
    let windSpeed10m: Double?
    let isDay: Int?

    private enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case relativeHumidity2m = "relative_humidity_2m"
        case precipitation
        case weatherCode = "weather_code"
        case windSpeed10m = "wind_speed_10m"
        case isDay = "is_day"
    }
}

private struct OpenMeteoHourly: Decodable {
    let time: [String]
    let temperature2m: [Double]
    let weatherCode: [Int]
    let precipitationProbability: [Int]?

    private enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case weatherCode = "weather_code"
        case precipitationProbability = "precipitation_probability"
    }
}

private struct OpenMeteoDaily: Decodable {
    let time: [String]
    let weatherCode: [Int]
    let temperature2mMax: [Double]
    let temperature2mMin: [Double]
    let precipitationProbabilityMax: [Int]?

    private enum CodingKeys: String, CodingKey {
        case time
        case weatherCode = "weather_code"
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case precipitationProbabilityMax = "precipitation_probability_max"
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
