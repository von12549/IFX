using System.Text.RegularExpressions;

namespace AuthSamples.Modules.Auth.Domain.ValueObjects;

public class EmailAddress : IEquatable<EmailAddress>
{
    private static readonly Regex EmailRegex = new(
        @"^[^@\s]+@[^@\s]+\.[^@\s]+$",
        RegexOptions.Compiled | RegexOptions.IgnoreCase);

    public string Value { get; private set; }

    private EmailAddress(string value)
    {
        Value = value;
    }

    public static EmailAddress Create(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            throw new ArgumentException("Email address cannot be empty", nameof(value));

        if (!EmailRegex.IsMatch(value))
            throw new ArgumentException("Invalid email address format", nameof(value));

        return new EmailAddress(value.ToLowerInvariant());
    }

    public bool Equals(EmailAddress? other)
    {
        if (other is null) return false;
        return Value == other.Value;
    }

    public override bool Equals(object? obj)
    {
        return obj is EmailAddress other && Equals(other);
    }

    public override int GetHashCode()
    {
        return Value.GetHashCode();
    }

    public static bool operator ==(EmailAddress? left, EmailAddress? right)
    {
        if (left is null && right is null) return true;
        if (left is null || right is null) return false;
        return left.Equals(right);
    }

    public static bool operator !=(EmailAddress? left, EmailAddress? right)
    {
        return !(left == right);
    }

    public override string ToString() => Value;
}
