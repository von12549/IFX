using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddCreatedByToResources : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "CreatedBy",
                schema: "auth",
                table: "Users",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "CreatedBy",
                schema: "auth",
                table: "UserIdentities",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "CreatedBy",
                schema: "auth",
                table: "Tenants",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "CreatedBy",
                schema: "auth",
                table: "Roles",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "CreatedBy",
                schema: "auth",
                table: "RoleGroups",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "CreatedBy",
                schema: "auth",
                table: "Idps",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "CreatedBy",
                schema: "auth",
                table: "Departments",
                type: "uniqueidentifier",
                nullable: true);

            // Backfill: non-user tables → Xiaolong Feng
            var adminUserId = "8314F7DA-2F5D-4128-A705-957CE0C3972E";
            migrationBuilder.Sql($"UPDATE auth.Roles           SET CreatedBy = '{adminUserId}' WHERE CreatedBy IS NULL;");
            migrationBuilder.Sql($"UPDATE auth.RoleGroups      SET CreatedBy = '{adminUserId}' WHERE CreatedBy IS NULL;");
            migrationBuilder.Sql($"UPDATE auth.Departments     SET CreatedBy = '{adminUserId}' WHERE CreatedBy IS NULL;");
            migrationBuilder.Sql($"UPDATE auth.Idps            SET CreatedBy = '{adminUserId}' WHERE CreatedBy IS NULL;");
            migrationBuilder.Sql($"UPDATE auth.Tenants         SET CreatedBy = '{adminUserId}' WHERE CreatedBy IS NULL;");

            // Backfill: Users and UserIdentities → self-created
            migrationBuilder.Sql("UPDATE auth.Users           SET CreatedBy = Id       WHERE CreatedBy IS NULL;");
            migrationBuilder.Sql("UPDATE auth.UserIdentities  SET CreatedBy = UserId   WHERE CreatedBy IS NULL;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CreatedBy",
                schema: "auth",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "CreatedBy",
                schema: "auth",
                table: "UserIdentities");

            migrationBuilder.DropColumn(
                name: "CreatedBy",
                schema: "auth",
                table: "Tenants");

            migrationBuilder.DropColumn(
                name: "CreatedBy",
                schema: "auth",
                table: "Roles");

            migrationBuilder.DropColumn(
                name: "CreatedBy",
                schema: "auth",
                table: "RoleGroups");

            migrationBuilder.DropColumn(
                name: "CreatedBy",
                schema: "auth",
                table: "Idps");

            migrationBuilder.DropColumn(
                name: "CreatedBy",
                schema: "auth",
                table: "Departments");
        }
    }
}
