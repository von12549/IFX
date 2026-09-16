using System.Reflection;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Application.Ports.Authorization;
using IFX.Modules.IAM.Application.Users.Commands.UpdateUserProfile;
using IFX.Modules.IAM.Application.Users.DTOs;
using IFX.Modules.IAM.Domain.Identity;
using IFX.Modules.IAM.Domain.Users;
using IFX.Tests.Common;
using IFX.Tests.Common.Builders;
using Microsoft.Extensions.Logging;
using SecurityResourceAttributes = IFX.BuildingBlocks.Security.Authorization.ResourceAttributes;

namespace IFX.Modules.IAM.Application.Tests.Handlers.Users;

public sealed class UpdateUserProfileCommandHandlerTests
{
    [Fact]
    public async Task Handle_WhenIpAddressIsMissing_RecordsUnknownInActivityLog()
    {
        var user = new UserBuilder().Active().Build();
        var identity = new UserIdentityBuilder()
            .WithUserId(user.Id)
            .WithIssuer(TestConstants.IFXCognitoIssuer)
            .WithSubject(TestConstants.ValidSubject)
            .Build();
        AddIdentity(user, identity);

        var users = new Mock<IUserRepository>();
        var identities = new Mock<IUserIdentityRepository>();
        var activities = new Mock<IUserActivityLogRepository>();
        UserActivityLog? recordedActivity = null;
        users.Setup(x => x.GetByIssuerAndSubjectWithPermissionsAsync(
                TestConstants.IFXCognitoIssuer,
                TestConstants.ValidSubject,
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);
        activities.Setup(x => x.AddAsync(It.IsAny<UserActivityLog>(), It.IsAny<CancellationToken>()))
            .Callback<UserActivityLog, CancellationToken>((activity, _) => recordedActivity = activity)
            .Returns(Task.CompletedTask);

        var unitOfWork = new Mock<IUnitOfWork>();
        unitOfWork.SetupGet(x => x.Users).Returns(users.Object);
        unitOfWork.SetupGet(x => x.UserIdentities).Returns(identities.Object);
        unitOfWork.SetupGet(x => x.UserActivityLogs).Returns(activities.Object);

        var authorization = new Mock<IResourceAuthorizationService>();
        authorization.Setup(x => x.AuthorizeWithResolvedPolicyAsync(
                "user",
                "update",
                It.IsAny<SecurityResourceAttributes>(),
                It.IsAny<IDictionary<string, object>?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        var mapper = new Mock<IMapper>();
        mapper.Setup(x => x.Map<UserProfileDto>(user)).Returns(new UserProfileDto { Id = user.Id });

        var handler = new UpdateUserProfileCommandHandler(
            unitOfWork.Object,
            mapper.Object,
            Mock.Of<ICurrentUser>(),
            authorization.Object,
            Mock.Of<ILogger<UpdateUserProfileCommandHandler>>());

        var result = await handler.Handle(
            new UpdateUserProfileCommand(
                TestConstants.IFXCognitoIssuer,
                TestConstants.ValidSubject,
                FirstName: "Updated",
                IpAddress: null),
            CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        recordedActivity.Should().NotBeNull();
        recordedActivity!.IpAddress.Should().Be("Unknown");
    }

    private static void AddIdentity(User user, UserIdentity identity)
    {
        var field = typeof(User).GetField("_identities", BindingFlags.Instance | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException("User identity backing field was not found.");
        var values = (List<UserIdentity>?)field.GetValue(user)
            ?? throw new InvalidOperationException("User identity collection was not initialized.");
        values.Add(identity);
    }
}
