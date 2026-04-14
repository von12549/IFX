using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Application.Products.DTOs;
using IFX.Modules.Registry.Application.Products.Queries.GetProducts;
using IFX.Modules.Registry.Domain.Entities;
using IFX.Modules.Registry.Domain.Enums;
using IFX.Modules.Registry.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Tests.Handlers.Products;

public class GetProductsQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IProductRepository> _products = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<GetProductsQueryHandler>> _logger = new();
    private readonly GetProductsQueryHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    public GetProductsQueryHandlerTests()
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

        _handler = new GetProductsQueryHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_ReturnsMappedProducts()
    {
        var products = new List<Product>
        {
            Product.Create(TenantId, "PROD001", "Growth Fund", ProductType.ManagedFund, "AUD", new DateOnly(2024, 1, 1)),
            Product.Create(TenantId, "PROD002", "Income ETF", ProductType.ETF, "AUD", new DateOnly(2024, 6, 1))
        };
        _products.Setup(r => r.GetByTenantIdAsync(TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(products);
        _mapper.Setup(m => m.Map<List<ProductDto>>(products))
            .Returns(new List<ProductDto> { new() { ProductCode = "PROD001" }, new() { ProductCode = "PROD002" } });

        var result = await _handler.Handle(new GetProductsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Should().HaveCount(2);
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsEmptyList()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(new GetProductsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Should().BeEmpty();
        _products.Verify(r => r.GetByTenantIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WithEmptyTenant_ReturnsEmptyList()
    {
        _products.Setup(r => r.GetByTenantIdAsync(TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(new List<Product>());
        _mapper.Setup(m => m.Map<List<ProductDto>>(It.IsAny<List<Product>>())).Returns(new List<ProductDto>());

        var result = await _handler.Handle(new GetProductsQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Should().BeEmpty();
    }
}
