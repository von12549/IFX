using AuthSamples.Modules.Auth.Presentation;

namespace AuthSamples.ApiHost.Configuration
{
    public static class EndPointsConfiguration
    {
        public static IEndpointRouteBuilder MapModuleEnpoints(this IEndpointRouteBuilder builder)
        {
            //Auth Module Enpoints 
            builder.AddAuthModuleEndpoints();
            builder.AddUserModuleEndpoints();
            builder.AddUserManagementModuleEndpoints();
            builder.AddRoleModuleEndpoints();
            builder.AddIdpModuleEndpoints();
            return builder;
        }
    }
}
