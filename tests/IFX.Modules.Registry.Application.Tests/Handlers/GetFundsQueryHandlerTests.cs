using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Registry.Application.Funds.DTOs;
using IFX.Modules.Registry.Application.Funds.Queries.GetFunds;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Domain.Entities;
using IFX.Modules.Registry.Domain.Enums;
using IFX.Modules.Registry.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Tests.Handlers;

public class GetFundsQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IFundRepository> _funds = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<GetFundsQueryHandler>> _logger = new();
    private readonly GetFundsQueryHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    public GetFundsQueryHandlerTests()
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

        _handler = new GetFundsQueryHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithTenantContext_ReturnsFunds()
    {
        var fund = Fund.Create(TenantId, "FUND001", "Growth Fund", FundType.UCITS, "USD", new DateOnly(2024, 1, 1));
        _funds.Setup(r => r.GetByTenantIdAsync(TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Fund> { fund });
        _mapper.Setup(m => m.Map<List<FundDto>>(It.IsAny<IEnumerable<Fund>>()))
            .Returns(new List<FundDto> { new() { FundCode = "FUND001" } });

        var result = await _handler.Handle(new GetFundsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().HaveCount(1);
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsEmptySuccess()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new GetFundsQuery(), CancellationToken.None);

        // GetFundsQueryHandler returns empty list (not failure) when tenant is null
        result.IsSuccess.Should().BeTrue();
        result.Value.Should().BeEmpty();
    }

    [Fact]
    public async Task Handle_WhenNoFunds_ReturnsEmptyList()
    {
        _funds.Setup(r => r.GetByTenantIdAsync(TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Fund>());
        _mapper.Setup(m => m.Map<List<FundDto>>(It.IsAny<IEnumerable<Fund>>()))
            .Returns(new List<FundDto>());

        var result = await _handler.Handle(new GetFundsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().BeEmpty();
    }
}
