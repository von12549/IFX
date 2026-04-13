using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IFX.Modules.CRM.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "crm");

            migrationBuilder.CreateTable(
                name: "InvestmentAccounts",
                schema: "crm",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TenantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AccountNumber = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    AccountType = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    CertificateDate = table.Column<DateOnly>(type: "date", nullable: true),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_InvestmentAccounts", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Investors",
                schema: "crm",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TenantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PartyId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    InvestorCode = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    LegalStructure = table.Column<int>(type: "int", nullable: false),
                    KycStatus = table.Column<int>(type: "int", nullable: false),
                    KycReviewedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    TaxResidencyCountry = table.Column<string>(type: "nvarchar(2)", maxLength: 2, nullable: true),
                    TIN = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    FatcaCrsStatus = table.Column<int>(type: "int", nullable: false),
                    GIIN = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    AmlStatus = table.Column<int>(type: "int", nullable: false),
                    AmlGatewayReference = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    AmlCheckedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    IsPEP = table.Column<bool>(type: "bit", nullable: true),
                    PepDetails = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    SourceOfWealth = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    UnresolvedPepCount = table.Column<int>(type: "int", nullable: false),
                    UnresolvedSanctionCount = table.Column<int>(type: "int", nullable: false),
                    UnresolvedAdverseMediaCount = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Investors", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Parties",
                schema: "crm",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TenantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PartyCode = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    LegalStructure = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Parties", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "CorporateInvestorProfiles",
                schema: "crm",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    InvestorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Acn = table.Column<string>(type: "nvarchar(9)", maxLength: 9, nullable: true),
                    Abn = table.Column<string>(type: "nvarchar(11)", maxLength: 11, nullable: true),
                    RegistrationNumber = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    CountryOfIncorporation = table.Column<string>(type: "nvarchar(2)", maxLength: 2, nullable: true),
                    IncorporationDate = table.Column<DateOnly>(type: "date", nullable: true),
                    IsPubliclyListed = table.Column<bool>(type: "bit", nullable: true),
                    Regulator = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    LicenceNumber = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    FrankieOneEntityId = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CorporateInvestorProfiles", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CorporateInvestorProfiles_Investors_InvestorId",
                        column: x => x.InvestorId,
                        principalSchema: "crm",
                        principalTable: "Investors",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "IndividualInvestorProfiles",
                schema: "crm",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    InvestorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DateOfBirth = table.Column<DateOnly>(type: "date", nullable: true),
                    DateOfDeath = table.Column<DateOnly>(type: "date", nullable: true),
                    Gender = table.Column<int>(type: "int", nullable: true),
                    PlaceOfBirth = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Nationality = table.Column<string>(type: "nvarchar(2)", maxLength: 2, nullable: true),
                    IdDocumentType = table.Column<int>(type: "int", nullable: true),
                    IdDocumentNumber = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    IdDocumentCountry = table.Column<string>(type: "nvarchar(2)", maxLength: 2, nullable: true),
                    IdDocumentExpiry = table.Column<DateOnly>(type: "date", nullable: true),
                    FrankieOneEntityId = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_IndividualInvestorProfiles", x => x.Id);
                    table.ForeignKey(
                        name: "FK_IndividualInvestorProfiles_Investors_InvestorId",
                        column: x => x.InvestorId,
                        principalSchema: "crm",
                        principalTable: "Investors",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "InvestorDocuments",
                schema: "crm",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    InvestorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TenantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DocumentType = table.Column<int>(type: "int", nullable: false),
                    DocumentNumber = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    IssueCountry = table.Column<string>(type: "nvarchar(2)", maxLength: 2, nullable: false),
                    IssueState = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    IssueDate = table.Column<DateOnly>(type: "date", nullable: true),
                    ExpiryDate = table.Column<DateOnly>(type: "date", nullable: true),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_InvestorDocuments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_InvestorDocuments_Investors_InvestorId",
                        column: x => x.InvestorId,
                        principalSchema: "crm",
                        principalTable: "Investors",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "TrustInvestorProfiles",
                schema: "crm",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    InvestorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TrustType = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    TrustDeedReference = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    TrustEstablishedDate = table.Column<DateOnly>(type: "date", nullable: true),
                    TrusteePartyId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    FrankieOneEntityId = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TrustInvestorProfiles", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TrustInvestorProfiles_Investors_InvestorId",
                        column: x => x.InvestorId,
                        principalSchema: "crm",
                        principalTable: "Investors",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "AdvisorInvestmentAccountLinks",
                schema: "crm",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TenantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AdvisorPartyId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    InvestmentAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RebateRate = table.Column<decimal>(type: "decimal(5,2)", precision: 5, scale: 2, nullable: false),
                    EffectiveDate = table.Column<DateOnly>(type: "date", nullable: false),
                    ExpiryDate = table.Column<DateOnly>(type: "date", nullable: true),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AdvisorInvestmentAccountLinks", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AdvisorInvestmentAccountLinks_InvestmentAccounts_InvestmentAccountId",
                        column: x => x.InvestmentAccountId,
                        principalSchema: "crm",
                        principalTable: "InvestmentAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_AdvisorInvestmentAccountLinks_Parties_AdvisorPartyId",
                        column: x => x.AdvisorPartyId,
                        principalSchema: "crm",
                        principalTable: "Parties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PartyInvestmentAccountLinks",
                schema: "crm",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TenantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PartyId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    InvestmentAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RelationshipType = table.Column<int>(type: "int", nullable: false),
                    OwnershipPercentage = table.Column<decimal>(type: "decimal(5,2)", precision: 5, scale: 2, nullable: true),
                    LinkOrder = table.Column<int>(type: "int", nullable: false),
                    EffectiveDate = table.Column<DateOnly>(type: "date", nullable: false),
                    ExpiryDate = table.Column<DateOnly>(type: "date", nullable: true),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PartyInvestmentAccountLinks", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PartyInvestmentAccountLinks_InvestmentAccounts_InvestmentAccountId",
                        column: x => x.InvestmentAccountId,
                        principalSchema: "crm",
                        principalTable: "InvestmentAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_PartyInvestmentAccountLinks_Parties_PartyId",
                        column: x => x.PartyId,
                        principalSchema: "crm",
                        principalTable: "Parties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PartyRelationships",
                schema: "crm",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TenantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FromPartyId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ToPartyId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RelationshipType = table.Column<int>(type: "int", nullable: false),
                    EffectiveDate = table.Column<DateOnly>(type: "date", nullable: false),
                    ExpiryDate = table.Column<DateOnly>(type: "date", nullable: true),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PartyRelationships", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PartyRelationships_Parties_FromPartyId",
                        column: x => x.FromPartyId,
                        principalSchema: "crm",
                        principalTable: "Parties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_PartyRelationships_Parties_ToPartyId",
                        column: x => x.ToPartyId,
                        principalSchema: "crm",
                        principalTable: "Parties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PartyRoleAssignments",
                schema: "crm",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TenantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PartyId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Role = table.Column<int>(type: "int", nullable: false),
                    AssignedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    AssignedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PartyRoleAssignments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PartyRoleAssignments_Parties_PartyId",
                        column: x => x.PartyId,
                        principalSchema: "crm",
                        principalTable: "Parties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "UserPartyLinks",
                schema: "crm",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PartyId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TenantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserPartyLinks", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserPartyLinks_Parties_PartyId",
                        column: x => x.PartyId,
                        principalSchema: "crm",
                        principalTable: "Parties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AdvisorInvestmentAccountLinks_AdvisorPartyId",
                schema: "crm",
                table: "AdvisorInvestmentAccountLinks",
                column: "AdvisorPartyId");

            migrationBuilder.CreateIndex(
                name: "IX_AdvisorInvestmentAccountLinks_InvestmentAccountId",
                schema: "crm",
                table: "AdvisorInvestmentAccountLinks",
                column: "InvestmentAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_AdvisorInvestmentAccountLinks_TenantId_AccountId_AdvisorPartyId",
                schema: "crm",
                table: "AdvisorInvestmentAccountLinks",
                columns: new[] { "TenantId", "InvestmentAccountId", "AdvisorPartyId" });

            migrationBuilder.CreateIndex(
                name: "IX_CorporateInvestorProfiles_InvestorId",
                schema: "crm",
                table: "CorporateInvestorProfiles",
                column: "InvestorId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_IndividualInvestorProfiles_InvestorId",
                schema: "crm",
                table: "IndividualInvestorProfiles",
                column: "InvestorId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_InvestmentAccounts_TenantId_AccountNumber",
                schema: "crm",
                table: "InvestmentAccounts",
                columns: new[] { "TenantId", "AccountNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_InvestorDocuments_InvestorId",
                schema: "crm",
                table: "InvestorDocuments",
                column: "InvestorId");

            migrationBuilder.CreateIndex(
                name: "IX_InvestorDocuments_TenantId_InvestorId",
                schema: "crm",
                table: "InvestorDocuments",
                columns: new[] { "TenantId", "InvestorId" });

            migrationBuilder.CreateIndex(
                name: "IX_Investors_TenantId_InvestorCode",
                schema: "crm",
                table: "Investors",
                columns: new[] { "TenantId", "InvestorCode" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Investors_TenantId_PartyId",
                schema: "crm",
                table: "Investors",
                columns: new[] { "TenantId", "PartyId" },
                unique: true,
                filter: "[PartyId] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_Parties_TenantId_PartyCode",
                schema: "crm",
                table: "Parties",
                columns: new[] { "TenantId", "PartyCode" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PartyInvestmentAccountLinks_InvestmentAccountId",
                schema: "crm",
                table: "PartyInvestmentAccountLinks",
                column: "InvestmentAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_PartyInvestmentAccountLinks_PartyId",
                schema: "crm",
                table: "PartyInvestmentAccountLinks",
                column: "PartyId");

            migrationBuilder.CreateIndex(
                name: "IX_PartyInvestmentAccountLinks_TenantId_AccountId_PartyId",
                schema: "crm",
                table: "PartyInvestmentAccountLinks",
                columns: new[] { "TenantId", "InvestmentAccountId", "PartyId" });

            migrationBuilder.CreateIndex(
                name: "IX_PartyRelationships_FromPartyId",
                schema: "crm",
                table: "PartyRelationships",
                column: "FromPartyId");

            migrationBuilder.CreateIndex(
                name: "IX_PartyRelationships_TenantId_FromPartyId_Type",
                schema: "crm",
                table: "PartyRelationships",
                columns: new[] { "TenantId", "FromPartyId", "RelationshipType" });

            migrationBuilder.CreateIndex(
                name: "IX_PartyRelationships_ToPartyId",
                schema: "crm",
                table: "PartyRelationships",
                column: "ToPartyId");

            migrationBuilder.CreateIndex(
                name: "IX_PartyRoleAssignments_PartyId",
                schema: "crm",
                table: "PartyRoleAssignments",
                column: "PartyId");

            migrationBuilder.CreateIndex(
                name: "IX_PartyRoleAssignments_TenantId_PartyId_Role",
                schema: "crm",
                table: "PartyRoleAssignments",
                columns: new[] { "TenantId", "PartyId", "Role" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TrustInvestorProfiles_InvestorId",
                schema: "crm",
                table: "TrustInvestorProfiles",
                column: "InvestorId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserPartyLinks_PartyId",
                schema: "crm",
                table: "UserPartyLinks",
                column: "PartyId");

            migrationBuilder.CreateIndex(
                name: "IX_UserPartyLinks_TenantId_PartyId",
                schema: "crm",
                table: "UserPartyLinks",
                columns: new[] { "TenantId", "PartyId" });

            migrationBuilder.CreateIndex(
                name: "IX_UserPartyLinks_TenantId_UserId",
                schema: "crm",
                table: "UserPartyLinks",
                columns: new[] { "TenantId", "UserId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AdvisorInvestmentAccountLinks",
                schema: "crm");

            migrationBuilder.DropTable(
                name: "CorporateInvestorProfiles",
                schema: "crm");

            migrationBuilder.DropTable(
                name: "IndividualInvestorProfiles",
                schema: "crm");

            migrationBuilder.DropTable(
                name: "InvestorDocuments",
                schema: "crm");

            migrationBuilder.DropTable(
                name: "PartyInvestmentAccountLinks",
                schema: "crm");

            migrationBuilder.DropTable(
                name: "PartyRelationships",
                schema: "crm");

            migrationBuilder.DropTable(
                name: "PartyRoleAssignments",
                schema: "crm");

            migrationBuilder.DropTable(
                name: "TrustInvestorProfiles",
                schema: "crm");

            migrationBuilder.DropTable(
                name: "UserPartyLinks",
                schema: "crm");

            migrationBuilder.DropTable(
                name: "InvestmentAccounts",
                schema: "crm");

            migrationBuilder.DropTable(
                name: "Investors",
                schema: "crm");

            migrationBuilder.DropTable(
                name: "Parties",
                schema: "crm");
        }
    }
}
