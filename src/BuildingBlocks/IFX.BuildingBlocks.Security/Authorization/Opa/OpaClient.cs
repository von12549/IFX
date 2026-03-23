using System.Diagnostics;
using System.Text;
using System.Text.Json;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace IFX.BuildingBlocks.Security.Authorization.Opa;

public class OpaClient : IOpaPolicyClient
{
    private readonly HttpClient _httpClient;
    private readonly OpaOptions _options;
    private readonly ILogger<OpaClient> _logger;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower
    };

    public OpaClient(HttpClient httpClient, IOptions<OpaOptions> options, ILogger<OpaClient> logger)
    {
        _httpClient = httpClient;
        _options = options.Value;
        _logger = logger;
    }

    public async Task<OpaDecisionResult> EvaluateAsync(string decisionPath, object input, CancellationToken ct = default)
    {
        var url = $"{_options.BaseUrl.TrimEnd('/')}/v1/data/{decisionPath.TrimStart('/')}";
        var body = JsonSerializer.Serialize(new { input }, JsonOptions);

        _logger.LogDebug("OPA request: POST {Url}", url);
        var sw = Stopwatch.StartNew();

        try
        {
            using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            cts.CancelAfter(TimeSpan.FromSeconds(_options.TimeoutSeconds));

            var request = new HttpRequestMessage(HttpMethod.Post, url)
            {
                Content = new StringContent(body, Encoding.UTF8, "application/json")
            };

            var response = await _httpClient.SendAsync(request, cts.Token);
            sw.Stop();

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("OPA returned {StatusCode} for {Path} in {Ms}ms — treating as deny",
                    (int)response.StatusCode, decisionPath, sw.ElapsedMilliseconds);
                return FailOrDeny();
            }

            var json = await response.Content.ReadAsStringAsync(ct);
            var decision = JsonSerializer.Deserialize<OpaDecisionResponse>(json, JsonOptions);
            var allow = decision?.Result?.Allow ?? false;

            _logger.LogInformation("OPA decision for {Path}: {Decision} in {Ms}ms",
                decisionPath, allow ? "allow" : "deny", sw.ElapsedMilliseconds);

            return allow ? OpaDecisionResult.Allowed() : OpaDecisionResult.Denied();
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            sw.Stop();
            _logger.LogWarning("OPA request timed out for {Path} after {Ms}ms", decisionPath, sw.ElapsedMilliseconds);
            return FailOrDeny();
        }
        catch (Exception ex)
        {
            sw.Stop();
            _logger.LogError(ex, "OPA request failed for {Path}", decisionPath);
            return FailOrDeny();
        }
    }

    private OpaDecisionResult FailOrDeny() =>
        _options.FailClosed
            ? OpaDecisionResult.Denied("OPA unavailable — fail closed")
            : OpaDecisionResult.Allowed();
}
