using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.InvestmentAccounts.DTOs;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.CreateInvestmentAccount;

public record CreateInvestmentAccountCommand(
    string AccountNumber,
    InvestmentAccountType AccountType,
    DateOnly? CertificateDate) : ICommand<Result<InvestmentAccountDto>, CrmTransactionOwner>;
