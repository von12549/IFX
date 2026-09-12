using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Models;
using IFX.Modules.IAM.Application.Access.Policies.Queries.GetPolicies;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tests.Handlers.Authorization.Policies;

public class GetPoliciesQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IPolicyDefinitionRepository> _policies = new();
    private readonly Mock<IResourceAuthorizationService> _authorizationService = new();
    private readonly Mock<ILogger<GetPoliciesQueryHandler>> _logger = new();
    private readonly GetPoliciesQueryHandler _handler;

    public GetPoliciesQueryHandlerTests()
    {
        _unitOfWork.Setup(u => u.PolicyDefinitions).Returns(_policies.Object);
        _authorizationService
            .Setup(a => a.AuthorizeWithResolvedPolicyAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<OpaResourceAttributesBase>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _handler = new GetPoliciesQueryHandler(_unitOfWork.Object, _authorizationService.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_ReturnsTenantPoliciesWithIsPlatformDefaultFalse()
    {
        var tenantId = Guid.NewGuid();
        var policy = PolicyDefinition.Create(
            PolicyScope.Tenant, tenantId, "Read Own Profile", "user", "read",
            "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null}]", null);

        _policies.Setup(p => p.GetByTenantIdAsync(tenantId, It.IsAny<CancellationToken>()))
                 .ReturnsAsync([policy]);

        var result = await _handler.Handle(new GetPoliciesQuery(tenantId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().HaveCount(1);
        result.Value![0].Name.Should().Be("Read Own Profile");
        result.Value[0].IsPlatformDefault.Should().BeFalse();
        result.Value[0].Conditions.Should().HaveCount(1);
    }

    [Fact]
    public async Task Handle_WhenNoPolicies_ReturnsEmptyList()
    {
        var tenantId = Guid.NewGuid();
        _policies.Setup(p => p.GetByTenantIdAsync(tenantId, It.IsAny<CancellationToken>()))
                 .ReturnsAsync([]);

        var result = await _handler.Handle(new GetPoliciesQuery(tenantId), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().BeEmpty();
    }
}
