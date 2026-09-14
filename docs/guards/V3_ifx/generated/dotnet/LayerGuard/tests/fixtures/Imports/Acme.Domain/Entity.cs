using System.Text;
using Acme.Application;
using Microsoft.EntityFrameworkCore;
using Acme.Shared;

#if DEBUG
using Dapper;
#endif

namespace Acme.Domain;

public sealed class Order
{
    public string Describe() => nameof(Order);
}
