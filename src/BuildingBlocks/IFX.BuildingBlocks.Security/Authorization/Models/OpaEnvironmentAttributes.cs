using System.Text.Json.Serialization;

namespace IFX.BuildingBlocks.Security.Authorization.Models;

public class OpaEnvironmentAttributes
{
    [JsonPropertyName("ip")]
    public string? Ip { get; init; }

    [JsonPropertyName("network")]
    public string? Network { get; init; }

    [JsonPropertyName("time")]
    public string Time { get; init; } = DateTime.UtcNow.ToString("O");
}
