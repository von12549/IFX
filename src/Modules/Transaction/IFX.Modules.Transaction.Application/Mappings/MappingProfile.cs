using AutoMapper;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Domain.Entities;
using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;

namespace IFX.Modules.Transaction.Application.Mappings;

public class MappingProfile : Profile
{
    public MappingProfile()
    {
        CreateMap<TxEntity, TransactionDto>()
            .ForCtorParam(nameof(TransactionDto.TransactionId), o => o.MapFrom(s => s.Id))
            .ForCtorParam(nameof(TransactionDto.Type), o => o.MapFrom(s => s.Type.ToString()))
            .ForCtorParam(nameof(TransactionDto.TradeDate), o => o.MapFrom(s => s.TradeDate.ToString("yyyy-MM-dd")))
            .ForCtorParam(nameof(TransactionDto.SettlementDate), o => o.MapFrom(s => s.SettlementDate.HasValue ? s.SettlementDate.Value.ToString("yyyy-MM-dd") : null))
            .ForCtorParam(nameof(TransactionDto.Status), o => o.MapFrom(s => s.Status.ToString()));

        CreateMap<TxEntity, OrderLegDto>()
            .ForCtorParam(nameof(OrderLegDto.TransactionId), o => o.MapFrom(s => s.Id))
            .ForCtorParam(nameof(OrderLegDto.LegId), o => o.MapFrom(s => s.LegId ?? string.Empty))
            .ForCtorParam(nameof(OrderLegDto.TransactionType), o => o.MapFrom(s => s.Type.ToString()))
            .ForCtorParam(nameof(OrderLegDto.PriceType), o => o.MapFrom(s => s.DealingPriceDetails != null ? s.DealingPriceDetails.PriceType : null))
            .ForCtorParam(nameof(OrderLegDto.TradeDate), o => o.MapFrom(s => s.TradeDate.ToString("yyyy-MM-dd")))
            .ForCtorParam(nameof(OrderLegDto.SettlementDate), o => o.MapFrom(s => s.SettlementDate.HasValue ? s.SettlementDate.Value.ToString("yyyy-MM-dd") : null))
            .ForCtorParam(nameof(OrderLegDto.Status), o => o.MapFrom(s => s.Status.ToString()));

        CreateMap<Order, OrderDto>()
            .ForCtorParam(nameof(OrderDto.OrderId), o => o.MapFrom(s => s.Id))
            .ForCtorParam(nameof(OrderDto.OrderType), o => o.MapFrom(s => s.OrderType.ToString()))
            .ForCtorParam(nameof(OrderDto.Status), o => o.MapFrom(s => s.Status.ToString()))
            .ForCtorParam(nameof(OrderDto.ExpectedTradeDate), o => o.MapFrom(s => s.ExpectedTradeDate.HasValue ? s.ExpectedTradeDate.Value.ToString("yyyy-MM-dd") : null))
            .ForCtorParam(nameof(OrderDto.ExpectedSettlementDate), o => o.MapFrom(s => s.ExpectedSettlementDate.HasValue ? s.ExpectedSettlementDate.Value.ToString("yyyy-MM-dd") : null))
            .ForCtorParam(nameof(OrderDto.Legs), o => o.MapFrom(s => s.Legs));

        CreateMap<Order, OrderSummaryDto>()
            .ForCtorParam(nameof(OrderSummaryDto.OrderId), o => o.MapFrom(s => s.Id))
            .ForCtorParam(nameof(OrderSummaryDto.OrderType), o => o.MapFrom(s => s.OrderType.ToString()))
            .ForCtorParam(nameof(OrderSummaryDto.Status), o => o.MapFrom(s => s.Status.ToString()))
            .ForCtorParam(nameof(OrderSummaryDto.LegCount), o => o.MapFrom(s => s.Legs.Count));
    }
}
