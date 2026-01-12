namespace AuthSamples.ApiHost.Configuration;

public static class CorsConfiguration
{
    /// <summary>
    /// Configures CORS policy to allow all origins, methods, and headers
    /// </summary>
    public static IServiceCollection AddAuthCors(this IServiceCollection services)
    {
        services.AddCors(options =>
        {
            options.AddPolicy("AllowAll", policy =>
            {
                policy.AllowAnyOrigin()
                      .AllowAnyMethod()
                      .AllowAnyHeader();
            });
        });

        return services;
    }
}
