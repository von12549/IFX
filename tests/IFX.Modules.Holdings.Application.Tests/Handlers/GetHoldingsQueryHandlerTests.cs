using IFX.Modules.Holdings.Application.Ports.Authorization;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;

using IFX.Modules.Holdings.Application.DTOs;
using IFX.Modules.Holdings.Application.Interfaces;
using IFX.Modules.Holdings.Application.Queries.GetHoldings;
using IFX.Modules.Holdings.Domain.Entities;
using IFX.Modules.Holdings.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Holdings.Application.Tests.Handlers;

public class GetHoldingsQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IHoldingRepository> _holdings = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<GetHoldingsQueryHandler>> _logger = new();
    private readonly GetHoldingsQueryHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    public GetHoldingsQueryHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _unitOfWork.Setup(u => u.Holdings).Returns(_holdings.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<ResourceAttributes>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _handler = new GetHoldingsQueryHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithTenantContext_ReturnsHoldings()
    {
        var holding = Holding.Create(TenantId, Guid.NewGuid(), Guid.NewGuid());
        holding.ApplySubscription(100m);
        _holdings.Setup(r => r.GetByTenantAsync(TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Holding> { holding });
        _mapper.Setup(m => m.Map<IReadOnlyList<HoldingSummaryDto>>(It.IsAny<IEnumerable<Holding>>()))
            .Returns(new List<HoldingSummaryDto>
            {
                new(holding.Id, TenantId, holding.InvestmentAccountId, holding.ClassId, 100m, "Active", null, DateTime.UtcNow, DateTime.UtcNow)
            });

        var result = await _handler.Handle(new GetHoldingsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().HaveCount(1);
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new GetHoldingsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }

    [Fact]
    public async Task Handle_WhenNoHoldings_ReturnsEmptyList()
    {
        _holdings.Setup(r => r.GetByTenantAsync(TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Holding>());
        _mapper.Setup(m => m.Map<IReadOnlyList<HoldingSummaryDto>>(It.IsAny<IEnumerable<Holding>>()))
            .Returns(new List<HoldingSummaryDto>());

        var result = await _handler.Handle(new GetHoldingsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().BeEmpty();
    }
}
