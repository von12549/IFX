using Dapper;
using MediatR;

namespace Shop.Presentation;

public static class OrderEndpoints
{
    public static string Describe() => nameof(OrderEndpoints);
}
