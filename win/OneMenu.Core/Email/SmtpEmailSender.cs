using System.Net;
using System.Net.Mail;
using System.Text.Json;

namespace OneMenu.Core.Email;

public record EmailMessage(string To, string Subject, string Body);

/// <summary>
/// Sends email via SMTP using System.Net.Mail.SmtpClient.
/// Replaces the macOS curl-based approach with native .NET SMTP.
/// Reads config from ~/.aistatus/email.json (same format as macOS version).
/// </summary>
public class SmtpEmailSender
{
    private readonly SmtpConfig _config;

    public SmtpEmailSender(string configPath)
    {
        _config = LoadConfig(configPath);
    }

    public async Task SendAsync(EmailMessage message, CancellationToken ct = default)
    {
        if (!_config.IsValid)
            throw new InvalidOperationException("邮件配置不完整：请检查 ~/.aistatus/email.json");

        using var client = new SmtpClient(_config.Host, _config.Port)
        {
            EnableSsl = _config.UseTls,
            DeliveryMethod = SmtpDeliveryMethod.Network,
            Credentials = new NetworkCredential(_config.Username, _config.Password),
            Timeout = 30_000
        };

        var mail = new MailMessage
        {
            From = new MailAddress(_config.From),
            Subject = message.Subject,
            Body = message.Body,
            IsBodyHtml = false
        };
        mail.To.Add(message.To);

        await client.SendMailAsync(mail, ct);
    }

    private static SmtpConfig LoadConfig(string path)
    {
        try
        {
            var json = File.ReadAllText(path);
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            return new SmtpConfig(
                Host: root.TryGetProperty("host", out var h) ? h.GetString() ?? "" : "",
                Port: root.TryGetProperty("port", out var p) && p.TryGetInt32(out var port) ? port : 587,
                UseTls: !root.TryGetProperty("useTls", out var tls) || tls.GetBoolean(),
                Username: root.TryGetProperty("username", out var u) ? u.GetString() ?? "" : "",
                Password: root.TryGetProperty("password", out var pw) ? pw.GetString() ?? "" : "",
                From: root.TryGetProperty("from", out var f) ? f.GetString() ?? "" : "");
        }
        catch
        {
            return SmtpConfig.Empty;
        }
    }

    private record SmtpConfig(string Host, int Port, bool UseTls, string Username, string Password, string From)
    {
        public static readonly SmtpConfig Empty = new("", 587, true, "", "", "");
        public bool IsValid => !string.IsNullOrEmpty(Host) && !string.IsNullOrEmpty(Username) && !string.IsNullOrEmpty(From);
    }
}
