namespace IFX.Modules.CRM.Domain.Enums;

public enum PartyRelationshipType
{
    /// <summary>FromParty belongs to ToParty (e.g. rep belongs to firm)</summary>
    ParentFirm = 1,

    /// <summary>FromParty is authorised to advise ToParty (investor)</summary>
    AuthorizedToAdvise = 2,

    /// <summary>FromParty is beneficial owner of ToParty (corporate entity)</summary>
    BeneficialOwner = 3,

    /// <summary>FromParty controls ToParty (subsidiary)</summary>
    ControllingEntity = 4,

    /// <summary>FromParty is a beneficiary of ToParty (trust)</summary>
    TrustBeneficiary = 5
}
