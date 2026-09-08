using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Holdings.Application.DTOs;
using IFX.Modules.Holdings.Application.Interfaces;
using IFX.Modules.Holdings.Application.Queries.GetHoldingsByInvestor;
using IFX.Modules.Holdings.Domain.Entities;
using IFX.Modules.Holdings.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Holdings.Application.Tests.Handlers;

public class GetHoldingsByInvestorQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IHoldingRepository> _holdings = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<GetHoldingsByInvestorQueryHandler>> _logger = new();
    private readonly GetHoldingsByInvestorQueryHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    public GetHoldingsByInvestorQueryHandlerTests()
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

        _handler = new GetHoldingsByInvestorQueryHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_ReturnsHoldingsForInvestmentAccount()
    {
        var accountId = Guid.NewGuid();
        var holding = Holding.Create(TenantId, accountId, Guid.NewGuid());
        holding.ApplySubscription(200m);
        _holdings.Setup(r => r.GetByInvestmentAccountAsync(TenantId, accountId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Holding> { holding });
        _mapper.Setup(m => m.Map<IReadOnlyList<HoldingSummaryDto>>(It.IsAny<IEnumerable<Holding>>()))
            .Returns(new List<HoldingSummaryDto>
            {
                new(holding.Id, TenantId, accountId, holding.ClassId, 200m, "Active", null, DateTime.UtcNow, DateTime.UtcNow)
            });

        var result = await _handler.Handle(new GetHoldingsByInvestorQuery(accountId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().HaveCount(1);
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new GetHoldingsByInvestorQuery(Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }

    [Fact]
    public async Task Handle_WhenAccountHasNoHoldings_ReturnsEmptyList()
    {
        var accountId = Guid.NewGuid();
        _holdings.Setup(r => r.GetByInvestmentAccountAsync(TenantId, accountId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Holding>());
        _mapper.Setup(m => m.Map<IReadOnlyList<HoldingSummaryDto>>(It.IsAny<IEnumerable<Holding>>()))
            .Returns(new List<HoldingSummaryDto>());

        var result = await _handler.Handle(new GetHoldingsByInvestorQuery(accountId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().BeEmpty();
    }
}
