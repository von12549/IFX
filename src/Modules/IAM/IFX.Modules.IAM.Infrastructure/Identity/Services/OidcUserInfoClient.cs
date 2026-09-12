using System.Net.Http.Headers;
using System.Text.Json;
using IFX.Modules.IAM.Application.Identity.Ports;

namespace IFX.Modules.IAM.Infrastructure.Identity.Services;

internal sealed class OidcUserInfoClient(IHttpClientFactory httpClientFactory) : IOidcUserInfoClient
{
    public async Task<OidcUserInfo?> GetAsync(
        string endpoint,
        string accessToken,
        CancellationToken cancellationToken = default)
    {
        var client = httpClientFactory.CreateClient("OidcUserInfo");
        using var request = new HttpRequestMessage(HttpMethod.Get, endpoint);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        using var response = await client.SendAsync(request, cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        var root = document.RootElement;

        return new OidcUserInfo(
            ReadString(root, "email"),
            ReadString(root, "given_name"),
            ReadString(root, "family_name"),
            ReadBoolean(root, "email_verified"));
    }

    private static string? ReadString(JsonElement root, string name) =>
        root.TryGetProperty(name, out var property) && property.ValueKind == JsonValueKind.String
            ? property.GetString()
            : null;

    private static bool ReadBoolean(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out var property))
        {
            return false;
        }

        return property.ValueKind switch
        {
            JsonValueKind.True => true,
            JsonValueKind.String => bool.TryParse(property.GetString(), out var value) && value,
            _ => false
        };
    }
}
