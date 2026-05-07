using System.Text.Json;

namespace OneMenu.Core.Preferences;

/// <summary>
/// JSON-file based preference store. Analogous to UserDefaults on macOS.
/// Stores a flat key-value dictionary at %APPDATA%\oneMenu\preferences.json.
/// </summary>
public class PreferencesStore
{
    private readonly string _filePath;
    private Dictionary<string, JsonElement> _values;
    private readonly JsonSerializerOptions _jsonOptions;

    public PreferencesStore(string? filePath = null)
    {
        _filePath = filePath
            ?? Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "oneMenu", "preferences.json");
        _values = [];
        _jsonOptions = new JsonSerializerOptions { WriteIndented = true };
        Load();
    }

    public string? GetString(string key, string? defaultValue = null)
    {
        if (_values.TryGetValue(key, out var element) &&
            element.ValueKind == JsonValueKind.String)
            return element.GetString() ?? defaultValue;
        return defaultValue;
    }

    public int GetInt(string key, int defaultValue = 0)
    {
        if (_values.TryGetValue(key, out var element) &&
            element.ValueKind == JsonValueKind.Number &&
            element.TryGetInt32(out var value))
            return value;
        return defaultValue;
    }

    public double GetDouble(string key, double defaultValue = 0.0)
    {
        if (_values.TryGetValue(key, out var element) &&
            element.ValueKind == JsonValueKind.Number &&
            element.TryGetDouble(out var value))
            return value;
        return defaultValue;
    }

    public bool GetBool(string key, bool defaultValue = false)
    {
        if (_values.TryGetValue(key, out var element))
        {
            if (element.ValueKind == JsonValueKind.True) return true;
            if (element.ValueKind == JsonValueKind.False) return false;
        }
        return defaultValue;
    }

    public DateTime? GetDateTime(string key)
    {
        var str = GetString(key);
        if (str != null && DateTime.TryParse(str, null,
                System.Globalization.DateTimeStyles.RoundtripKind, out var result))
            return result;
        return null;
    }

    public void Set(string key, string? value)
    {
        if (value == null)
            _values.Remove(key);
        else
            _values[key] = JsonSerializer.SerializeToElement(value);
        Save();
    }

    public void Set(string key, int value)
    {
        _values[key] = JsonSerializer.SerializeToElement(value);
        Save();
    }

    public void Set(string key, double value)
    {
        _values[key] = JsonSerializer.SerializeToElement(value);
        Save();
    }

    public void Set(string key, bool value)
    {
        _values[key] = JsonSerializer.SerializeToElement(value);
        Save();
    }

    public void Set(string key, DateTime value)
    {
        _values[key] = JsonSerializer.SerializeToElement(value.ToString("O"));
        Save();
    }

    public void Remove(string key)
    {
        _values.Remove(key);
        Save();
    }

    public bool HasKey(string key) => _values.ContainsKey(key);

    private void Load()
    {
        try
        {
            if (File.Exists(_filePath))
            {
                var json = File.ReadAllText(_filePath);
                _values = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(json)
                    ?? [];
            }
        }
        catch
        {
            _values = [];
        }
    }

    private void Save()
    {
        try
        {
            var dir = Path.GetDirectoryName(_filePath);
            if (dir != null && !Directory.Exists(dir))
                Directory.CreateDirectory(dir);

            var json = JsonSerializer.Serialize(_values, _jsonOptions);
            File.WriteAllText(_filePath, json);
        }
        catch
        {
            // best-effort persistence
        }
    }
}
