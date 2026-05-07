import XCTest
@testable import CodexStatusCore

final class WeatherForecastTests: XCTestCase {
    func testParsesOpenMeteoForecast() throws {
        let json = """
        {
          "timezone": "Asia/Shanghai",
          "current": {
            "time": "2026-05-06T15:00",
            "temperature_2m": 22.4,
            "apparent_temperature": 23.1,
            "relative_humidity_2m": 71,
            "precipitation": 0.0,
            "weather_code": 2,
            "wind_speed_10m": 12.5,
            "is_day": 1
          },
          "hourly": {
            "time": [
              "2026-05-06T14:00",
              "2026-05-06T15:00",
              "2026-05-06T16:00",
              "2026-05-06T17:00"
            ],
            "temperature_2m": [21.9, 22.4, 22.1, 21.6],
            "weather_code": [1, 2, 61, 63],
            "precipitation_probability": [10, 15, 40, 60]
          },
          "daily": {
            "time": ["2026-05-06", "2026-05-07"],
            "weather_code": [2, 61],
            "temperature_2m_max": [24.0, 23.2],
            "temperature_2m_min": [18.5, 17.8],
            "precipitation_probability_max": [20, 70]
          }
        }
        """.data(using: .utf8)!

        let fetchedAt = Date(timeIntervalSince1970: 1_777_777_777)
        let forecast = try WeatherForecastParser.parse(data: json, fetchedAt: fetchedAt)

        XCTAssertEqual(forecast.fetchedAt, fetchedAt)
        XCTAssertEqual(forecast.timezone, "Asia/Shanghai")
        XCTAssertEqual(forecast.current.temperature, 22.4)
        XCTAssertEqual(forecast.current.apparentTemperature, 23.1)
        XCTAssertEqual(forecast.current.humidity, 71)
        XCTAssertEqual(forecast.current.condition.title, "少云")
        XCTAssertEqual(forecast.current.condition.symbolName, "cloud.sun.fill")

        XCTAssertEqual(forecast.hourly.map(\.time), [
            "2026-05-06T15:00",
            "2026-05-06T16:00",
            "2026-05-06T17:00"
        ])
        XCTAssertEqual(forecast.hourly[1].condition.title, "小雨")
        XCTAssertEqual(forecast.hourly[2].precipitationProbability, 60)

        XCTAssertEqual(forecast.daily.count, 2)
        XCTAssertEqual(forecast.daily[0].maxTemperature, 24.0)
        XCTAssertEqual(forecast.daily[1].condition.title, "小雨")
        XCTAssertEqual(forecast.daily[1].precipitationProbability, 70)
    }

    func testRequiresCurrentWeather() {
        let json = #"{"hourly":{"time":[],"temperature_2m":[],"weather_code":[]}}"#.data(using: .utf8)!

        XCTAssertThrowsError(try WeatherForecastParser.parse(data: json)) { error in
            XCTAssertEqual(error.localizedDescription, "天气响应缺少 current 数据")
        }
    }
}
