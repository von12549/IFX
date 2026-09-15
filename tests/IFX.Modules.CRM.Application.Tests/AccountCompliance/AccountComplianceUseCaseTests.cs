using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.CRM.Application.AccountCompliance;
using IFX.Modules.CRM.Application.Ports;

namespace IFX.Modules.CRM.Application.Tests.AccountCompliance;

public sealed class AccountComplianceUseCaseTests
{
    private static readonly Guid TenantId = Guid.Parse("0cbe9224-d0aa-485f-9515-ccf71a584d71");

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task TrustedMatchingTenant_UsesProviderDataPort(bool approved)
    {
        var dataPort = new Mock<IAccountComplianceDataPort>();
        var accountId = Guid.NewGuid();
        dataPort.Setup(port => port.IsInvestmentAccountKycApprovedAsync(accountId, TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(approved);
        var useCase = new AccountComplianceUseCase(dataPort.Object, AccessorFor(TenantId));

        (await useCase.IsApprovedAsync(accountId, TenantId)).Should().Be(approved);
        dataPort.Verify(port => port.IsInvestmentAccountKycApprovedAsync(accountId, TenantId, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task MismatchedTenant_DoesNotReadProviderData()
    {
        var dataPort = new Mock<IAccountComplianceDataPort>();
        var useCase = new AccountComplianceUseCase(dataPort.Object, AccessorFor(TenantId));

        await Assert.ThrowsAsync<InvalidOperationException>(() => useCase.IsApprovedAsync(Guid.NewGuid(), Guid.NewGuid()));
        dataPort.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task MissingTrustedContext_DoesNotReadProviderData()
    {
        var dataPort = new Mock<IAccountComplianceDataPort>();
        var useCase = new AccountComplianceUseCase(dataPort.Object, Mock.Of<IExecutionContextAccessor>());

        await Assert.ThrowsAsync<InvalidOperationException>(() => useCase.IsApprovedAsync(Guid.NewGuid(), TenantId));
        dataPort.VerifyNoOtherCalls();
    }

    private static IExecutionContextAccessor AccessorFor(Guid tenantId)
    {
        var accessor = new Mock<IExecutionContextAccessor>();
        accessor.SetupGet(value => value.HasCurrent).Returns(true);
        accessor.SetupGet(value => value.Current).Returns(ExecutionContextSnapshot.ForTenant(
            Guid.NewGuid(), Guid.NewGuid(), null, tenantId,
            "service", "crm-provider", "ifx", "crm-provider", 1));
        return accessor.Object;
    }
}
