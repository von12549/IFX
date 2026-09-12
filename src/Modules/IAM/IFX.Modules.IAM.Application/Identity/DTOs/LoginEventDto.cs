namespace IFX.Modules.IAM.Application.Identity.DTOs;

public class LoginEventDto
{
    public Guid Id { get; init; }
    public DateTimeOffset LoginTimestamp { get; init; }
    public bool Success { get; init; }
    public string? FailureReason { get; init; }
    public string IpAddress { get; init; } = string.Empty;
    public string DeviceBrowser { get; init; } = string.Empty;
    public string DeviceOS { get; init; } = string.Empty;
}
