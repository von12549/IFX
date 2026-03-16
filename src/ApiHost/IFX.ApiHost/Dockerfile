# Base runtime image (used by VS for debug target and by final stage)
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

# Create non-root user and logs directory
RUN groupadd -r appuser && useradd -r -g appuser appuser \
    && mkdir -p /app/logs && chown -R appuser:appuser /app/logs

# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src

# Copy solution and project files
COPY ["src/ApiHost/IFX.ApiHost/IFX.ApiHost.csproj", "src/ApiHost/IFX.ApiHost/"]
COPY ["src/BuildingBlocks/App.Abstractions/App.Abstractions.csproj", "src/BuildingBlocks/App.Abstractions/"]
COPY ["src/Modules/Auth/IFX.Modules.Auth.Composition/IFX.Modules.Auth.Composition.csproj", "src/Modules/Auth/IFX.Modules.Auth.Composition/"]
COPY ["src/Modules/Auth/IFX.Modules.Auth.Presentation/IFX.Modules.Auth.Presentation.csproj", "src/Modules/Auth/IFX.Modules.Auth.Presentation/"]
COPY ["src/Modules/Auth/IFX.Modules.Auth.Application/IFX.Modules.Auth.Application.csproj", "src/Modules/Auth/IFX.Modules.Auth.Application/"]
COPY ["src/Modules/Auth/IFX.Modules.Auth.Domain/IFX.Modules.Auth.Domain.csproj", "src/Modules/Auth/IFX.Modules.Auth.Domain/"]
COPY ["src/Modules/Auth/IFX.Modules.Auth.Infrastructure/IFX.Modules.Auth.Infrastructure.csproj", "src/Modules/Auth/IFX.Modules.Auth.Infrastructure/"]

# Restore dependencies
RUN dotnet restore "src/ApiHost/IFX.ApiHost/IFX.ApiHost.csproj"

# Copy all source files
COPY . .

# Build the application
WORKDIR "/src/src/ApiHost/IFX.ApiHost"
RUN dotnet build "IFX.ApiHost.csproj" -c $BUILD_CONFIGURATION -o /app/build

# Publish stage
FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "IFX.ApiHost.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

# Final runtime stage
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
USER appuser
ENTRYPOINT ["dotnet", "IFX.ApiHost.dll"]
