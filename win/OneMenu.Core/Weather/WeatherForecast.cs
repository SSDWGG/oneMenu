using System.Text.Json;

namespace OneMenu.Core.Weather;

public record WeatherCondition(int Code, string Title, string Symbol)
{
    public static WeatherCondition For(int code, bool isDay = true) => code switch
    {
        0 => new(code, "晴", isDay ? "☀️" : "🌙"),
        1 or 2 => new(code, "少云", isDay ? "⛅" : "🌤"),
        3 => new(code, "多云", "☁️"),
        45 or 48 => new(code, "雾", "🌫"),
        51 or 53 or 55 or 56 or 57 => new(code, "毛毛雨", "🌧"),
        61 => new(code, "小雨", "🌧"),
        63 => new(code, "中雨", "🌧"),
        65 or 80 or 81 or 82 => new(code, "大雨", "⛈"),
        66 or 67 => new(code, "冻雨", "🌨"),
        71 or 73 or 75 or 77 or 85 or 86 => new(code, "雪", "❄️"),
        95 or 96 or 99 => new(code, "雷雨", "🌩"),
        _ => new(code, "天气", "☁️")
    };
}

public record WeatherCurrent(
    string Time,
    double Temperature,
    double? ApparentTemperature,
    double? Humidity,
    double? Precipitation,
    double? WindSpeed,
    WeatherCondition Condition);

public record WeatherHourlyForecast(
    string Time,
    double Temperature,
    int? PrecipitationProbability,
    WeatherCondition Condition);

public record WeatherDailyForecast(
    string Date,
    double MinTemperature,
    double MaxTemperature,
    int? PrecipitationProbability,
    WeatherCondition Condition);

public record WeatherForecast(
    DateTime FetchedAt,
    string? Timezone,
    WeatherCurrent Current,
    List<WeatherHourlyForecast> Hourly,
    List<WeatherDailyForecast> Daily);

public static class WeatherForecastParser
{
    public static WeatherForecast Parse(byte[] data, DateTime? fetchedAt = null)
    {
        var doc = JsonDocument.Parse(data);
        var root = doc.RootElement;

        if (!root.TryGetProperty("current", out var currentEl))
            throw new InvalidOperationException("天气响应缺少 current 数据");

        var timezone = root.TryGetProperty("timezone", out var tz) ? tz.GetString() : null;
        var isDay = currentEl.TryGetProperty("is_day", out var isd) && isd.GetInt32() != 0;

        var current = new WeatherCurrent(
            Time: currentEl.GetProperty("time").GetString()!,
            Temperature: currentEl.GetProperty("temperature_2m").GetDouble(),
            ApparentTemperature: currentEl.TryGetPropertyAsDouble("apparent_temperature"),
            Humidity: currentEl.TryGetPropertyAsDouble("relative_humidity_2m"),
            Precipitation: currentEl.TryGetPropertyAsDouble("precipitation"),
            WindSpeed: currentEl.TryGetPropertyAsDouble("wind_speed_10m"),
            Condition: WeatherCondition.For((int)currentEl.GetProperty("weather_code").GetDouble(), isDay));

        var hourly = ParseHourly(root, currentEl);
        var daily = ParseDaily(root);

        return new WeatherForecast(fetchedAt ?? DateTime.UtcNow, timezone, current, hourly, daily);
    }

    private static List<WeatherHourlyForecast> ParseHourly(JsonElement root, JsonElement current)
    {
        var result = new List<WeatherHourlyForecast>();
        if (!root.TryGetProperty("hourly", out var hourly)) return result;

        var times = hourly.GetProperty("time").EnumerateArray().Select(e => e.GetString()!).ToArray();
        var temps = hourly.GetProperty("temperature_2m").EnumerateArray().Select(e => e.GetDouble()).ToArray();
        var codes = hourly.GetProperty("weather_code").EnumerateArray().Select(e => (int)e.GetDouble()).ToArray();
        var precipProbs = hourly.TryGetProperty("precipitation_probability", out var pp)
            ? pp.EnumerateArray().Select(e => (int?)e.GetDouble()).ToArray()
            : new int?[times.Length];

        var currentTime = current.GetProperty("time").GetString()!;
        var startIdx = Array.FindIndex(times, t => string.Compare(t, currentTime) >= 0);
        if (startIdx < 0) startIdx = 0;

        var endIdx = Math.Min(times.Length, startIdx + 8);
        for (var i = startIdx; i < endIdx; i++)
        {
            if (i >= temps.Length || i >= codes.Length) continue;
            result.Add(new WeatherHourlyForecast(
                times[i], Math.Round(temps[i], 1),
                i < precipProbs.Length ? precipProbs[i] : null,
                WeatherCondition.For(codes[i])));
        }

        return result;
    }

    private static List<WeatherDailyForecast> ParseDaily(JsonElement root)
    {
        var result = new List<WeatherDailyForecast>();
        if (!root.TryGetProperty("daily", out var daily)) return result;

        var times = daily.GetProperty("time").EnumerateArray().Select(e => e.GetString()!).ToArray();
        var mins = daily.GetProperty("temperature_2m_min").EnumerateArray().Select(e => e.GetDouble()).ToArray();
        var maxes = daily.GetProperty("temperature_2m_max").EnumerateArray().Select(e => e.GetDouble()).ToArray();
        var codes = daily.GetProperty("weather_code").EnumerateArray().Select(e => (int)e.GetDouble()).ToArray();
        var precipProbs = daily.TryGetProperty("precipitation_probability_max", out var pp)
            ? pp.EnumerateArray().Select(e => (int?)e.GetDouble()).ToArray()
            : new int?[times.Length];

        for (var i = 0; i < Math.Min(times.Length, 7); i++)
        {
            if (i >= mins.Length || i >= maxes.Length || i >= codes.Length) continue;
            result.Add(new WeatherDailyForecast(
                times[i], Math.Round(mins[i], 1), Math.Round(maxes[i], 1),
                i < precipProbs.Length ? precipProbs[i] : null,
                WeatherCondition.For(codes[i])));
        }

        return result;
    }
}

internal static class JsonElementExtensions
{
    public static double? TryGetPropertyAsDouble(this JsonElement element, string name) =>
        element.TryGetProperty(name, out var v) && v.ValueKind != JsonValueKind.Null ? v.GetDouble() : null;
}
