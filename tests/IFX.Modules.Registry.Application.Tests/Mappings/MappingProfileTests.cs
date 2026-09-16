using AutoMapper;
using IFX.Modules.Registry.Application.Mappings;
using Microsoft.Extensions.Logging.Abstractions;

namespace IFX.Modules.Registry.Application.Tests.Mappings;

public sealed class MappingProfileTests
{
    [Fact]
    public void Configuration_IsValid()
    {
        var configuration = new MapperConfiguration(
            cfg => cfg.AddProfile<MappingProfile>(),
            NullLoggerFactory.Instance);

        configuration.AssertConfigurationIsValid();
    }
}
