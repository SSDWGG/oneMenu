using System.Net.Http.Json;
using System.Text.Json;

namespace OneMenu.Core.Weather;

public class OpenMeteoApiClient
{
    private readonly HttpClient _http;

    public OpenMeteoApiClient(HttpClient? http = null)
    {
        _http = http ?? new HttpClient();
        _http.Timeout = TimeSpan.FromSeconds(15);
    }

    public async Task<WeatherForecast> FetchAsync(double latitude, double longitude, CancellationToken ct = default)
    {
        var url = BuildUrl(latitude, longitude);
        var response = await _http.GetAsync(url, ct);
        response.EnsureSuccessStatusCode();
        var data = await response.Content.ReadAsByteArrayAsync(ct);
        return WeatherForecastParser.Parse(data);
    }

    private static string BuildUrl(double lat, double lon)
    {
        var latStr = lat.ToString("F4", System.Globalization.CultureInfo.InvariantCulture);
        var lonStr = lon.ToString("F4", System.Globalization.CultureInfo.InvariantCulture);

        return $"https://api.open-meteo.com/v1/forecast" +
               $"?latitude={latStr}&longitude={lonStr}" +
               $"&current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,is_day" +
               $"&hourly=temperature_2m,weather_code,precipitation_probability" +
               $"&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max" +
               $"&forecast_days=7&timezone=auto&temperature_unit=celsius&wind_speed_unit=kmh&precipitation_unit=mm";
    }
}
