using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Investors.Commands.AddInvestorDocument;
using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Tests.Handlers.Investors;

public class AddInvestorDocumentCommandHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IInvestorRepository> _investors = new();
    private readonly Mock<IInvestorDocumentRepository> _documents = new();
    private readonly Mock<ICurrentUser> _currentUser = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<AddInvestorDocumentCommandHandler>> _logger = new();
    private readonly AddInvestorDocumentCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid InvestorId = Guid.NewGuid();

    public AddInvestorDocumentCommandHandlerTests()
    {
        _currentUser.Setup(c => c.TenantId).Returns(TenantId);
        _currentUser.Setup(c => c.UserId).Returns(Guid.NewGuid());
        _unitOfWork.Setup(u => u.Investors).Returns(_investors.Object);
        _unitOfWork.Setup(u => u.InvestorDocuments).Returns(_documents.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _handler = new AddInvestorDocumentCommandHandler(
            _unitOfWork.Object, _currentUser.Object, _authorizationService.Object, _logger.Object);
    }

    private AddInvestorDocumentCommand MakeCommand() =>
        new(InvestorId, DocumentType.Passport, "P1234567", "AU", null, null, null);

    [Fact]
    public async Task Handle_WithExistingInvestor_AddsDocument()
    {
        var investor = Investor.Create(TenantId, "INV001", "John Doe", PartyLegalStructure.Individual);
        _investors.Setup(r => r.GetByIdAsync(InvestorId, TenantId, It.IsAny<CancellationToken>())).ReturnsAsync(investor);

        var result = await _handler.Handle(MakeCommand(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _documents.Verify(r => r.AddAsync(It.IsAny<InvestorDocument>(), It.IsAny<CancellationToken>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_WhenInvestorNotFound_ReturnsFailure()
    {
        _investors.Setup(r => r.GetByIdAsync(InvestorId, TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Investor?)null);

        var result = await _handler.Handle(MakeCommand(), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
        _documents.Verify(r => r.AddAsync(It.IsAny<InvestorDocument>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_WhenNoTenantContext_ReturnsFailure()
    {
        _currentUser.Setup(c => c.TenantId).Returns((Guid?)null);

        var result = await _handler.Handle(MakeCommand(), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Tenant");
    }
}
