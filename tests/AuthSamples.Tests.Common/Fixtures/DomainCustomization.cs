using AutoFixture;
using AuthSamples.Modules.Auth.Domain.ValueObjects;
using AuthSamples.Modules.Auth.Domain.Entities;

namespace AuthSamples.Tests.Common.Fixtures;

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
