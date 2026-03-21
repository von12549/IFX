using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.Auth.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddRbacRoleGroupsAndPermissions : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Users_UserRoles_UserRoleId",
                schema: "auth",
                table: "Users");

            migrationBuilder.DropIndex(
                name: "IX_Users_UserRoleId",
                schema: "auth",
                table: "Users");

            // Clear the old role-definition rows (Admin, User, SsoUser, PendingUser).
            // The old auth.UserRoles was a role-definitions table (not a join table).
            // These rows would otherwise remain as orphaned rows with RolesId = Guid.Empty
            // after the structural changes below, causing the FK constraint to fail.
            // Roles are re-seeded in the new auth.Roles table later in this migration.
            migrationBuilder.Sql("DELETE FROM [auth].[UserRoles]");

            migrationBuilder.DropPrimaryKey(
                name: "PK_UserRoles",
                schema: "auth",
                table: "UserRoles");

            migrationBuilder.DropIndex(
                name: "IX_UserRoles_RoleName",
                schema: "auth",
                table: "UserRoles");

            migrationBuilder.DropColumn(
                name: "UserRoleId",
                schema: "auth",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "CreatedAt",
                schema: "auth",
                table: "UserRoles");

            migrationBuilder.DropColumn(
                name: "Description",
                schema: "auth",
                table: "UserRoles");

            migrationBuilder.DropColumn(
                name: "RoleName",
                schema: "auth",
                table: "UserRoles");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                schema: "auth",
                table: "UserRoles");

            migrationBuilder.RenameColumn(
                name: "Id",
                schema: "auth",
                table: "UserRoles",
                newName: "UserId");

            migrationBuilder.AddColumn<Guid>(
                name: "RolesId",
                schema: "auth",
                table: "UserRoles",
                type: "uniqueidentifier",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.AddPrimaryKey(
                name: "PK_UserRoles",
                schema: "auth",
                table: "UserRoles",
                columns: new[] { "RolesId", "UserId" });

            migrationBuilder.CreateTable(
                name: "Permissions",
                schema: "auth",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Permissions", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "RoleGroups",
                schema: "auth",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RoleGroups", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Roles",
                schema: "auth",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Roles", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "UserRoleGroups",
                schema: "auth",
                columns: table => new
                {
                    RoleGroupsId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserRoleGroups", x => new { x.RoleGroupsId, x.UserId });
                    table.ForeignKey(
                        name: "FK_UserRoleGroups_RoleGroups_RoleGroupsId",
                        column: x => x.RoleGroupsId,
                        principalSchema: "auth",
                        principalTable: "RoleGroups",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_UserRoleGroups_Users_UserId",
                        column: x => x.UserId,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "RoleGroupRoles",
                schema: "auth",
                columns: table => new
                {
                    RoleGroupId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RolesId = table.Column<Guid>(type: "uniqueidentifier", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RoleGroupRoles", x => new { x.RoleGroupId, x.RolesId });
                    table.ForeignKey(
                        name: "FK_RoleGroupRoles_RoleGroups_RoleGroupId",
                        column: x => x.RoleGroupId,
                        principalSchema: "auth",
                        principalTable: "RoleGroups",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_RoleGroupRoles_Roles_RolesId",
                        column: x => x.RolesId,
                        principalSchema: "auth",
                        principalTable: "Roles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "RolePermissions",
                schema: "auth",
                columns: table => new
                {
                    PermissionsId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RoleId = table.Column<Guid>(type: "uniqueidentifier", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RolePermissions", x => new { x.PermissionsId, x.RoleId });
                    table.ForeignKey(
                        name: "FK_RolePermissions_Permissions_PermissionsId",
                        column: x => x.PermissionsId,
                        principalSchema: "auth",
                        principalTable: "Permissions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_RolePermissions_Roles_RoleId",
                        column: x => x.RoleId,
                        principalSchema: "auth",
                        principalTable: "Roles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_UserRoles_UserId",
                schema: "auth",
                table: "UserRoles",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_Permissions_Name",
                schema: "auth",
                table: "Permissions",
                column: "Name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RoleGroupRoles_RolesId",
                schema: "auth",
                table: "RoleGroupRoles",
                column: "RolesId");

            migrationBuilder.CreateIndex(
                name: "IX_RoleGroups_Name",
                schema: "auth",
                table: "RoleGroups",
                column: "Name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RolePermissions_RoleId",
                schema: "auth",
                table: "RolePermissions",
                column: "RoleId");

            migrationBuilder.CreateIndex(
                name: "IX_Roles_Name",
                schema: "auth",
                table: "Roles",
                column: "Name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserRoleGroups_UserId",
                schema: "auth",
                table: "UserRoleGroups",
                column: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_UserRoles_Roles_RolesId",
                schema: "auth",
                table: "UserRoles",
                column: "RolesId",
                principalSchema: "auth",
                principalTable: "Roles",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserRoles_Users_UserId",
                schema: "auth",
                table: "UserRoles",
                column: "UserId",
                principalSchema: "auth",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            // Seed permissions
            var now = DateTime.UtcNow;
            var permUserRead    = Guid.NewGuid();
            var permUserWrite   = Guid.NewGuid();
            var permRoleRead    = Guid.NewGuid();
            var permRoleWrite   = Guid.NewGuid();
            var permRoleGroupRead  = Guid.NewGuid();
            var permRoleGroupWrite = Guid.NewGuid();
            var permPermRead    = Guid.NewGuid();
            var permPermWrite   = Guid.NewGuid();
            var permIdpRead     = Guid.NewGuid();
            var permIdpWrite    = Guid.NewGuid();

            migrationBuilder.InsertData(
                schema: "auth",
                table: "Permissions",
                columns: new[] { "Id", "Name", "Description", "CreatedAt", "UpdatedAt" },
                values: new object[,]
                {
                    { permUserRead,    "User.Read",         "View user data",                now, now },
                    { permUserWrite,   "User.Write",        "Create/update user data",       now, now },
                    { permRoleRead,    "Role.Read",         "View roles",                    now, now },
                    { permRoleWrite,   "Role.Write",        "Create/update roles",           now, now },
                    { permRoleGroupRead,  "RoleGroup.Read", "View role groups",              now, now },
                    { permRoleGroupWrite, "RoleGroup.Write","Create/update role groups",     now, now },
                    { permPermRead,    "Permission.Read",   "View permissions",              now, now },
                    { permPermWrite,   "Permission.Write",  "Create/update permissions",     now, now },
                    { permIdpRead,     "Idp.Read",          "View identity providers",       now, now },
                    { permIdpWrite,    "Idp.Write",         "Create/update identity providers", now, now }
                });

            // Seed roles
            var roleAdmin   = Guid.NewGuid();
            var roleUser    = Guid.NewGuid();
            var roleSsoUser = Guid.NewGuid();
            var rolePending = Guid.NewGuid();

            migrationBuilder.InsertData(
                schema: "auth",
                table: "Roles",
                columns: new[] { "Id", "Name", "Description", "CreatedAt", "UpdatedAt" },
                values: new object[,]
                {
                    { roleAdmin,   "Admin",       "Administrator with full access",          now, now },
                    { roleUser,    "User",         "Standard user with limited permissions", now, now },
                    { roleSsoUser, "SsoUser",      "SSO authenticated user",                 now, now },
                    { rolePending, "PendingUser",  "Pending user awaiting approval",         now, now }
                });

            // Seed role-permission assignments
            // Admin: all 10
            migrationBuilder.InsertData(
                schema: "auth",
                table: "RolePermissions",
                columns: new[] { "RoleId", "PermissionsId" },
                values: new object[,]
                {
                    { roleAdmin, permUserRead    },
                    { roleAdmin, permUserWrite   },
                    { roleAdmin, permRoleRead    },
                    { roleAdmin, permRoleWrite   },
                    { roleAdmin, permRoleGroupRead  },
                    { roleAdmin, permRoleGroupWrite },
                    { roleAdmin, permPermRead    },
                    { roleAdmin, permPermWrite   },
                    { roleAdmin, permIdpRead     },
                    { roleAdmin, permIdpWrite    },
                    // User: User.Read + User.Write
                    { roleUser,    permUserRead  },
                    { roleUser,    permUserWrite },
                    // SsoUser: User.Read
                    { roleSsoUser, permUserRead  },
                    // PendingUser: User.Read
                    { rolePending, permUserRead  }
                });

            // Seed role group
            var groupTestGroup = Guid.NewGuid();

            migrationBuilder.InsertData(
                schema: "auth",
                table: "RoleGroups",
                columns: new[] { "Id", "Name", "Description", "CreatedAt", "UpdatedAt" },
                values: new object[] { groupTestGroup, "TestGroup", "Test role group", now, now });

            // TestGroup contains Admin, User, SsoUser
            migrationBuilder.InsertData(
                schema: "auth",
                table: "RoleGroupRoles",
                columns: new[] { "RoleGroupId", "RolesId" },
                values: new object[,]
                {
                    { groupTestGroup, roleAdmin   },
                    { groupTestGroup, roleUser    },
                    { groupTestGroup, roleSsoUser }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_UserRoles_Roles_RolesId",
                schema: "auth",
                table: "UserRoles");

            migrationBuilder.DropForeignKey(
                name: "FK_UserRoles_Users_UserId",
                schema: "auth",
                table: "UserRoles");

            migrationBuilder.DropTable(
                name: "RoleGroupRoles",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "RolePermissions",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "UserRoleGroups",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "Permissions",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "Roles",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "RoleGroups",
                schema: "auth");

            migrationBuilder.DropPrimaryKey(
                name: "PK_UserRoles",
                schema: "auth",
                table: "UserRoles");

            migrationBuilder.DropIndex(
                name: "IX_UserRoles_UserId",
                schema: "auth",
                table: "UserRoles");

            migrationBuilder.DropColumn(
                name: "RolesId",
                schema: "auth",
                table: "UserRoles");

            migrationBuilder.RenameColumn(
                name: "UserId",
                schema: "auth",
                table: "UserRoles",
                newName: "Id");

            migrationBuilder.AddColumn<Guid>(
                name: "UserRoleId",
                schema: "auth",
                table: "Users",
                type: "uniqueidentifier",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.AddColumn<DateTime>(
                name: "CreatedAt",
                schema: "auth",
                table: "UserRoles",
                type: "datetime2",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<string>(
                name: "Description",
                schema: "auth",
                table: "UserRoles",
                type: "nvarchar(255)",
                maxLength: 255,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "RoleName",
                schema: "auth",
                table: "UserRoles",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                schema: "auth",
                table: "UserRoles",
                type: "datetime2",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddPrimaryKey(
                name: "PK_UserRoles",
                schema: "auth",
                table: "UserRoles",
                column: "Id");

            migrationBuilder.CreateIndex(
                name: "IX_Users_UserRoleId",
                schema: "auth",
                table: "Users",
                column: "UserRoleId");

            migrationBuilder.CreateIndex(
                name: "IX_UserRoles_RoleName",
                schema: "auth",
                table: "UserRoles",
                column: "RoleName",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Users_UserRoles_UserRoleId",
                schema: "auth",
                table: "Users",
                column: "UserRoleId",
                principalSchema: "auth",
                principalTable: "UserRoles",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
