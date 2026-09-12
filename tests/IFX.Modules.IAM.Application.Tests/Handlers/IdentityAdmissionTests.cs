using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Application.Identity.Ports;
using IFX.Modules.IAM.Application.Identity.Queries.GetOrProvisionUser;
using IFX.Modules.IAM.Application.Identity.Commands.ProvisionSsoUser;
using IFX.Modules.IAM.Application.Identity.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Identity;
using IFX.Modules.IAM.Domain.Users;
using MediatR;
using Microsoft.Extensions.Logging.Abstractions;

namespace IFX.Modules.IAM.Application.Tests.Handlers;

public sealed class IdentityAdmissionTests
{
    [Theory]
    [InlineData(true, true, true)]
    [InlineData(false, true, false)]
    [InlineData(true, false, false)]
    public async Task Existing_identity_requires_enabled_issuer_and_active_local_account(bool enabled, bool active, bool expected)
    {
        var idp = Idp.Create("test", "https://issuer.example", "https://issuer.example", "", "", enabled: enabled);
        var user = User.Create("test-user", active);
        var work = new Mock<IUnitOfWork> { DefaultValue = DefaultValue.Mock };
        work.Setup(w => w.Idps.GetEnabledByIssuerAsync(idp.Issuer, It.IsAny<CancellationToken>())).ReturnsAsync(enabled ? idp : null);
        work.Setup(w => w.Users.GetByIssuerAndSubjectWithPermissionsAsync(idp.Issuer, "subject", It.IsAny<CancellationToken>())).ReturnsAsync(user);
        var mediator = new Mock<IMediator>(MockBehavior.Strict);
        var handler = new GetOrProvisionUserQueryHandler(work.Object, mediator.Object, Mock.Of<IOidcDiscoveryService>(), Mock.Of<IOidcUserInfoClient>(), NullLogger<GetOrProvisionUserQueryHandler>.Instance);
        var result = await handler.Handle(new(idp.Issuer, "subject", "test-token", false, idp.Id, idp.IdpType), default);
        Assert.Equal(expected, result.IsSuccess);
        mediator.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task Concurrent_provisioning_reuses_only_the_same_verified_identity()
    {
        var idp = Idp.Create("test", "https://issuer.example", "https://issuer.example", "", "");
        var created = User.Create("new user", true);
        var work = new Mock<IUnitOfWork> { DefaultValue = DefaultValue.Mock };
        work.Setup(w => w.Idps.GetEnabledByIssuerAsync(idp.Issuer, It.IsAny<CancellationToken>())).ReturnsAsync(idp);
        work.SetupSequence(w => w.Users.GetByIssuerAndSubjectWithPermissionsAsync(idp.Issuer, "subject", It.IsAny<CancellationToken>()))
            .ReturnsAsync((User?)null).ReturnsAsync(created);
        var discovery = new Mock<IOidcDiscoveryService>();
        discovery.Setup(d => d.GetDiscoveryDocumentAsync(idp.Issuer, It.IsAny<CancellationToken>())).ReturnsAsync(new OidcDiscoveryDocument());
        var mediator = new Mock<IMediator>();
        mediator.Setup(m => m.Send(It.Is<ProvisionSsoUserCommand>(command => command.Issuer == idp.Issuer && command.Subject == "subject"), It.IsAny<CancellationToken>()))
            .ReturnsAsync(Result<ProvisionSsoUserResponse>.Failure("concurrent unique identity"));
        var handler = new GetOrProvisionUserQueryHandler(work.Object, mediator.Object, discovery.Object, Mock.Of<IOidcUserInfoClient>(), NullLogger<GetOrProvisionUserQueryHandler>.Instance);
        var result = await handler.Handle(new(idp.Issuer, "subject", "test-token", true, idp.Id, idp.IdpType), default);
        Assert.True(result.IsSuccess);
        Assert.Equal(created.Id, result.Value!.UserId);
        Assert.False(result.Value.WasProvisioned);
    }

    [Fact]
    public async Task Mismatched_userinfo_subject_cannot_provision_or_merge_identity()
    {
        var idp = Idp.Create("test", "https://issuer.example", "https://issuer.example", "", "");
        var work = new Mock<IUnitOfWork> { DefaultValue = DefaultValue.Mock };
        work.Setup(w => w.Idps.GetEnabledByIssuerAsync(idp.Issuer, It.IsAny<CancellationToken>())).ReturnsAsync(idp);
        var discovery = new Mock<IOidcDiscoveryService>();
        discovery.Setup(d => d.GetDiscoveryDocumentAsync(idp.Issuer, It.IsAny<CancellationToken>())).ReturnsAsync(new OidcDiscoveryDocument { UserInfoEndpoint = "https://issuer.example/userinfo" });
        var userinfo = new Mock<IOidcUserInfoClient>();
        userinfo.Setup(u => u.GetAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new IFX.Modules.IAM.Application.Identity.Ports.OidcUserInfo("same@example.test", "", "", true, "other-subject"));
        var mediator = new Mock<IMediator>(MockBehavior.Strict);
        var handler = new GetOrProvisionUserQueryHandler(work.Object, mediator.Object, discovery.Object, userinfo.Object, NullLogger<GetOrProvisionUserQueryHandler>.Instance);
        var result = await handler.Handle(new(idp.Issuer, "subject", "test-token", true, idp.Id, idp.IdpType), default);
        Assert.False(result.IsSuccess);
        mediator.VerifyNoOtherCalls();
    }
}
