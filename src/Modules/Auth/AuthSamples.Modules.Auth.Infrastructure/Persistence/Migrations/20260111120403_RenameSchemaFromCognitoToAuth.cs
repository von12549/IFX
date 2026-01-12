using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AuthSamples.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class RenameSchemaFromCognitoToAuth : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "auth");

            migrationBuilder.RenameTable(
                name: "Users",
                schema: "cognito",
                newName: "Users",
                newSchema: "auth");

            migrationBuilder.RenameTable(
                name: "UserRoles",
                schema: "cognito",
                newName: "UserRoles",
                newSchema: "auth");

            migrationBuilder.RenameTable(
                name: "UserActivityLogs",
                schema: "cognito",
                newName: "UserActivityLogs",
                newSchema: "auth");

            migrationBuilder.RenameTable(
                name: "RegistrationFlowEvents",
                schema: "cognito",
                newName: "RegistrationFlowEvents",
                newSchema: "auth");

            migrationBuilder.RenameTable(
                name: "LogoutEvents",
                schema: "cognito",
                newName: "LogoutEvents",
                newSchema: "auth");

            migrationBuilder.RenameTable(
                name: "LoginEvents",
                schema: "cognito",
                newName: "LoginEvents",
                newSchema: "auth");

            migrationBuilder.RenameTable(
                name: "Idps",
                schema: "cognito",
                newName: "Idps",
                newSchema: "auth");

            // Drop the old cognito schema after all tables have been moved
            migrationBuilder.Sql("DROP SCHEMA IF EXISTS cognito;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Recreate the cognito schema for rollback
            migrationBuilder.EnsureSchema(
                name: "cognito");

            migrationBuilder.RenameTable(
                name: "Users",
                schema: "auth",
                newName: "Users",
                newSchema: "cognito");

            migrationBuilder.RenameTable(
                name: "UserRoles",
                schema: "auth",
                newName: "UserRoles",
                newSchema: "cognito");

            migrationBuilder.RenameTable(
                name: "UserActivityLogs",
                schema: "auth",
                newName: "UserActivityLogs",
                newSchema: "cognito");

            migrationBuilder.RenameTable(
                name: "RegistrationFlowEvents",
                schema: "auth",
                newName: "RegistrationFlowEvents",
                newSchema: "cognito");

            migrationBuilder.RenameTable(
                name: "LogoutEvents",
                schema: "auth",
                newName: "LogoutEvents",
                newSchema: "cognito");

            migrationBuilder.RenameTable(
                name: "LoginEvents",
                schema: "auth",
                newName: "LoginEvents",
                newSchema: "cognito");

            migrationBuilder.RenameTable(
                name: "Idps",
                schema: "auth",
                newName: "Idps",
                newSchema: "cognito");

            // Drop the auth schema after rollback
            migrationBuilder.Sql("DROP SCHEMA IF EXISTS auth;");
        }
    }
}
