using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Registry.Application.Funds.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Application.Products.Queries.GetProductFunds;
using IFX.Modules.Registry.Domain.Entities;
using IFX.Modules.Registry.Domain.Enums;
using IFX.Modules.Registry.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Tests.Handlers.Products;

public class GetProductFundsQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IProductRepository> _products = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<GetProductFundsQueryHandler>> _logger = new();
    private readonly GetProductFundsQueryHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid ProductId = Guid.NewGuid();

    public GetProductFundsQueryHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _unitOfWork.Setup(u => u.Products).Returns(_products.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _handler = new GetProductFundsQueryHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WhenProductExists_ReturnsFunds()
    {
        var product = Product.Create(TenantId, "PROD001", "Growth Fund", ProductType.ManagedFund, "AUD", new DateOnly(2024, 1, 1));
        var funds = new List<Fund>
        {
            Fund.Create(TenantId, "FUND001", "Sub Fund A", FundType.UCITS, "AUD", new DateOnly(2024, 1, 1)),
            Fund.Create(TenantId, "FUND002", "Sub Fund B", FundType.UCITS, "AUD", new DateOnly(2024, 6, 1))
        };

        _products.Setup(r => r.GetByIdAsync(ProductId, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(product);
        _products.Setup(r => r.GetFundsByProductIdAsync(ProductId, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(funds);
        _mapper.Setup(m => m.Map<List<FundDto>>(funds))
            .Returns(new List<FundDto> { new() { FundCode = "FUND001" }, new() { FundCode = "FUND002" } });

        var result = await _handler.Handle(new GetProductFundsQuery(ProductId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Should().HaveCount(2);
    }

    [Fact]
    public async Task Handle_WhenProductNotFound_ReturnsFailure()
    {
        _products.Setup(r => r.GetByIdAsync(ProductId, TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Product?)null);

        var result = await _handler.Handle(new GetProductFundsQuery(ProductId), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
        _products.Verify(r => r.GetFundsByProductIdAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsEmptyList()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new GetProductFundsQuery(ProductId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Should().BeEmpty();
        _products.Verify(r => r.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenProductHasNoFunds_ReturnsEmptyList()
    {
        var product = Product.Create(TenantId, "PROD001", "Growth Fund", ProductType.ManagedFund, "AUD", new DateOnly(2024, 1, 1));
        _products.Setup(r => r.GetByIdAsync(ProductId, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(product);
        _products.Setup(r => r.GetFundsByProductIdAsync(ProductId, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(new List<Fund>());
        _mapper.Setup(m => m.Map<List<FundDto>>(It.IsAny<List<Fund>>())).Returns(new List<FundDto>());

        var result = await _handler.Handle(new GetProductFundsQuery(ProductId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Should().BeEmpty();
    }
}
