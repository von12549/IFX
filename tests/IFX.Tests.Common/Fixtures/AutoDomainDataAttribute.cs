using AutoFixture;
using AutoFixture.Xunit2;

namespace IFX.Tests.Common.Fixtures;

public class AutoDomainDataAttribute : AutoDataAttribute
{
    public AutoDomainDataAttribute()
        : base(() => new Fixture().Customize(new DomainCustomization()))
    {
    }
}
