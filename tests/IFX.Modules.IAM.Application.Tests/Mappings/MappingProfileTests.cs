using AutoMapper;
using IFX.Modules.IAM.Application.Mappings;
using Microsoft.Extensions.Logging.Abstractions;

namespace IFX.Modules.IAM.Application.Tests.Mappings;

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
