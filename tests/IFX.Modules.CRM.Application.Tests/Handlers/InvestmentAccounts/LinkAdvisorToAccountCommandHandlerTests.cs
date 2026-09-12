using IFX.Modules.CRM.Application.Ports.Authorization;
using IFX.BuildingBlocks.Security.Authorization;

using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.InvestmentAccounts.Commands.LinkAdvisorToInvestmentAccount;
using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Tests.Handlers.InvestmentAccounts;

public class LinkAdvisorToAccountCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IInvestmentAccountRepository> _accounts = new();
    private readonly Mock<IPartyRoleAssignmentRepository> _roleAssignments = new();
    private readonly Mock<IAdvisorInvestmentAccountLinkRepository> _advisorLinks = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<LinkAdvisorToInvestmentAccountCommandHandler>> _logger = new();
    private readonly LinkAdvisorToInvestmentAccountCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid AccountId = Guid.NewGuid();
    private static readonly Guid AdvisorId = Guid.NewGuid();
    private static readonly DateOnly Today = DateOnly.FromDateTime(DateTime.UtcNow);

    public LinkAdvisorToAccountCommandHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _unitOfWork.Setup(u => u.InvestmentAccounts).Returns(_accounts.Object);
        _unitOfWork.Setup(u => u.PartyRoleAssignments).Returns(_roleAssignments.Object);
        _unitOfWork.Setup(u => u.AdvisorInvestmentAccountLinks).Returns(_advisorLinks.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<ResourceAttributes>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _handler = new LinkAdvisorToInvestmentAccountCommandHandler(
            _unitOfWork.Object, _currentUser.Object, _authorizationService.Object, _logger.Object);
    }

    private void SetupValidAccount() =>
        _accounts.Setup(r => r.GetByIdAsync(AccountId, TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(InvestmentAccount.Create(TenantId, "ACC001", InvestmentAccountType.Individual));

    private void SetupAdvisorHasRole(bool hasRole = true) =>
        _roleAssignments.Setup(r => r.HasRoleAsync(AdvisorId, PartyFunctionalRole.AdvisorRep, TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(hasRole);

    [Fact]
    public async Task Handle_WithValidAdvisor_LinksAdvisorToAccount()
    {
        var command = new LinkAdvisorToInvestmentAccountCommand(AccountId, AdvisorId, Today, null);
        SetupValidAccount();
        SetupAdvisorHasRole();
        _advisorLinks.Setup(r => r.GetAsync(AdvisorId, AccountId, TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((AdvisorInvestmentAccountLink?)null);

        var result = await _handler.Handle(command, CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _advisorLinks.Verify(r => r.AddAsync(It.IsAny<AdvisorInvestmentAccountLink>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenAccountNotFound_ReturnsFailure()
    {
        var command = new LinkAdvisorToInvestmentAccountCommand(AccountId, AdvisorId, Today, null);
        _accounts.Setup(r => r.GetByIdAsync(AccountId, TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((InvestmentAccount?)null);

        var result = await _handler.Handle(command, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    public async Task Handle_WhenAdvisorLacksRole_ReturnsFailure()
    {
        var command = new LinkAdvisorToInvestmentAccountCommand(AccountId, AdvisorId, Today, null);
        SetupValidAccount();
        _roleAssignments.Setup(r => r.HasRoleAsync(It.IsAny<Guid>(), It.IsAny<PartyFunctionalRole>(), TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);

        var result = await _handler.Handle(command, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("advisory role");
    }

    [Fact]
    public async Task Handle_WhenAdvisorAlreadyLinked_ReturnsFailure()
    {
        var command = new LinkAdvisorToInvestmentAccountCommand(AccountId, AdvisorId, Today, null);
        SetupValidAccount();
        SetupAdvisorHasRole();
        var existingLink = AdvisorInvestmentAccountLink.Create(TenantId, AdvisorId, AccountId, Today);
        _advisorLinks.Setup(r => r.GetAsync(AdvisorId, AccountId, TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(existingLink);

        var result = await _handler.Handle(command, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("already linked");
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);
        var command = new LinkAdvisorToInvestmentAccountCommand(AccountId, AdvisorId, Today, null);

        var result = await _handler.Handle(command, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }
}
