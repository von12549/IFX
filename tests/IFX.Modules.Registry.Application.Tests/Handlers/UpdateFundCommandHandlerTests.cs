using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Registry.Application.Funds.Commands.UpdateFund;
using IFX.Modules.Registry.Application.Funds.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Domain.Entities;
using IFX.Modules.Registry.Domain.Enums;
using IFX.Modules.Registry.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Tests.Handlers;

public class UpdateFundCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IFundRepository> _funds = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<UpdateFundCommandHandler>> _logger = new();
    private readonly UpdateFundCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly UpdateFundCommand ValidCommand = new(
        Guid.NewGuid(), "Updated Fund", FundType.AIF, "EUR");

    public UpdateFundCommandHandlerTests()
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

        _handler = new UpdateFundCommandHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WhenFundExists_UpdatesAndReturnsDto()
    {
        var fund = Fund.Create(TenantId, "FUND001", "Growth Fund", FundType.UCITS, "USD", new DateOnly(2024, 1, 1));
        _funds.Setup(r => r.GetByIdAsync(ValidCommand.FundId, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(fund);
        _mapper.Setup(m => m.Map<FundDto>(fund)).Returns(new FundDto { FundName = "Updated Fund" });

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        fund.FundName.Should().Be("Updated Fund");
        fund.FundType.Should().Be(FundType.AIF);
        fund.BaseCurrency.Should().Be("EUR");
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenFundNotFound_ReturnsFailure()
    {
        _funds.Setup(r => r.GetByIdAsync(It.IsAny<Guid>(), TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Fund?)null);

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }

    [Fact]
    public async Task Handle_WithProductId_SetsProductIdOnFund()
    {
        var fund = Fund.Create(TenantId, "FUND001", "Growth Fund", FundType.UCITS, "USD", new DateOnly(2024, 1, 1));
        var productId = Guid.NewGuid();
        var command = new UpdateFundCommand(ValidCommand.FundId, "Updated Fund", FundType.AIF, "EUR", productId);
        _funds.Setup(r => r.GetByIdAsync(command.FundId, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(fund);

        var result = await _handler.Handle(command, CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        fund.ProductId.Should().Be(productId);
    }

    [Fact]
    public async Task Handle_WithClearProduct_RemovesProductIdFromFund()
    {
        var fund = Fund.Create(TenantId, "FUND001", "Growth Fund", FundType.UCITS, "USD", new DateOnly(2024, 1, 1));
        fund.SetProduct(Guid.NewGuid());
        var command = new UpdateFundCommand(ValidCommand.FundId, "Updated Fund", FundType.AIF, "EUR", ClearProduct: true);
        _funds.Setup(r => r.GetByIdAsync(command.FundId, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(fund);

        var result = await _handler.Handle(command, CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        fund.ProductId.Should().BeNull();
    }
}
