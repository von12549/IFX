FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish src/DatabaseMigrator/IFX.DatabaseMigrator/IFX.DatabaseMigrator.csproj \
    --configuration Release \
    --output /app/publish \
    /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/runtime:8.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "IFX.DatabaseMigrator.dll"]
CMD ["--mode", "apply", "--report", "/reports/database-migration.json"]
