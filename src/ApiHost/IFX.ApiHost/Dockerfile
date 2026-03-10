# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
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
RUN dotnet build "IFX.ApiHost.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "IFX.ApiHost.csproj" -c Release -o /app/publish /p:UseAppHost=false

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

ENTRYPOINT ["dotnet", "IFX.ApiHost.dll"]
