using AutoMapper;
using IFX.Modules.CRM.Application.Mappings;
using Microsoft.Extensions.Logging.Abstractions;

namespace IFX.Modules.CRM.Application.Tests.Mappings;

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
