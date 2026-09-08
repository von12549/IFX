using IFX.BuildingBlocks.Application.Events;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Registry.Application.FundClasses.Commands.CreateClass;
using IFX.Modules.Registry.Application.FundClasses.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Domain.Entities;
using IFX.Modules.Registry.Domain.Enums;
using IFX.Modules.Registry.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Tests.Handlers;

public class CreateClassCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IFundRepository> _funds = new();
    private readonly Mock<IFundClassRepository> _fundClasses = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ICommittedEventBuffer> _eventBuffer = new();
    private readonly Mock<ILogger<CreateClassCommandHandler>> _logger = new();
    private readonly CreateClassCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid FundId = Guid.NewGuid();
    private static readonly CreateClassCommand ValidCommand = new(
        FundId, "CLASS-A", "Class A", "USD", NavFrequency.Daily,
        null, null, null);

    public CreateClassCommandHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _unitOfWork.Setup(u => u.Funds).Returns(_funds.Object);
        _unitOfWork.Setup(u => u.FundClasses).Returns(_fundClasses.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        var fund = Fund.Create(TenantId, "FUND001", "Growth Fund", FundType.UCITS, "USD", new DateOnly(2024, 1, 1));
        _funds.Setup(r => r.GetByIdAsync(FundId, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(fund);
        _fundClasses.Setup(r => r.CodeExistsAsync(It.IsAny<string>(), FundId, It.IsAny<CancellationToken>())).ReturnsAsync(false);

        _handler = new CreateClassCommandHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _eventBuffer.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithNewCode_CreatesClassAndPublishesEvent()
    {
        _mapper.Setup(m => m.Map<FundClassDto>(It.IsAny<FundClass>()))
            .Returns(new FundClassDto { ClassCode = "CLASS-A" });

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.ClassCode.Should().Be("CLASS-A");
        _fundClasses.Verify(r => r.AddAsync(It.IsAny<FundClass>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
        _eventBuffer.Invocations.Should().BeEmpty();
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
        _fundClasses.Verify(r => r.AddAsync(It.IsAny<FundClass>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenFundNotFound_ReturnsFailure()
    {
        _funds.Setup(r => r.GetByIdAsync(FundId, TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Fund?)null);

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Fund not found");
        _fundClasses.Verify(r => r.AddAsync(It.IsAny<FundClass>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenClassCodeAlreadyExists_ReturnsFailure()
    {
        _fundClasses.Setup(r => r.CodeExistsAsync("CLASS-A", FundId, It.IsAny<CancellationToken>())).ReturnsAsync(true);

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("CLASS-A");
        _fundClasses.Verify(r => r.AddAsync(It.IsAny<FundClass>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_SetsCreatedByFromCurrentUser()
    {
        var userId = Guid.NewGuid();
        _currentUser.Setup(c => c.UserId).Returns(userId);
        FundClass? captured = null;
        _fundClasses.Setup(r => r.AddAsync(It.IsAny<FundClass>(), It.IsAny<CancellationToken>()))
            .Callback<FundClass, CancellationToken>((fc, _) => captured = fc)
            .Returns(Task.CompletedTask);

        await _handler.Handle(ValidCommand, CancellationToken.None);

        captured.Should().NotBeNull();
        captured!.CreatedBy.Should().Be(userId);
    }
}
