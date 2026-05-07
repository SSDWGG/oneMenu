namespace OneMenu.Core.Weather;

public enum WeatherServiceState
{
    Idle, WaitingForPermission, Locating, Loading, Loaded, Failed, PermissionDenied
}

public class WeatherServiceSnapshot
{
    public WeatherServiceState State { get; init; }
    public WeatherForecast? Forecast { get; init; }
    public string? ErrorMessage { get; init; }

    public static WeatherServiceSnapshot Create(WeatherServiceState state, WeatherForecast? forecast = null, string? error = null) =>
        new() { State = state, Forecast = forecast, ErrorMessage = error };
}

/// <summary>
/// Weather service that uses Windows Geolocator or a manual location.
/// Falls back to a default location (Beijing) if geolocation is unavailable.
/// </summary>
public class WeatherService : IDisposable
{
    private readonly OpenMeteoApiClient _api;
    private readonly TimeSpan _refreshInterval;
    private readonly HttpClient _http;

    private double? _latitude;
    private double? _longitude;
    private WeatherForecast? _latestForecast;
    private DateTime? _lastFetchAt;
    private CancellationTokenSource? _cts;

    public WeatherServiceSnapshot CurrentSnapshot { get; private set; } = WeatherServiceSnapshot.Create(WeatherServiceState.Idle);
    public event Action<WeatherServiceSnapshot>? OnSnapshotChanged;

    public WeatherService(TimeSpan? refreshInterval = null, HttpClient? http = null)
    {
        _http = http ?? new HttpClient();
        _api = new OpenMeteoApiClient(_http);
        _refreshInterval = refreshInterval ?? TimeSpan.FromMinutes(10);
    }

    /// <summary>
    /// Set a manual location (e.g., from user settings) and fetch weather.
    /// </summary>
    public async Task SetLocationAsync(double lat, double lon)
    {
        _latitude = lat;
        _longitude = lon;
        await FetchAsync(force: true);
    }

    /// <summary>
    /// Try to get location from Windows Geolocator. Falls back to Beijing.
    /// </summary>
    public async Task StartAsync()
    {
        // Default to Beijing if no GPS
        if (_latitude == null)
        {
            _latitude = 39.9042;
            _longitude = 116.4074;
        }

        await FetchAsync(force: true);
    }

    public async Task RefreshIfNeededAsync(bool force = false)
    {
        if (_latitude == null) return;

        if (!force && _lastFetchAt.HasValue &&
            (DateTime.UtcNow - _lastFetchAt.Value) < _refreshInterval)
            return;

        await FetchAsync(force);
    }

    private async Task FetchAsync(bool force)
    {
        if (_latitude == null || _longitude == null) return;

        try
        {
            UpdateSnapshot(WeatherServiceSnapshot.Create(WeatherServiceState.Loading, _latestForecast));
            var forecast = await _api.FetchAsync(_latitude.Value, _longitude.Value);

            _latestForecast = forecast;
            _lastFetchAt = DateTime.UtcNow;
            UpdateSnapshot(WeatherServiceSnapshot.Create(WeatherServiceState.Loaded, forecast));
        }
        catch (Exception ex)
        {
            UpdateSnapshot(WeatherServiceSnapshot.Create(WeatherServiceState.Failed, _latestForecast, ex.Message));
        }
    }

    private void UpdateSnapshot(WeatherServiceSnapshot snapshot)
    {
        CurrentSnapshot = snapshot;
        OnSnapshotChanged?.Invoke(snapshot);
    }

    public void Dispose()
    {
        _cts?.Cancel();
        _cts?.Dispose();
        _http?.Dispose();
    }
}
