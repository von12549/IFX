using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.InvestmentAccounts.DTOs;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.UpdateInvestmentAccount;

public record UpdateInvestmentAccountCommand(
    Guid Id,
    string AccountNumber,
    InvestmentAccountType AccountType,
    DateOnly? CertificateDate) : ICommand<Result<InvestmentAccountDto>, CrmTransactionOwner>;
