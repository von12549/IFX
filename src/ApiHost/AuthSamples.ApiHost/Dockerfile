# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy solution and project files
COPY ["src/ApiHost/AuthSamples.ApiHost/AuthSamples.ApiHost.csproj", "src/ApiHost/AuthSamples.ApiHost/"]
COPY ["src/BuildingBlocks/App.Abstractions/App.Abstractions.csproj", "src/BuildingBlocks/App.Abstractions/"]
COPY ["src/Modules/Auth/AuthSamples.Modules.Auth.Composition/AuthSamples.Modules.Auth.Composition.csproj", "src/Modules/Auth/AuthSamples.Modules.Auth.Composition/"]
COPY ["src/Modules/Auth/AuthSamples.Modules.Auth.Presentation/AuthSamples.Modules.Auth.Presentation.csproj", "src/Modules/Auth/AuthSamples.Modules.Auth.Presentation/"]
COPY ["src/Modules/Auth/AuthSamples.Modules.Auth.Application/AuthSamples.Modules.Auth.Application.csproj", "src/Modules/Auth/AuthSamples.Modules.Auth.Application/"]
COPY ["src/Modules/Auth/AuthSamples.Modules.Auth.Domain/AuthSamples.Modules.Auth.Domain.csproj", "src/Modules/Auth/AuthSamples.Modules.Auth.Domain/"]
COPY ["src/Modules/Auth/AuthSamples.Modules.Auth.Infrastructure/AuthSamples.Modules.Auth.Infrastructure.csproj", "src/Modules/Auth/AuthSamples.Modules.Auth.Infrastructure/"]

# Restore dependencies
RUN dotnet restore "src/ApiHost/AuthSamples.ApiHost/AuthSamples.ApiHost.csproj"

# Copy all source files
COPY . .

# Build the application
WORKDIR "/src/src/ApiHost/AuthSamples.ApiHost"
RUN dotnet build "AuthSamples.ApiHost.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "AuthSamples.ApiHost.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Create logs directory with proper permissions
RUN mkdir -p /app/logs && chown -R appuser:appuser /app/logs

# Copy published files
COPY --from=publish /app/publish .

# Switch to non-root user
USER appuser

# Expose ports
EXPOSE 8080
EXPOSE 8081

ENTRYPOINT ["dotnet", "AuthSamples.ApiHost.dll"]
