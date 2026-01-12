# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy solution and project files
COPY ["src/Modules/Cognito/AuthSamples.Modules.Auth.API/AuthSamples.Modules.Auth.API.csproj", "src/Modules/Cognito/AuthSamples.Modules.Auth.API/"]
COPY ["src/Modules/Cognito/AuthSamples.Modules.Auth.Application/AuthSamples.Modules.Auth.Application.csproj", "src/Modules/Cognito/AuthSamples.Modules.Auth.Application/"]
COPY ["src/Modules/Cognito/AuthSamples.Modules.Auth.Domain/AuthSamples.Modules.Auth.Domain.csproj", "src/Modules/Cognito/AuthSamples.Modules.Auth.Domain/"]
COPY ["src/Modules/Cognito/AuthSamples.Modules.Auth.Infrastructure/AuthSamples.Modules.Auth.Infrastructure.csproj", "src/Modules/Cognito/AuthSamples.Modules.Auth.Infrastructure/"]

# Restore dependencies
RUN dotnet restore "src/Modules/Cognito/AuthSamples.Modules.Auth.API/AuthSamples.Modules.Auth.API.csproj"

# Copy all source files
COPY . .

# Build the application
WORKDIR "/src/src/Modules/Cognito/AuthSamples.Modules.Auth.API"
RUN dotnet build "AuthSamples.Modules.Auth.API.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "AuthSamples.Modules.Auth.API.csproj" -c Release -o /app/publish /p:UseAppHost=false

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

ENTRYPOINT ["dotnet", "AuthSamples.Modules.Auth.API.dll"]
