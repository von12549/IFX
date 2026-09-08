using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Holdings.Application.DTOs;
using IFX.Modules.Holdings.Application.Interfaces;
using IFX.Modules.Holdings.Application.Queries.GetHoldingById;
using IFX.Modules.Holdings.Domain.Entities;
using IFX.Modules.Holdings.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Holdings.Application.Tests.Handlers;

public class GetHoldingByIdQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IHoldingRepository> _holdings = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<GetHoldingByIdQueryHandler>> _logger = new();
    private readonly GetHoldingByIdQueryHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    private static HoldingSummaryDto MakeDto(Guid holdingId) => new(
        holdingId, TenantId, Guid.NewGuid(), Guid.NewGuid(),
        100m, "Active", null, DateTime.UtcNow, DateTime.UtcNow);

    public GetHoldingByIdQueryHandlerTests()
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

        _handler = new GetHoldingByIdQueryHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WhenHoldingExists_ReturnsDto()
    {
        var holding = Holding.Create(TenantId, Guid.NewGuid(), Guid.NewGuid());
        _holdings.Setup(r => r.GetByIdAsync(holding.Id, It.IsAny<CancellationToken>())).ReturnsAsync(holding);
        _mapper.Setup(m => m.Map<HoldingSummaryDto>(holding)).Returns(MakeDto(holding.Id));

        var result = await _handler.Handle(new GetHoldingByIdQuery(holding.Id), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.HoldingId.Should().Be(holding.Id);
    }

    [Fact]
    public async Task Handle_WhenHoldingNotFound_ReturnsFailure()
    {
        var missingId = Guid.NewGuid();
        _holdings.Setup(r => r.GetByIdAsync(missingId, It.IsAny<CancellationToken>())).ReturnsAsync((Holding?)null);

        var result = await _handler.Handle(new GetHoldingByIdQuery(missingId), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }
}
