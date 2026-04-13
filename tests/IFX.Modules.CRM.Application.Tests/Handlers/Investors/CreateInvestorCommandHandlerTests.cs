using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Investors.Commands.CreateInvestor;
using IFX.Modules.CRM.Application.Investors.DTOs;
using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Platform.Messaging.Abstractions;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Tests.Handlers.Investors;

public class CreateInvestorCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IInvestorRepository> _investors = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<IIntegrationEventBus> _eventBus = new();
    private readonly Mock<ILogger<CreateInvestorCommandHandler>> _logger = new();
    private readonly CreateInvestorCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly CreateInvestorCommand ValidCommand = new("INV001", "John Doe", PartyLegalStructure.Individual);

    public CreateInvestorCommandHandlerTests()
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
        _eventBus
            .Setup(e => e.PublishAsync(It.IsAny<IIntegrationEvent>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _handler = new CreateInvestorCommandHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _eventBus.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithNewCode_CreatesInvestorAndReturnsDto()
    {
        _investors.Setup(r => r.CodeExistsAsync("INV001", TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);
        _mapper.Setup(m => m.Map<InvestorDto>(It.IsAny<Investor>())).Returns(new InvestorDto { InvestorCode = "INV001" });

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _investors.Verify(r => r.AddAsync(It.IsAny<Investor>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
        _eventBus.Verify(e => e.PublishAsync(It.IsAny<IIntegrationEvent>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenCodeAlreadyExists_ReturnsFailure()
    {
        _investors.Setup(r => r.CodeExistsAsync("INV001", TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(true);

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("INV001");
        _investors.Verify(r => r.AddAsync(It.IsAny<Investor>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }
}
