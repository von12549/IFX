using IFX.BuildingBlocks.Application.Events;
using IFX.Modules.Holdings.Application.Integrations;
using IFX.Modules.Holdings.Application.Interfaces;
using IFX.Modules.Holdings.Application.Ports;
using IFX.Modules.Holdings.Domain.Entities;
using IFX.Modules.Holdings.Domain.Repositories;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Holdings.Application.Tests.Integrations;

public sealed class HoldingsInboxCommandHandlerTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IHoldingRepository> _holdings = new();
    private readonly Mock<IHoldingsInboxPort> _inbox = new();

    public HoldingsInboxCommandHandlerTests() => _unitOfWork.Setup(unit => unit.Holdings).Returns(_holdings.Object);

    [Fact]
    public async Task Transaction_event_applies_projection_without_saving_outside_transaction_behavior()
    {
        var holding = Holding.Create(TenantId, Guid.NewGuid(), Guid.NewGuid());
        _holdings.Setup(repository => repository.GetByAccountAndClassAsync(TenantId, holding.InvestmentAccountId, holding.ClassId, It.IsAny<CancellationToken>())).ReturnsAsync(holding);
        var handler = new ApplyTransactionProcessedCommandHandler(_unitOfWork.Object, _inbox.Object, Mock.Of<ILogger<ApplyTransactionProcessedCommandHandler>>());
        var command = new ApplyTransactionProcessedCommand(Metadata(), Guid.NewGuid(), "Subscription", holding.InvestmentAccountId, holding.ClassId, null, 25m, 4m);

        var result = await handler.Handle(command, CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.WasDuplicate.Should().BeFalse();
        holding.Units.Should().Be(25m);
        _unitOfWork.Verify(unit => unit.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Completed_event_is_a_no_op()
    {
        var metadata = Metadata();
        _inbox.Setup(port => port.HasCompletedAsync("holdings.transaction-processed.v1", metadata.EventId, It.IsAny<CancellationToken>())).ReturnsAsync(true);
        var handler = new ApplyTransactionProcessedCommandHandler(_unitOfWork.Object, _inbox.Object, Mock.Of<ILogger<ApplyTransactionProcessedCommandHandler>>());

        var result = await handler.Handle(new ApplyTransactionProcessedCommand(metadata, Guid.NewGuid(), "Subscription", Guid.NewGuid(), Guid.NewGuid(), null, 10m, 2m), CancellationToken.None);

        result.WasDuplicate.Should().BeTrue();
        _holdings.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task Closing_class_freezes_only_tenant_scoped_holdings()
    {
        var classId = Guid.NewGuid();
        var holding = Holding.Create(TenantId, Guid.NewGuid(), classId);
        _holdings.Setup(repository => repository.GetByClassAsync(TenantId, classId, It.IsAny<CancellationToken>())).ReturnsAsync([holding]);
        var handler = new ApplyClassStatusChangedCommandHandler(_unitOfWork.Object, _inbox.Object);

        var result = await handler.Handle(new ApplyClassStatusChangedCommand(Metadata(), classId, Guid.NewGuid(), "Active", "Closed"), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        holding.Status.Should().Be(Domain.Enums.HoldingStatus.Frozen);
        _holdings.Verify(repository => repository.Update(holding), Times.Once);
    }

    private static IntegrationEventMetadata Metadata() => new(Guid.NewGuid(), TenantId, Guid.NewGuid().ToString("D"), Guid.NewGuid().ToString("D"));
}
