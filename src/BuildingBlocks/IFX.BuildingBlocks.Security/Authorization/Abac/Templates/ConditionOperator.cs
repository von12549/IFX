namespace IFX.BuildingBlocks.Security.Authorization.Abac.Templates;

public enum ConditionOperator
{
    /// <summary>Left equals Right (scalar comparison).</summary>
    Equals,

    /// <summary>Left does not equal Right.</summary>
    NotEquals,

    /// <summary>Scalar Left is a member of collection Right.</summary>
    In,

    /// <summary>Scalar Left is not a member of collection Right.</summary>
    NotIn,

    /// <summary>Collection Left contains scalar Right.</summary>
    Contains,

    /// <summary>Collections Left and Right share at least one element.</summary>
    Intersects
}
