using System.Net;
using System.Text.Json;
using IFX.Platform.Authorization.Contracts.V1;
using IFX.Platform.Authorization.Infrastructure.Opa;
using IFX.Platform.Authorization.Runtime;
using Microsoft.Extensions.Options;

namespace IFX.Platform.Authorization.Tests;

public class AuthorizationTests
{
    private static EvaluationRequest Request(params ConditionSpec[] conditions) => new(
        new("user-1", "tenant-1", ["dept-1"], ["reader"], ["read"], false, [], "false"),
        new("user", "user-2", "tenant-1", "true", "user-2"), "read",
        new(null, null, "2026-09-12T00:00:00.0000000Z"), new("policy-v1", conditions.Length == 0
            ? [new("subject.tenant_id", ConditionOperator.Equals, ValueReference.Field, "resource.tenant_id")] : conditions));

    [Theory]
    [InlineData("{\"result\":{\"allow\":true}}", DecisionOutcome.Allow, "policy_allow")]
    [InlineData("{\"result\":{\"allow\":false}}", DecisionOutcome.Deny, "policy_deny")]
    [InlineData("{\"result\":{}}", DecisionOutcome.Indeterminate, "invalid_provider_response")]
    [InlineData("{\"result\":true}", DecisionOutcome.Indeterminate, "invalid_provider_response")]
    [InlineData("{\"result\":{\"allow\":\"true\"}}", DecisionOutcome.Indeterminate, "invalid_provider_response")]
    public async Task Wire_mapping_and_decision_normalization(string body, DecisionOutcome outcome, string reason)
    {
        JsonElement input = default;
        var handler = new Handler(async (message, _) =>
        {
            Assert.Equal("http://opa/v1/data/authz/common/abac_eval", message.RequestUri!.ToString());
            using var json = JsonDocument.Parse(await message.Content!.ReadAsStringAsync());
            input = json.RootElement.GetProperty("input").Clone();
            return new(HttpStatusCode.OK) { Content = new StringContent(body) };
        });
        var result = await Runtime(handler).EvaluateAsync(Request());
        Assert.Equal(outcome, result.Outcome);
        Assert.Equal(reason, result.ReasonCode);
        Assert.Equal("policy-v1", result.PolicyVersion);
        Assert.NotEqual(Guid.Empty, result.DecisionId);
        Assert.Equal("tenant-1", input.GetProperty("subject").GetProperty("tenant_id").GetString());
        Assert.Equal("user-2", input.GetProperty("resource").GetProperty("owner_id").GetString());
        Assert.Equal("field_ref", input.GetProperty("conditions")[0].GetProperty("right_type").GetString());
        Assert.Equal("equals", input.GetProperty("conditions")[0].GetProperty("operator").GetString());
    }

    [Theory]
    [InlineData("disabled")]
    [InlineData("status")]
    [InlineData("network")]
    [InlineData("malformed")]
    public async Task Technical_failure_never_grants_even_with_legacy_fail_open_setting(string scenario)
    {
        var calls = 0;
        var handler = new Handler((_, _) =>
        {
            calls++;
            if (scenario == "network") throw new HttpRequestException();
            return Task.FromResult(new HttpResponseMessage(scenario == "status" ? HttpStatusCode.ServiceUnavailable : HttpStatusCode.OK)
                { Content = new StringContent("not-json") });
        });
        var result = await Runtime(handler, scenario != "disabled").EvaluateAsync(Request());
        Assert.Equal(DecisionOutcome.Indeterminate, result.Outcome);
        Assert.Equal(scenario == "disabled" ? 0 : 1, calls);
    }

    [Theory]
    [InlineData("unknown")]
    [InlineData("missing-parameter")]
    [InlineData("unknown-right")]
    [InlineData("empty")]
    public async Task Invalid_snapshot_does_not_reach_provider(string failure)
    {
        var provider = new Mock<IConditionEvaluationProvider>(MockBehavior.Strict);
        var request = Request(new ConditionSpec(failure == "unknown" ? "resource.secret" : "subject.id", ConditionOperator.Equals,
            failure == "missing-parameter" ? ValueReference.Parameter : ValueReference.Field,
            failure == "unknown-right" ? "resource.secret" : "resource.id"));
        if (failure == "empty") request = request with { Policy = new("v1", []) };
        var result = await new AuthorizationRuntime(provider.Object).EvaluateAsync(request);
        Assert.Equal("invalid_policy", result.ReasonCode);
        provider.VerifyNoOtherCalls();
    }

    [Theory]
    [InlineData(ConditionOperator.Equals)]
    [InlineData(ConditionOperator.NotEquals)]
    [InlineData(ConditionOperator.In)]
    [InlineData(ConditionOperator.NotIn)]
    [InlineData(ConditionOperator.Contains)]
    [InlineData(ConditionOperator.Intersects)]
    public void Parameter_resolution_preserves_operator_and_supplied_value(ConditionOperator op)
    {
        var resolved = new ConditionParameterResolver().Resolve(new("v1",
            [new("subject.id", op, ValueReference.Parameter, "actor", "user-1")]));
        Assert.Equal(new ResolvedCondition("subject.id", op, ValueReference.Literal, "user-1"), Assert.Single(resolved));
    }

    [Fact]
    public async Task Caller_cancellation_propagates()
    {
        using var cancellation = new CancellationTokenSource();
        var handler = new Handler(async (_, ct) => { cancellation.Cancel(); await Task.Delay(-1, ct); return new(HttpStatusCode.OK); });
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => Runtime(handler).EvaluateAsync(Request(), cancellation.Token));
    }

    [Fact]
    public async Task Global_role_names_do_not_bypass_platform_evaluation()
    {
        var request = Request();
        request = request with { Subject = request.Subject with { GlobalRoles = ["PlatformAdmin"], IsGlobalAdmin = "true" } };
        var handler = new Handler((_, _) => Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            { Content = new StringContent("{\"result\":{\"allow\":false}}") }));
        Assert.Equal(DecisionOutcome.Deny, (await Runtime(handler).EvaluateAsync(request)).Outcome);
    }

    private static AuthorizationRuntime Runtime(Handler handler, bool enabled = true) => new(new OpaEvaluationProvider(
        new HttpClient(handler), Options.Create(new OpaOptions { BaseUrl = "http://opa", Enabled = enabled, FailClosed = false })));
    private sealed class Handler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> send) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) => send(request, ct);
    }
}
