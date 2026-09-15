using LayerGuard;
using Xunit;

namespace LayerGuard.Tests;

public class BootstrapArchitectureTests
{
    private static Report Report => Fixtures.Check(Fixtures.BootstrapArchitecture);

    [Theory]
    [InlineData("Acme.Sales.Contracts", "Contracts", "Sales")]
    [InlineData("Acme.Billing.Integration", "IntegrationAdapter", "Billing")]
    [InlineData("Acme.Billing.Composition", "Composition", "Billing")]
    [InlineData("Acme.ApiHost", "RuntimeHost", null)]
    public void Project_roles_and_ownership_are_recognised(string project, string role, string? module)
    {
        var item = Report.Projects.Single(candidate => candidate.Name == project);
        Assert.Equal(role, item.Ring);
        Assert.Equal(module, item.Module);
    }

    [Fact]
    public void Domain_to_contracts_and_application_to_module_contracts_are_rejected()
    {
        Assert.Contains(Report.Violations, finding =>
            finding.FromProject == "Acme.Billing.Domain"
            && finding.ToProject == "Acme.Sales.Contracts"
            && finding.Rule == ReferenceRules.DirectionRule);
        Assert.Contains(Report.Violations, finding =>
            finding.FromProject == "Acme.Billing.Application"
            && finding.ToProject == "Acme.Billing.Contracts"
            && finding.Rule == OwnershipRules.ScopeRule);
        Assert.Contains(Report.Violations, finding =>
            finding.FromProject == "Acme.Billing.Application"
            && finding.ToProject == "Acme.Sales.Contracts"
            && finding.Rule == OwnershipRules.ScopeRule);
        Assert.Contains(Report.Violations, finding =>
            finding.FromProject == "Acme.Billing.Application"
            && finding.ToProject == "Acme.BillingPlus.Contracts"
            && finding.Rule == OwnershipRules.ScopeRule);
    }

    [Fact]
    public void A_registered_standalone_adapter_can_use_provider_contracts()
    {
        Assert.DoesNotContain(Report.Violations, finding =>
            finding.FromProject == "Acme.Billing.Integration"
            && finding.ToProject == "Acme.Sales.Contracts");
    }

    [Fact]
    public void Adapter_must_implement_an_application_port()
    {
        Assert.DoesNotContain(Report.Violations, finding => finding.ToProject == "SalesAdapter"
            && finding.Rule == SourcePolicyRules.NamespaceRuleId);
        Assert.Contains(Report.Violations, finding => finding.ToProject == "BrokenAdapter"
            && finding.Rule == SourcePolicyRules.NamespaceRuleId);
    }

    [Fact]
    public void Inbound_adapter_must_implement_its_provider_contract()
    {
        Assert.DoesNotContain(Report.Violations, finding => finding.ToProject == "BillingInboundAdapter"
            && finding.Rule == SourcePolicyRules.NamespaceRuleId);
        Assert.Contains(Report.Violations, finding => finding.ToProject == "BrokenInboundAdapter"
            && finding.Rule == SourcePolicyRules.NamespaceRuleId);
    }

    [Fact]
    public void Embedded_adapter_permission_is_limited_to_its_namespace()
    {
        var finding = Assert.Single(Report.Violations, finding =>
            finding.Rule == EmbeddedAdapterRules.LocationRule);
        Assert.EndsWith("LeakingRepository.cs", finding.Evidence.File);
    }

    [Fact]
    public void Runtime_host_may_load_composition_but_not_presentation()
    {
        Assert.DoesNotContain(Report.Violations, finding =>
            finding.FromProject == "Acme.ApiHost"
            && finding.ToProject == "Acme.Billing.Composition");
        Assert.Contains(Report.Violations, finding =>
            finding.FromProject == "Acme.ApiHost"
            && finding.ToProject == "Acme.Billing.Presentation"
            && finding.Rule == ReferenceRules.DirectionRule);
    }

    [Fact]
    public void Legacy_project_names_are_reported_even_though_their_role_is_understood()
    {
        var finding = Assert.Single(Report.Violations, item =>
            item.Rule == OwnershipRules.ProjectNameRule);
        Assert.Equal("Contracts", finding.FromRing);
        Assert.Equal("Acme.Legacy.Abstractions", finding.FromProject);
    }

    [Fact]
    public void Test_projects_are_outside_production_role_matching_and_generated_code_is_skipped()
    {
        Assert.Contains(Report.Outside, project => project.Name == "Acme.Billing.Application.Tests");
        Assert.DoesNotContain(Report.Violations, finding => finding.Evidence.File.EndsWith("Ignored.generated.cs"));
    }

    [Fact]
    public void Contracts_cycles_are_reported()
    {
        Assert.Contains(Report.Violations, finding => finding.Rule == OwnershipRules.ContractCycleRule);
    }

    [Fact]
    public void Contract_framework_implementation_and_payload_leaks_are_reported()
    {
        Assert.Contains(Report.Violations, finding => finding.Rule == SourcePolicyRules.ForbiddenSymbolRuleId);
        Assert.Contains(Report.Violations, finding => finding.Rule == SourcePolicyRules.ForbiddenDeclarationRuleId
            && finding.ToProject == "BillingDbContext");
        Assert.DoesNotContain(Report.Violations, finding => finding.Rule == SourcePolicyRules.ForbiddenDeclarationRuleId
            && finding.ToProject == "CompatibilityHandler");
        Assert.Contains(Report.Violations, finding => finding.Rule == SourcePolicyRules.PayloadRuleId);
        Assert.Contains(Report.Violations, finding => finding.Rule == SourcePolicyRules.NamespaceRuleId
            && finding.ToProject == "BillingIntegrationEvent");
    }

    [Fact]
    public void Bcl_only_contract_context_is_accepted()
    {
        Assert.DoesNotContain(Report.Violations, finding =>
            finding.Evidence.File.EndsWith("Context.cs")
            && finding.ToProject == "ContractRequestContext");
    }
}
