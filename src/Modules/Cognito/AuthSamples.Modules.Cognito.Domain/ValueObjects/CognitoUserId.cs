namespace AuthSamples.Modules.Cognito.Domain.ValueObjects;

public class CognitoUserId : IEquatable<CognitoUserId>
{
    public string Value { get; private set; }

    private CognitoUserId(string value)
    {
        Value = value;
    }

    public static CognitoUserId Create(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            throw new ArgumentException("Cognito User ID cannot be empty", nameof(value));

        return new CognitoUserId(value);
    }

    public bool Equals(CognitoUserId? other)
    {
        if (other is null) return false;
        return Value == other.Value;
    }

    public override bool Equals(object? obj)
    {
        return obj is CognitoUserId other && Equals(other);
    }

    public override int GetHashCode()
    {
        return Value.GetHashCode();
    }

    public static bool operator ==(CognitoUserId? left, CognitoUserId? right)
    {
        if (left is null && right is null) return true;
        if (left is null || right is null) return false;
        return left.Equals(right);
    }

    public static bool operator !=(CognitoUserId? left, CognitoUserId? right)
    {
        return !(left == right);
    }

    public override string ToString() => Value;
}
