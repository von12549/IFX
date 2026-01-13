namespace AuthSamples.Modules.Auth.Domain.ValueObjects;

public class DeviceInfo
{
    public string Browser { get; private set; } = string.Empty;
    public string OS { get; private set; } = string.Empty;
    public string DeviceType { get; private set; } = string.Empty;
    public bool IsBot { get; private set; }

    private DeviceInfo() { }

    public static DeviceInfo Parse(string userAgent)
    {
        if (string.IsNullOrWhiteSpace(userAgent))
        {
            return new DeviceInfo
            {
                Browser = "Unknown",
                OS = "Unknown",
                DeviceType = "Unknown",
                IsBot = false
            };
        }

        var deviceInfo = new DeviceInfo();

        // Simple bot detection
        deviceInfo.IsBot = userAgent.Contains("bot", StringComparison.OrdinalIgnoreCase) ||
                          userAgent.Contains("crawler", StringComparison.OrdinalIgnoreCase) ||
                          userAgent.Contains("spider", StringComparison.OrdinalIgnoreCase);

        // Browser detection
        if (userAgent.Contains("Edg"))
            deviceInfo.Browser = "Edge";
        else if (userAgent.Contains("Chrome"))
            deviceInfo.Browser = "Chrome";
        else if (userAgent.Contains("Safari") && !userAgent.Contains("Chrome"))
            deviceInfo.Browser = "Safari";
        else if (userAgent.Contains("Firefox"))
            deviceInfo.Browser = "Firefox";
        else
            deviceInfo.Browser = "Other";

        // OS detection (order matters - check mobile OS before desktop)
        if (userAgent.Contains("iPhone") || userAgent.Contains("iPad") || userAgent.Contains("iOS"))
            deviceInfo.OS = "iOS";
        else if (userAgent.Contains("Android"))
            deviceInfo.OS = "Android";
        else if (userAgent.Contains("Windows"))
            deviceInfo.OS = "Windows";
        else if (userAgent.Contains("Mac OS") || userAgent.Contains("Macintosh"))
            deviceInfo.OS = "macOS";
        else if (userAgent.Contains("Linux"))
            deviceInfo.OS = "Linux";
        else
            deviceInfo.OS = "Unknown";

        // Device type detection
        if (userAgent.Contains("Mobile") || userAgent.Contains("Android") || userAgent.Contains("iPhone"))
            deviceInfo.DeviceType = "Mobile";
        else if (userAgent.Contains("Tablet") || userAgent.Contains("iPad"))
            deviceInfo.DeviceType = "Tablet";
        else
            deviceInfo.DeviceType = "Desktop";

        return deviceInfo;
    }
}
