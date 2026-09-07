namespace IFX.BuildingBlocks.Domain;

public sealed class DomainRuleViolationException(string message) : Exception(message);
