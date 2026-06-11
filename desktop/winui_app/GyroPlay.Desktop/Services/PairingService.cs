using QRCoder;
using System;
using System.IO;
using System.Security.Cryptography;
using System.Text.Json;

namespace GyroPlay.Desktop.Services;

public sealed record PairingCode(string Token, DateTimeOffset ExpiresAt, byte[] QrPngBytes);

public sealed class PairingService
{
    private const int UdpPort = 5005;
    private static readonly TimeSpan PairingTokenLifetime = TimeSpan.FromMinutes(5);
    private AppPaths _paths = new();

    public void Initialize(AppPaths paths)
    {
        _paths = paths;
    }

    public PairingCode Refresh(string localIpAddress)
    {
        var token = GeneratePairingToken();
        var expiresAt = DateTimeOffset.UtcNow.Add(PairingTokenLifetime);
        var payload = new
        {
            version = 1,
            type = "gyroplay_pairing",
            host = localIpAddress,
            port = UdpPort,
            pairing_token = token,
            expires_at = expiresAt.ToString("O"),
        };

        WritePairingFile(token, expiresAt);
        var payloadJson = JsonSerializer.Serialize(payload);
        using var generator = new QRCodeGenerator();
        using var data = generator.CreateQrCode(payloadJson, QRCodeGenerator.ECCLevel.Q);
        var qrCode = new PngByteQRCode(data);
        return new PairingCode(token, expiresAt, qrCode.GetGraphic(12));
    }

    private void WritePairingFile(string token, DateTimeOffset expiresAt)
    {
        _paths.EnsureAppDataDirectory();
        var json = JsonSerializer.Serialize(
            new { version = 1, pairing_token = token, expires_at = expiresAt.ToString("O") },
            new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(_paths.PairingFilePath, json);
    }

    private static string GeneratePairingToken()
    {
        Span<byte> bytes = stackalloc byte[4];
        RandomNumberGenerator.Fill(bytes);
        return Convert.ToHexString(bytes);
    }
}
