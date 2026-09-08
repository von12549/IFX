using System.Net;
using System.Net.Http.Json;
using FluentValidation;
using FluentValidation.Results;
using IFX.ApiHost.Middleware;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.IntegrationTests.Fixtures;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.IntegrationTests.Middleware;

public sealed class ExceptionHandlingHttpEndToEndTests : IDisposable
{
    private readonly Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;

    public ExceptionHandlingHttpEndToEndTests()
    {
        var root = new CustomWebApplicationFactory();
        _factory = root.WithWebHostBuilder(builder => builder.ConfigureServices(services =>
            services.AddSingleton<IStartupFilter, ExceptionProbeStartupFilter>()));
        _client = _factory.CreateClient(new Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });
    }

    [Fact]
    public async Task Real_ApiHost_returns_structured_400_for_validation_exception()
    {
        var response = await _client.GetAsync("/__g01/errors/validation");
        var body = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        body!.Errors.Should().ContainKey("Email");
        body.Errors!["Email"].Should().ContainSingle().Which.Should().Be("Invalid value.");
        body.ErrorCode.Should().Be("validation_failed");
        Guid.TryParseExact(body.CorrelationId, "D", out _).Should().BeTrue();
    }

    [Fact]
    public async Task Real_ApiHost_returns_403_for_forbidden_exception()
    {
        var response = await _client.GetAsync("/__g01/errors/forbidden");

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Real_ApiHost_returns_safe_500_for_unexpected_exception()
    {
        var response = await _client.GetAsync("/__g01/errors/unexpected");
        var body = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        response.StatusCode.Should().Be(HttpStatusCode.InternalServerError);
        body!.Error.Should().NotContain("secret database detail");
    }

    public void Dispose()
    {
        _client.Dispose();
        _factory.Dispose();
    }

    private sealed class ExceptionProbeStartupFilter : IStartupFilter
    {
        public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next) => app =>
        {
            next(app);
            app.Map("/__g01/errors/validation", branch => branch.Run(_ =>
                throw new ValidationException([new ValidationFailure("Email", "Email is required.")])));
            app.Map("/__g01/errors/forbidden", branch => branch.Run(_ =>
                throw new ForbiddenException("Denied by G01 probe.")));
            app.Map("/__g01/errors/unexpected", branch => branch.Run(_ =>
                throw new InvalidOperationException("secret database detail")));
        };
    }
}
