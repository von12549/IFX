namespace AuthSamples.Modules.Cognito.Application.DTOs;

public class UserActivityDto
{
    public Guid Id { get; init; }
    public string ActivityType { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public DateTime Timestamp { get; init; }
    public string IpAddress { get; init; } = string.Empty;
}
