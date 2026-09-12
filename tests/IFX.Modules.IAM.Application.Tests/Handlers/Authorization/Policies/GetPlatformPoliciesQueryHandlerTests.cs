using IFX.Modules.IAM.Application.Ports.Authorization;
using IFX.Modules.IAM.Application.Access.Policies.Queries.GetPlatformPolicies;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tests.Handlers.Authorization.Policies;

public class GetPlatformPoliciesQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IPolicyDefinitionRepository> _policies = new();
    private readonly Mock<ILogger<GetPlatformPoliciesQueryHandler>> _logger = new();
    private readonly GetPlatformPoliciesQueryHandler _handler;

    public GetPlatformPoliciesQueryHandlerTests()
    {
        _unitOfWork.Setup(u => u.PolicyDefinitions).Returns(_policies.Object);
        _handler = new GetPlatformPoliciesQueryHandler(_unitOfWork.Object, _logger.Object, Mock.Of<IResourceAuthorizationService>());
    }

    [Fact]
    public async Task Handle_ReturnsPlatformPoliciesWithIsPlatformDefaultTrue()
    {
        var policy = PolicyDefinition.Create(
            PolicyScope.Platform, null, "Read Own Profile (Platform Default)", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null},{\"TemplateName\":\"CreatedByMe\",\"Parameters\":null}]",
            null);

        _policies.Setup(p => p.GetPlatformPoliciesAsync(It.IsAny<CancellationToken>()))
                 .ReturnsAsync([policy]);

        var result = await _handler.Handle(new GetPlatformPoliciesQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().HaveCount(1);
        result.Value![0].TenantId.Should().BeNull();
        result.Value[0].IsPlatformDefault.Should().BeTrue();
        result.Value[0].Conditions.Should().HaveCount(2);
    }

    [Fact]
    public async Task Handle_WhenNoPlatformPolicies_ReturnsEmptyList()
    {
        _policies.Setup(p => p.GetPlatformPoliciesAsync(It.IsAny<CancellationToken>()))
                 .ReturnsAsync([]);

        var result = await _handler.Handle(new GetPlatformPoliciesQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().BeEmpty();
    }
}
