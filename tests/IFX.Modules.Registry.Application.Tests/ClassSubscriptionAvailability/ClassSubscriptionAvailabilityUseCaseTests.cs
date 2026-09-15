using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.Registry.Application.ClassSubscriptionAvailability;
using IFX.Modules.Registry.Application.Ports;

namespace IFX.Modules.Registry.Application.Tests.ClassSubscriptionAvailability;

public sealed class ClassSubscriptionAvailabilityUseCaseTests
{
    private static readonly Guid TenantId = Guid.Parse("0cbe9224-d0aa-485f-9515-ccf71a584d71");

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task TrustedMatchingTenant_UsesProviderDataPort(bool isOpen)
    {
        var dataPort = new Mock<IClassSubscriptionDataPort>();
        var classId = Guid.NewGuid();
        dataPort.Setup(port => port.IsClassOpenForSubscriptionAsync(classId, TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(isOpen);
        var useCase = new ClassSubscriptionAvailabilityUseCase(dataPort.Object, AccessorFor(TenantId));

        (await useCase.IsOpenAsync(classId, TenantId)).Should().Be(isOpen);
        dataPort.Verify(port => port.IsClassOpenForSubscriptionAsync(classId, TenantId, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task MismatchedTenant_DoesNotReadProviderData()
    {
        var dataPort = new Mock<IClassSubscriptionDataPort>();
        var useCase = new ClassSubscriptionAvailabilityUseCase(dataPort.Object, AccessorFor(TenantId));

        await Assert.ThrowsAsync<InvalidOperationException>(() => useCase.IsOpenAsync(Guid.NewGuid(), Guid.NewGuid()));
        dataPort.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task MissingTrustedContext_DoesNotReadProviderData()
    {
        var dataPort = new Mock<IClassSubscriptionDataPort>();
        var useCase = new ClassSubscriptionAvailabilityUseCase(dataPort.Object, Mock.Of<IExecutionContextAccessor>());

        await Assert.ThrowsAsync<InvalidOperationException>(() => useCase.IsOpenAsync(Guid.NewGuid(), TenantId));
        dataPort.VerifyNoOtherCalls();
    }

    private static IExecutionContextAccessor AccessorFor(Guid tenantId)
    {
        var accessor = new Mock<IExecutionContextAccessor>();
        accessor.SetupGet(value => value.HasCurrent).Returns(true);
        accessor.SetupGet(value => value.Current).Returns(ExecutionContextSnapshot.ForTenant(
            Guid.NewGuid(), Guid.NewGuid(), null, tenantId,
            "service", "registry-provider", "ifx", "registry-provider", 1));
        return accessor.Object;
    }
}
