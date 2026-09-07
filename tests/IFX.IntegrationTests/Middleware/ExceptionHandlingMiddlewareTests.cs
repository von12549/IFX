using System.Text.Json;
using FluentValidation;
using FluentValidation.Results;
using IFX.ApiHost.Middleware;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Moq;

namespace IFX.IntegrationTests.Middleware;

public sealed class ExceptionHandlingMiddlewareTests
{
    [Fact]
    public async Task Validation_exception_returns_structured_bad_request()
    {
        var exception = new ValidationException(
        [
            new ValidationFailure("Email", "Email is required."),
            new ValidationFailure("Email", "Email is invalid."),
            new ValidationFailure("Name", "Name is required.")
        ]);

        var (context, body, _) = await InvokeAsync(exception);

        context.Response.StatusCode.Should().Be(StatusCodes.Status400BadRequest);
        body.RootElement.GetProperty("error").GetString().Should().Be("One or more validation errors occurred.");
        body.RootElement.GetProperty("errors").GetProperty("Email").GetArrayLength().Should().Be(2);
        body.RootElement.GetProperty("errors").GetProperty("Name").GetArrayLength().Should().Be(1);
    }

    [Fact]
    public async Task Forbidden_exception_returns_forbidden()
    {
        var (context, _, _) = await InvokeAsync(new ForbiddenException("Denied."));

        context.Response.StatusCode.Should().Be(StatusCodes.Status403Forbidden);
    }

    [Fact]
    public async Task Concurrency_exception_returns_safe_conflict()
    {
        var internalException = new InvalidOperationException("database row detail");

        var (context, body, _) = await InvokeAsync(
            new ConcurrencyConflictException(typeof(TestOwner), internalException));

        context.Response.StatusCode.Should().Be(StatusCodes.Status409Conflict);
        body.RootElement.GetProperty("error").GetString().Should().NotContain("database row detail");
    }

    [Fact]
    public async Task Unexpected_exception_returns_safe_internal_server_error()
    {
        var (context, body, logger) = await InvokeAsync(
            new InvalidOperationException("secret connection detail"));

        context.Response.StatusCode.Should().Be(StatusCodes.Status500InternalServerError);
        body.RootElement.GetProperty("error").GetString().Should().NotContain("secret connection detail");
        logger.VerifyLog(LogLevel.Error, Times.Once());
    }

    [Fact]
    public async Task Cancellation_is_rethrown_and_not_logged_as_an_error()
    {
        var logger = new Mock<ILogger<ExceptionHandlingMiddleware>>();
        var middleware = new ExceptionHandlingMiddleware(
            _ => throw new OperationCanceledException(),
            logger.Object);

        Func<Task> act = () => middleware.InvokeAsync(new DefaultHttpContext());

        await act.Should().ThrowAsync<OperationCanceledException>();
        logger.VerifyLog(LogLevel.Error, Times.Never());
    }

    private static async Task<(
        DefaultHttpContext Context,
        JsonDocument Body,
        Mock<ILogger<ExceptionHandlingMiddleware>> Logger)> InvokeAsync(Exception exception)
    {
        var logger = new Mock<ILogger<ExceptionHandlingMiddleware>>();
        var middleware = new ExceptionHandlingMiddleware(_ => throw exception, logger.Object);
        var context = new DefaultHttpContext();
        context.Response.Body = new MemoryStream();

        await middleware.InvokeAsync(context);
        context.Response.Body.Position = 0;
        return (context, await JsonDocument.ParseAsync(context.Response.Body), logger);
    }

    private sealed class TestOwner : ITransactionOwner;
}

internal static class LoggerMockExtensions
{
    public static void VerifyLog<T>(this Mock<ILogger<T>> logger, LogLevel level, Times times) =>
        logger.Verify(
            item => item.Log(
                level,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((_, _) => true),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            times);
}
