using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Investors.Commands.UpdateInvestorAml;
using IFX.Modules.CRM.Application.Investors.DTOs;
using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Tests.Handlers.Investors;

public class UpdateInvestorAmlCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IInvestorRepository> _investors = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<UpdateInvestorAmlCommandHandler>> _logger = new();
    private readonly UpdateInvestorAmlCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid InvestorId = Guid.NewGuid();

    public UpdateInvestorAmlCommandHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _unitOfWork.Setup(u => u.Investors).Returns(_investors.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _mapper.Setup(m => m.Map<InvestorDto>(It.IsAny<Investor>())).Returns(new InvestorDto());

        _handler = new UpdateInvestorAmlCommandHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object, _authorizationService.Object, _logger.Object);
    }

    private UpdateInvestorAmlCommand MakeCommand(AmlStatus status = AmlStatus.Clear) =>
        new(InvestorId, status, "REF-001", false, null, "Salary", 0, 0, 0);

    [Fact]
    public async Task Handle_WithExistingInvestor_UpdatesAmlAndReturnsDto()
    {
        var investor = Investor.Create(TenantId, "INV001", "John Doe", PartyLegalStructure.Individual);
        _investors.Setup(r => r.GetByIdAsync(InvestorId, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(investor);

        var result = await _handler.Handle(MakeCommand(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        investor.AmlStatus.Should().Be(AmlStatus.Clear);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenInvestorNotFound_ReturnsFailure()
    {
        _investors.Setup(r => r.GetByIdAsync(InvestorId, TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Investor?)null);

        var result = await _handler.Handle(MakeCommand(), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(MakeCommand(), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }

    [Fact]
    public async Task Handle_BlockedStatus_UpdatesAmlStatusToBlocked()
    {
        var investor = Investor.Create(TenantId, "INV001", "John Doe", PartyLegalStructure.Individual);
        _investors.Setup(r => r.GetByIdAsync(InvestorId, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(investor);

        await _handler.Handle(MakeCommand(AmlStatus.Blocked), CancellationToken.None);

        investor.AmlStatus.Should().Be(AmlStatus.Blocked);
    }
}
