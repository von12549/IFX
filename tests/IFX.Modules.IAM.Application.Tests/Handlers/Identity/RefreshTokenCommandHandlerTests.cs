using AutoMapper;
using IFX.Modules.IAM.Application.Identity.Commands.RefreshToken;
using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Application.Interfaces;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tests.Handlers.Identity;

public sealed class RefreshTokenCommandHandlerTests
{
    [Fact]
    public async Task Handle_WhenProviderReportsSuccessWithoutCompleteTokens_RejectsResponse()
    {
        var tokenLifecycle = new Mock<ITokenLifecycleService>();
        var accounts = new Mock<IExternalAccountService>();
        tokenLifecycle
            .Setup(x => x.RefreshTokenAsync("refresh-token", "subject"))
            .ReturnsAsync(new AuthTokenResult
            {
                Success = true,
                AccessToken = null,
                IdToken = "id-token",
                RefreshToken = "new-refresh-token"
            });

        var handler = new RefreshTokenCommandHandler(
            tokenLifecycle.Object,
            accounts.Object,
            Mock.Of<IUnitOfWork>(),
            Mock.Of<IMapper>(),
            Mock.Of<ILogger<RefreshTokenCommandHandler>>());

        var result = await handler.Handle(
            new RefreshTokenCommand("refresh-token", "subject"),
            CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Invalid token response");
        accounts.Verify(x => x.GetUserAsync(It.IsAny<string>()), Times.Never);
    }
}
