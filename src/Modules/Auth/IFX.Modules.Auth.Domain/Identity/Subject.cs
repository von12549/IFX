namespace IFX.Modules.Auth.Domain.ValueObjects;

public class Subject : IEquatable<Subject>
{
    public string Value { get; private set; }

    private Subject(string value)
    {
        Value = value;
    }

    public static Subject Create(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            throw new ArgumentException("Subject cannot be empty", nameof(value));

        return new Subject(value);
    }

    public bool Equals(Subject? other)
    {
        if (other is null) return false;
        return Value == other.Value;
    }

    public override bool Equals(object? obj)
    {
        return obj is Subject other && Equals(other);
    }

    public override int GetHashCode()
    {
        return Value.GetHashCode();
    }

    public static bool operator ==(Subject? left, Subject? right)
    {
        if (left is null && right is null) return true;
        if (left is null || right is null) return false;
        return left.Equals(right);
    }

    public static bool operator !=(Subject? left, Subject? right)
    {
        return !(left == right);
    }

    public override string ToString() => Value;
}
