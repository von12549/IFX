using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Registry.Application.Funds.Commands.CreateFund;
using IFX.Modules.Registry.Application.Funds.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Domain.Entities;
using IFX.Modules.Registry.Domain.Enums;
using IFX.Modules.Registry.Domain.Repositories;
using IFX.Platform.Messaging.Abstractions;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Tests.Handlers;

public class CreateFundCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IFundRepository> _funds = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<IIntegrationEventBus> _eventBus = new();
    private readonly Mock<ILogger<CreateFundCommandHandler>> _logger = new();
    private readonly CreateFundCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly CreateFundCommand ValidCommand = new("FUND001", "Growth Fund", FundType.UCITS, "USD", new DateOnly(2024, 1, 1));

    public CreateFundCommandHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _unitOfWork.Setup(u => u.Funds).Returns(_funds.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _eventBus
            .Setup(e => e.PublishAsync(It.IsAny<IIntegrationEvent>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _handler = new CreateFundCommandHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _eventBus.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithNewCode_CreatesFundAndReturnsDto()
    {
        _funds.Setup(r => r.CodeExistsAsync("FUND001", TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);
        _mapper.Setup(m => m.Map<FundDto>(It.IsAny<Fund>())).Returns(new FundDto { FundCode = "FUND001" });

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.FundCode.Should().Be("FUND001");
        _funds.Verify(r => r.AddAsync(It.IsAny<Fund>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
        _eventBus.Verify(e => e.PublishAsync(It.IsAny<IIntegrationEvent>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenCodeAlreadyExists_ReturnsFailure()
    {
        _funds.Setup(r => r.CodeExistsAsync("FUND001", TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(true);

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("FUND001");
        _funds.Verify(r => r.AddAsync(It.IsAny<Fund>(), It.IsAny<CancellationToken>()), Times.Never);
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
    public async Task Handle_SetsCreatedByFromCurrentUser()
    {
        var userId = Guid.NewGuid();
        _currentUser.Setup(c => c.UserId).Returns(userId);
        _funds.Setup(r => r.CodeExistsAsync(It.IsAny<string>(), TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);
        Fund? capturedFund = null;
        _funds.Setup(r => r.AddAsync(It.IsAny<Fund>(), It.IsAny<CancellationToken>()))
            .Callback<Fund, CancellationToken>((f, _) => capturedFund = f)
            .Returns(Task.CompletedTask);

        await _handler.Handle(ValidCommand, CancellationToken.None);

        capturedFund.Should().NotBeNull();
        capturedFund!.CreatedBy.Should().Be(userId);
    }

    [Fact]
    public async Task Handle_WithProductId_SetsProductIdOnFund()
    {
        var productId = Guid.NewGuid();
        var command = ValidCommand with { ProductId = productId };
        _funds.Setup(r => r.CodeExistsAsync(It.IsAny<string>(), TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);
        Fund? captured = null;
        _funds.Setup(r => r.AddAsync(It.IsAny<Fund>(), It.IsAny<CancellationToken>()))
            .Callback<Fund, CancellationToken>((f, _) => captured = f)
            .Returns(Task.CompletedTask);

        await _handler.Handle(command, CancellationToken.None);

        captured.Should().NotBeNull();
        captured!.ProductId.Should().Be(productId);
    }

    [Fact]
    public async Task Handle_WithoutProductId_LeavesProductIdNull()
    {
        _funds.Setup(r => r.CodeExistsAsync(It.IsAny<string>(), TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);
        Fund? captured = null;
        _funds.Setup(r => r.AddAsync(It.IsAny<Fund>(), It.IsAny<CancellationToken>()))
            .Callback<Fund, CancellationToken>((f, _) => captured = f)
            .Returns(Task.CompletedTask);

        await _handler.Handle(ValidCommand, CancellationToken.None);

        captured.Should().NotBeNull();
        captured!.ProductId.Should().BeNull();
    }
}
