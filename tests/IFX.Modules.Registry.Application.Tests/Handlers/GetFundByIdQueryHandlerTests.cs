using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Registry.Application.Funds.DTOs;
using IFX.Modules.Registry.Application.Funds.Queries.GetFundById;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Domain.Entities;
using IFX.Modules.Registry.Domain.Enums;
using IFX.Modules.Registry.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Tests.Handlers;

public class GetFundByIdQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IFundRepository> _funds = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<GetFundByIdQueryHandler>> _logger = new();
    private readonly GetFundByIdQueryHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    public GetFundByIdQueryHandlerTests()
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

        _handler = new GetFundByIdQueryHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WhenFundExists_ReturnsDto()
    {
        var fund = Fund.Create(TenantId, "FUND001", "Growth Fund", FundType.UCITS, "USD", new DateOnly(2024, 1, 1));
        _funds.Setup(r => r.GetByIdAsync(fund.Id, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(fund);
        _mapper.Setup(m => m.Map<FundDto>(fund)).Returns(new FundDto { FundCode = "FUND001" });

        var result = await _handler.Handle(new GetFundByIdQuery(fund.Id), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.FundCode.Should().Be("FUND001");
    }

    [Fact]
    public async Task Handle_WhenFundNotFound_ReturnsFailure()
    {
        var missingId = Guid.NewGuid();
        _funds.Setup(r => r.GetByIdAsync(missingId, TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Fund?)null);

        var result = await _handler.Handle(new GetFundByIdQuery(missingId), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new GetFundByIdQuery(Guid.NewGuid()), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }
}
