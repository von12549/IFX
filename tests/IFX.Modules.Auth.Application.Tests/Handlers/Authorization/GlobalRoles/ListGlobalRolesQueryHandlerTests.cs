using IFX.Modules.Auth.Application.Authorization.GlobalRoles.Queries.ListGlobalRoles;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization.GlobalRoles;

public class ListGlobalRolesQueryHandlerTests
{
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly Mock<IGlobalRoleRepository> _globalRoles = new();
    private readonly Mock<ILogger<ListGlobalRolesQueryHandler>> _logger = new();
    private readonly ListGlobalRolesQueryHandler _handler;

    public ListGlobalRolesQueryHandlerTests()
    {
        _unitOfWork.Setup(u => u.GlobalRoles).Returns(_globalRoles.Object);
        _handler = new ListGlobalRolesQueryHandler(_unitOfWork.Object, _logger.Object);
    }

    [Fact]
    public async Task Handle_ReturnsAllGlobalRoles()
    {
        var role = GlobalRole.Create("PlatformAdmin", "Full cross-tenant platform access");

        _globalRoles.Setup(r => r.GetAllAsync(It.IsAny<CancellationToken>()))
                    .ReturnsAsync([role]);

        var result = await _handler.Handle(new ListGlobalRolesQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().HaveCount(1);
        result.Value![0].Name.Should().Be("PlatformAdmin");
    }

    [Fact]
    public async Task Handle_WhenNoRoles_ReturnsEmptyList()
    {
        _globalRoles.Setup(r => r.GetAllAsync(It.IsAny<CancellationToken>()))
                    .ReturnsAsync([]);

        var result = await _handler.Handle(new ListGlobalRolesQuery(), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().BeEmpty();
    }
}
