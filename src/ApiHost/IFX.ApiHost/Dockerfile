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

# Restore needs the complete project graph and the linked release manifest.
COPY . .
RUN dotnet restore "src/ApiHost/IFX.ApiHost/IFX.ApiHost.csproj"

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
