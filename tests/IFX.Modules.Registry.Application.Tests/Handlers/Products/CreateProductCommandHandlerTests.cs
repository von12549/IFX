using IFX.BuildingBlocks.Application.Events;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Application.Products.Commands.CreateProduct;
using IFX.Modules.Registry.Application.Products.DTOs;
using IFX.Modules.Registry.Domain.Entities;
using IFX.Modules.Registry.Domain.Enums;
using IFX.Modules.Registry.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Tests.Handlers.Products;

public class CreateProductCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IProductRepository> _products = new();
    private readonly Mock<IMapper> _mapper = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ICommittedEventBuffer> _eventBuffer = new();
    private readonly Mock<ILogger<CreateProductCommandHandler>> _logger = new();
    private readonly CreateProductCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly CreateProductCommand ValidCommand = new(
        "PROD001", "Growth Managed Fund", ProductType.ManagedFund, "AUD", new DateOnly(2024, 1, 1));

    public CreateProductCommandHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _unitOfWork.Setup(u => u.Products).Returns(_products.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _handler = new CreateProductCommandHandler(
            _unitOfWork.Object, _mapper.Object, _currentUser.Object,
            _authorizationService.Object, _eventBuffer.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_WithNewCode_CreatesProductAndReturnsDto()
    {
        _products.Setup(r => r.CodeExistsAsync("PROD001", TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);
        _mapper.Setup(m => m.Map<ProductDto>(It.IsAny<Product>())).Returns(new ProductDto { ProductCode = "PROD001" });

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value!.ProductCode.Should().Be("PROD001");
        _products.Verify(r => r.AddAsync(It.IsAny<Product>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
        _eventBuffer.Invocations.Should().BeEmpty();
    }

    [Fact]
    public async Task Handle_WhenCodeAlreadyExists_ReturnsFailure()
    {
        _products.Setup(r => r.CodeExistsAsync("PROD001", TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(true);

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("PROD001");
        _products.Verify(r => r.AddAsync(It.IsAny<Product>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(ValidCommand, CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }

    [Fact]
    public async Task Handle_SetsCreatedByFromCurrentUser()
    {
        var userId = Guid.NewGuid();
        _currentUser.Setup(c => c.UserId).Returns(userId);
        _products.Setup(r => r.CodeExistsAsync(It.IsAny<string>(), TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);
        Product? captured = null;
        _products.Setup(r => r.AddAsync(It.IsAny<Product>(), It.IsAny<CancellationToken>()))
            .Callback<Product, CancellationToken>((p, _) => captured = p)
            .Returns(Task.CompletedTask);

        await _handler.Handle(ValidCommand, CancellationToken.None);

        captured.Should().NotBeNull();
        captured!.CreatedBy.Should().Be(userId);
    }

    [Fact]
    public async Task Handle_WithOptionalFields_PassesThemToEntity()
    {
        var command = new CreateProductCommand(
            "PROD002", "ETF Product", ProductType.ETF, "USD", new DateOnly(2024, 6, 1),
            ApirCode: "ABC1234", Isin: "AU000XYZ1234", IssuerName: "ETF Mgmt Co");

        _products.Setup(r => r.CodeExistsAsync(It.IsAny<string>(), TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(false);
        Product? captured = null;
        _products.Setup(r => r.AddAsync(It.IsAny<Product>(), It.IsAny<CancellationToken>()))
            .Callback<Product, CancellationToken>((p, _) => captured = p)
            .Returns(Task.CompletedTask);

        await _handler.Handle(command, CancellationToken.None);

        captured.Should().NotBeNull();
        captured!.ApirCode.Should().Be("ABC1234");
        captured.Isin.Should().Be("AU000XYZ1234");
        captured.IssuerName.Should().Be("ETF Mgmt Co");
    }
}
