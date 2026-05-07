namespace OneMenu.Core.Email;

public class EmailNotificationConfig
{
    private const string ConfigFileName = ".aistatus/email.json";

    public static string ConfigFilePath =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ConfigFileName);

    public bool Exists => File.Exists(ConfigFilePath);

    // Phase 5 will implement full SMTP email sending via SmtpClient
    // For now, this is a minimal skeleton matching the macOS config path
}
