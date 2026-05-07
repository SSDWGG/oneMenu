using OneMenu.Core.Preferences;

namespace OneMenu.Tests;

public class PreferencesStoreTests : IDisposable
{
    private readonly string _tempFile;

    public PreferencesStoreTests()
    {
        _tempFile = Path.Combine(Path.GetTempPath(), $"oneMenu_prefs_{Guid.NewGuid():N}.json");
    }

    public void Dispose()
    {
        if (File.Exists(_tempFile))
            File.Delete(_tempFile);
    }

    [Fact]
    public void GetString_UnsetKey_ReturnsDefault()
    {
        var store = new PreferencesStore(_tempFile);
        Assert.Null(store.GetString("nonexistent"));
        Assert.Equal("fallback", store.GetString("nonexistent", "fallback"));
    }

    [Fact]
    public void SetAndGet_String_Roundtrips()
    {
        var store = new PreferencesStore(_tempFile);
        store.Set("key1", "hello");
        Assert.Equal("hello", store.GetString("key1"));
    }

    [Fact]
    public void SetAndGet_Int_Roundtrips()
    {
        var store = new PreferencesStore(_tempFile);
        store.Set("num", 42);
        Assert.Equal(42, store.GetInt("num"));
    }

    [Fact]
    public void SetAndGet_Bool_Roundtrips()
    {
        var store = new PreferencesStore(_tempFile);
        store.Set("enabled", true);
        Assert.True(store.GetBool("enabled"));
        store.Set("enabled", false);
        Assert.False(store.GetBool("enabled"));
    }

    [Fact]
    public void SetAndGet_Double_Roundtrips()
    {
        var store = new PreferencesStore(_tempFile);
        store.Set("pi", 3.14);
        Assert.Equal(3.14, store.GetDouble("pi"), 3);
    }

    [Fact]
    public void Remove_KeyNoLongerExists()
    {
        var store = new PreferencesStore(_tempFile);
        store.Set("temp", "value");
        Assert.True(store.HasKey("temp"));
        store.Remove("temp");
        Assert.False(store.HasKey("temp"));
        Assert.Null(store.GetString("temp"));
    }

    [Fact]
    public void Persistence_SurvivesNewInstance()
    {
        var store1 = new PreferencesStore(_tempFile);
        store1.Set("persist", 100);

        var store2 = new PreferencesStore(_tempFile);
        Assert.Equal(100, store2.GetInt("persist"));
    }
}
