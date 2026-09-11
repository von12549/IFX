using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Holdings.Application.DTOs;
using IFX.Modules.Holdings.Application.Interfaces;
using IFX.Modules.Holdings.Application.Queries.GetHoldingsByClass;
using IFX.Modules.Holdings.Domain.Entities;
using IFX.Modules.Holdings.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Holdings.Application.Tests.Handlers;

public class GetHoldingsByClassQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IHoldingRepository> _holdings = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<GetHoldingsByClassQueryHandler>> _logger = new();
    private readonly GetHoldingsByClassQueryHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    public GetHoldingsByClassQueryHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _unitOfWork.Setup(u => u.Holdings).Returns(_holdings.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _handler = new GetHoldingsByClassQueryHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_ReturnsHoldingsForClass()
    {
        var classId = Guid.NewGuid();
        var h1 = Holding.Create(TenantId, Guid.NewGuid(), classId);
        h1.ApplySubscription(100m);
        var h2 = Holding.Create(TenantId, Guid.NewGuid(), classId);
        h2.ApplySubscription(200m);
        _holdings.Setup(r => r.GetByClassAsync(TenantId, classId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Holding> { h1, h2 });
        _mapper.Setup(m => m.Map<IReadOnlyList<HoldingSummaryDto>>(It.IsAny<IEnumerable<Holding>>()))
            .Returns(new List<HoldingSummaryDto>
            {
                new(h1.Id, TenantId, h1.InvestmentAccountId, classId, 100m, "Active", null, DateTime.UtcNow, DateTime.UtcNow),
                new(h2.Id, TenantId, h2.InvestmentAccountId, classId, 200m, "Active", null, DateTime.UtcNow, DateTime.UtcNow)
            });

        var result = await _handler.Handle(new GetHoldingsByClassQuery(classId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().HaveCount(2);
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new GetHoldingsByClassQuery(Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }

    [Fact]
    public async Task Handle_WhenClassHasNoHoldings_ReturnsEmptyList()
    {
        var classId = Guid.NewGuid();
        _holdings.Setup(r => r.GetByClassAsync(TenantId, classId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Holding>());
        _mapper.Setup(m => m.Map<IReadOnlyList<HoldingSummaryDto>>(It.IsAny<IEnumerable<Holding>>()))
            .Returns(new List<HoldingSummaryDto>());

        var result = await _handler.Handle(new GetHoldingsByClassQuery(classId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().BeEmpty();
    }
}
