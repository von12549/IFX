using IFX.BuildingBlocks.Application.Events;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Registry.Application.Funds.Commands.DeleteFund;
using IFX.Modules.Registry.Application.Funds.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Domain.Entities;
using IFX.Modules.Registry.Domain.Enums;
using IFX.Modules.Registry.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Tests.Handlers;

public class DeleteFundCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IFundRepository> _funds = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ICommittedEventBuffer> _eventBuffer = new();
    private readonly Mock<ILogger<DeleteFundCommandHandler>> _logger = new();
    private readonly DeleteFundCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    public DeleteFundCommandHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _unitOfWork.Setup(u => u.Funds).Returns(_funds.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _handler = new DeleteFundCommandHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _eventBuffer.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WhenFundExists_ClosesFundAndPublishesEvent()
    {
        var fund = Fund.Create(TenantId, "FUND001", "Growth Fund", FundType.UCITS, "USD", new DateOnly(2024, 1, 1));
        _funds.Setup(r => r.GetByIdAsync(fund.Id, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(fund);
        _mapper.Setup(m => m.Map<FundDto>(fund)).Returns(new FundDto { FundCode = "FUND001" });

        var result = await _handler.Handle(new DeleteFundCommand(fund.Id), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        fund.Status.Should().Be(FundStatus.Closed);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
        _eventBuffer.Invocations.Should().BeEmpty();
    }

    [Fact]
    public async Task Handle_WhenFundNotFound_ReturnsFailure()
    {
        var missingId = Guid.NewGuid();
        _funds.Setup(r => r.GetByIdAsync(missingId, TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Fund?)null);

        var result = await _handler.Handle(new DeleteFundCommand(missingId), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
        _eventBuffer.Invocations.Should().BeEmpty();
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new DeleteFundCommand(Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }
}
