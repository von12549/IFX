using AutoFixture;
using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Domain.Identity;
using IFX.Modules.Auth.Domain.Users;

namespace IFX.Tests.Common.Fixtures;

public class DomainCustomization : ICustomization
{
    public void Customize(IFixture fixture)
    {
        fixture.Register(() => EmailAddress.Create($"test{Guid.NewGuid():N}@example.com"));
        fixture.Register(() => Subject.Create(Guid.NewGuid().ToString()));
        fixture.Register(() => DeviceInfo.Parse(TestConstants.ValidUserAgent));

        fixture.Register(() => UserRole.Create(
            $"Role_{Guid.NewGuid():N}".Substring(0, 20),
            "Auto-generated role description"));

        fixture.Register(() => User.Create(
            Guid.NewGuid(),
            $"User {fixture.Create<string>().Substring(0, 10)}",
            false));
    }
}
