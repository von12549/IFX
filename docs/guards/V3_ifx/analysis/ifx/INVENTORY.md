# Target inventory

Evidence is recorded in [inventory.json](inventory.json). Project references are literal XML declarations; MSBuild conditions, imports, generated files and transitive graphs are not evaluated. Source/test/fixture roles are path-name hints for review.

## .NET projects (171)

| Path | Role hint | Declared framework | Direct references | SHA-256 |
| --- | --- | --- | ---: | --- |
| `mcp/LayerGuard/src/LayerGuard/LayerGuard.csproj` | source | net10.0 | 0 | `a94781860e22ef83ef64a2d66d4a7c33d909b3fa2d9c4568741f3211bdac8eb3` |
| `mcp/LayerGuard/tests/fixtures/AllowedDirections/Allowed.Application/Allowed.Application.csproj` | fixture | net10.0 | 1 | `41da542e4b043355759677716b06a98b270ec52c5f16db1c7155a62cd4514118` |
| `mcp/LayerGuard/tests/fixtures/AllowedDirections/Allowed.Domain/Allowed.Domain.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/AllowedDirections/Allowed.Infrastructure/Allowed.Infrastructure.csproj` | fixture | net10.0 | 2 | `9e8065b429b0abf4f58a06abd1b85a88e1b0ef7d0cb9a3e7b2ddc9a64b6b5e73` |
| `mcp/LayerGuard/tests/fixtures/AllowedDirections/Allowed.Presentation/Allowed.Presentation.csproj` | fixture | net10.0 | 2 | `9e8065b429b0abf4f58a06abd1b85a88e1b0ef7d0cb9a3e7b2ddc9a64b6b5e73` |
| `mcp/LayerGuard/tests/fixtures/AllowedReferences/Billing/Acme.Billing.Abstractions/Acme.Billing.Abstractions.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/AllowedReferences/Billing/Acme.Billing.Application/Acme.Billing.Application.csproj` | fixture | net10.0 | 2 | `626e1a7165c3ee4bf5114ce363f35fe10fdb39e1e167ec3fddca564d042d6dd5` |
| `mcp/LayerGuard/tests/fixtures/AllowedReferences/Billing/Acme.Billing.Domain/Acme.Billing.Domain.csproj` | fixture | net10.0 | 2 | `fc4ee5ec6dabcf607e9b4fa00aa27dcb98c03bcf02c4f6ce667793109e62a0d9` |
| `mcp/LayerGuard/tests/fixtures/AllowedReferences/Billing/Acme.Billing.Infrastructure/Acme.Billing.Infrastructure.csproj` | fixture | net10.0 | 1 | `db5b13326291ef9bdaca276e4e44e63579a56fb6fc12a4866fdee1584bed017f` |
| `mcp/LayerGuard/tests/fixtures/AllowedReferences/Order/Acme.Order.Domain/Acme.Order.Domain.csproj` | fixture | net10.0 | 1 | `14a1007ce8621a192f36f2220487f244ed16138ac794e417a819bf7049450596` |
| `mcp/LayerGuard/tests/fixtures/AllowedReferences/Order/Acme.Order.Infrastructure/Acme.Order.Infrastructure.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/AllowedReferences/Shared/Acme.Shared.Domain/Acme.Shared.Domain.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/AllowedReferences/Shared/Acme.Shared.Legacy/Acme.Shared.Legacy.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Acme.ApiHost/Acme.ApiHost.csproj` | fixture |  | 2 | `fe9c47da33c454a19981de2291302bb78ef2275b1d6b417064751cb1b3c3a793` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Application.Tests/Acme.Billing.Application.Tests.csproj` | fixture |  | 0 | `8d654c44b7bebb6b31a9f2f606927f45b5072193adc4eef8cce3f3cf3b278df3` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Application/Acme.Billing.Application.csproj` | fixture |  | 4 | `c8efd037f6396ba4c5675d1d1de69a24058189dd2be51803874cd14a8a45fa86` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Composition/Acme.Billing.Composition.csproj` | fixture |  | 3 | `6df3058c86005228ae0267ba0fddea5df6111f44705621c84553f461ca1ea304` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Contracts/Acme.Billing.Contracts.csproj` | fixture |  | 2 | `a4594a095a1c39d008e3031c2100cc331c9d64e564ce64da794d4bca85b95330` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Domain/Acme.Billing.Domain.csproj` | fixture |  | 1 | `25eefa71ed365b7981c4edec0dad640d96dc855085ab228aa11147db785bf2de` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Infrastructure/Acme.Billing.Infrastructure.csproj` | fixture |  | 3 | `8b4bacf3412f01c2fdd825f0dd6eebdaab444c6b1807d99c027a221209b65079` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Integration/Acme.Billing.Integration.csproj` | fixture |  | 2 | `8c070d8fee30d724e096d78961d47e114ae578423b1d83a9c50700e4b8139fde` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Presentation/Acme.Billing.Presentation.csproj` | fixture |  | 1 | `c0c7f5ef3ca2125b10b2b5fd66965f80641aef90b4664f75c67751974b2cd7b8` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/BillingPlus/Acme.BillingPlus.Contracts/Acme.BillingPlus.Contracts.csproj` | fixture |  | 0 | `8d654c44b7bebb6b31a9f2f606927f45b5072193adc4eef8cce3f3cf3b278df3` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Legacy/Acme.Legacy.Abstractions/Acme.Legacy.Abstractions.csproj` | fixture |  | 0 | `8d654c44b7bebb6b31a9f2f606927f45b5072193adc4eef8cce3f3cf3b278df3` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Sales/Acme.Sales.Contracts/Acme.Sales.Contracts.csproj` | fixture |  | 1 | `15017d5d3b08a743e63db2952e82a442c57f20c3885083eac8d0518bb8008869` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Sales/Acme.Sales.Domain/Acme.Sales.Domain.csproj` | fixture |  | 0 | `8d654c44b7bebb6b31a9f2f606927f45b5072193adc4eef8cce3f3cf3b278df3` |
| `mcp/LayerGuard/tests/fixtures/CustomRules/Shop.Api/Shop.Api.csproj` | fixture | net10.0 | 2 | `71f1c83bdfcee6235400c1927331dc6ea450a218f0ae7b5161a9522749d860fa` |
| `mcp/LayerGuard/tests/fixtures/CustomRules/Shop.Core/Shop.Core.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/CustomRules/Shop.Persistence/Shop.Persistence.csproj` | fixture | net10.0 | 1 | `2f9e9a685307f409b4ddfc72ff507da4b2a04d9e4da24f85f4189991e3773729` |
| `mcp/LayerGuard/tests/fixtures/CustomRules/Shop.UseCases/Shop.UseCases.csproj` | fixture | net10.0 | 1 | `2f9e9a685307f409b4ddfc72ff507da4b2a04d9e4da24f85f4189991e3773729` |
| `mcp/LayerGuard/tests/fixtures/DeclarationPlacement/Acme.Application/Acme.Application.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/DeclarationPlacement/Acme.Domain/Acme.Domain.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/DeclarationPlacement/Acme.Infrastructure/Acme.Infrastructure.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/DeclarationPlacement/Acme.Presentation/Acme.Presentation.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/DirectReference/Direct.Application/Direct.Application.csproj` | fixture | net10.0 | 2 | `54d74a5ddd2f392ba61e134bcad59b7d09541e881d883aa6b99fd0aad7f50710` |
| `mcp/LayerGuard/tests/fixtures/DirectReference/Direct.Domain/Direct.Domain.csproj` | fixture | net10.0 | 3 | `3115a9835718dc7a0a5a097d63ed6c19275b738b54af7764fd4cb10007c0af16` |
| `mcp/LayerGuard/tests/fixtures/DirectReference/Direct.Infrastructure/Direct.Infrastructure.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/DirectReference/Direct.Presentation/Direct.Presentation.csproj` | fixture | net10.0 | 1 | `20fb2a297b28cb6dd83707868f0401f22adcae999b915dcef81815c4b9d2d1c3` |
| `mcp/LayerGuard/tests/fixtures/DirectSiblingReference/Sibling.Infrastructure/Sibling.Infrastructure.csproj` | fixture | net10.0 | 1 | `57fd840921c1ff772956c9398be468045d50a08a7d88bd9fd7f877f78484b841` |
| `mcp/LayerGuard/tests/fixtures/DirectSiblingReference/Sibling.Presentation/Sibling.Presentation.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/DisableTransitive/NoFlow.Carrier/NoFlow.Carrier.csproj` | fixture | net10.0 | 1 | `dbde4a78ad7b3e23d4d816a2090d488945b9474622ba8eb30004deea5fe80706` |
| `mcp/LayerGuard/tests/fixtures/DisableTransitive/NoFlow.Domain/NoFlow.Domain.csproj` | fixture | net10.0 | 1 | `a20cca4ee53e2fafe2334b124152b7968674e7215cbc82d145a4b98c5e3d24dc` |
| `mcp/LayerGuard/tests/fixtures/DisableTransitive/NoFlow.Infrastructure/NoFlow.Infrastructure.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/DisableTransitive/NoFlow.Presentation/NoFlow.Presentation.csproj` | fixture | net10.0 | 1 | `b33891c66a0569675a97494caa89bfbe0029ca071f09e368314e66a143672cc5` |
| `mcp/LayerGuard/tests/fixtures/ForbiddenDependencies/Acme.Application/Acme.Application.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/ForbiddenDependencies/Acme.Infrastructure/Acme.Infrastructure.csproj` | fixture | net10.0 | 1 | `aeb661f15ad2e91a7e3deda10bc4031b8dd2c19a6c70a4ee827b1bb55bcf9e2a` |
| `mcp/LayerGuard/tests/fixtures/ForbiddenDependencies/Acme.Presentation/Acme.Presentation.csproj` | fixture | net10.0 | 1 | `aeb661f15ad2e91a7e3deda10bc4031b8dd2c19a6c70a4ee827b1bb55bcf9e2a` |
| `mcp/LayerGuard/tests/fixtures/ForbiddenPackages/Shop.Application/Shop.Application.csproj` | fixture | net10.0 | 1 | `a368758c047d397489facf4edce1d6788e862e5e486088aec4ec950622aebb6d` |
| `mcp/LayerGuard/tests/fixtures/ForbiddenPackages/Shop.Domain/Shop.Domain.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/ForbiddenPackages/Shop.Presentation/Shop.Presentation.csproj` | fixture | net10.0 | 1 | `1e85a1077f63759e0648edc622c5445330dc6330b34e88ba25336a8c2a80adc6` |
| `mcp/LayerGuard/tests/fixtures/Implements/Acme.Domain/Acme.Domain.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/Implements/Acme.Infrastructure/Acme.Infrastructure.csproj` | fixture | net10.0 | 1 | `7df61ac92fe2b3cb75b72d88f6ccc5230fa67b5e6481fa8498fe87509d32182a` |
| `mcp/LayerGuard/tests/fixtures/Imports/Acme.Application/Acme.Application.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/Imports/Acme.Domain/Acme.Domain.csproj` | fixture | net10.0 | 1 | `63a42b5c9da83bb1e14f9dc3f048000057524765ed5dbaf2225382fbd2d4eea9` |
| `mcp/LayerGuard/tests/fixtures/Imports/Acme.Shared/Acme.Shared.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/IndirectKeptPrivate/Private.AppCarrier/Private.AppCarrier.csproj` | fixture | net10.0 | 1 | `4e9171714937b16a90530eb8773814f2e0cb933170ef11e56849f37827531e2f` |
| `mcp/LayerGuard/tests/fixtures/IndirectKeptPrivate/Private.Application/Private.Application.csproj` | fixture | net10.0 | 2 | `f087e7d854ff9722cab7ca925dc92b3007bc29dc8260e7c76418a541c9a3b3a8` |
| `mcp/LayerGuard/tests/fixtures/IndirectKeptPrivate/Private.Domain/Private.Domain.csproj` | fixture | net10.0 | 3 | `6dfabd55991be20f6202357ada3da390f0306890208a3540d9ede50d0ca80b81` |
| `mcp/LayerGuard/tests/fixtures/IndirectKeptPrivate/Private.InfraCarrier/Private.InfraCarrier.csproj` | fixture | net10.0 | 1 | `914eab752cf48cb21f94a0fb059e98311a8716be08db9109a73db3152f0377e5` |
| `mcp/LayerGuard/tests/fixtures/IndirectKeptPrivate/Private.Infrastructure/Private.Infrastructure.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/IndirectKeptPrivate/Private.PresCarrier/Private.PresCarrier.csproj` | fixture | net10.0 | 1 | `06e716f265e2bb86116daac7191f920c8b2e95ff6b7832b550935cd1ab4cccac` |
| `mcp/LayerGuard/tests/fixtures/IndirectKeptPrivate/Private.Presentation/Private.Presentation.csproj` | fixture | net10.0 | 1 | `c8893a1872897e5229a15f9aaadcf869f5aae3edf4ba5408069be1092de9c719` |
| `mcp/LayerGuard/tests/fixtures/IndirectReference/Indirect.AppCarrier/Indirect.AppCarrier.csproj` | fixture | net10.0 | 1 | `b6207f58dc425d3170dcb31616939a6a9908108a11d66629cb70991e3a9646af` |
| `mcp/LayerGuard/tests/fixtures/IndirectReference/Indirect.Application/Indirect.Application.csproj` | fixture | net10.0 | 2 | `372c8b38f14727e1f25702a60f268cf47bed563a3b1d5548d05f73a415ae970d` |
| `mcp/LayerGuard/tests/fixtures/IndirectReference/Indirect.Domain/Indirect.Domain.csproj` | fixture | net10.0 | 3 | `ec3e3a14bd9c432419be9ccec75054be7afec7d9f50cd3c02ac0143602223909` |
| `mcp/LayerGuard/tests/fixtures/IndirectReference/Indirect.InfraCarrier/Indirect.InfraCarrier.csproj` | fixture | net10.0 | 1 | `89b8dc9a9f412d55f5953f985b7dee48f143f10268559e20305a0f7bb05a6234` |
| `mcp/LayerGuard/tests/fixtures/IndirectReference/Indirect.Infrastructure/Indirect.Infrastructure.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/IndirectReference/Indirect.PresCarrier/Indirect.PresCarrier.csproj` | fixture | net10.0 | 1 | `74fcebc7991681fc5be2395d5a6cfef746ed4f66d2eae6ce7a7d997d0b53509a` |
| `mcp/LayerGuard/tests/fixtures/IndirectReference/Indirect.Presentation/Indirect.Presentation.csproj` | fixture | net10.0 | 1 | `39bd5bd4fa3f15a5b02e001e613fc28393fb2fb79cd5150c6c8caf9817a0e5b0` |
| `mcp/LayerGuard/tests/fixtures/IndirectSharedHop/Hop.Application/Hop.Application.csproj` | fixture | net10.0 | 1 | `fb077bc75371ec65e45f2842e1b9302387221d2f00e433a646af3d7cf0fdf697` |
| `mcp/LayerGuard/tests/fixtures/IndirectSharedHop/Hop.Carrier/Hop.Carrier.csproj` | fixture | net10.0 | 1 | `830e492b6ca016298d8ac8e8907368c6da89a50817139bf3cef2fc6f0b90c26d` |
| `mcp/LayerGuard/tests/fixtures/IndirectSharedHop/Hop.Domain/Hop.Domain.csproj` | fixture | net10.0 | 1 | `3284e7b72057a38094f297263ae7048ef5a8b250b7662ad74280d08968b6cbed` |
| `mcp/LayerGuard/tests/fixtures/IndirectSharedHop/Hop.Infrastructure/Hop.Infrastructure.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/IndirectSiblingReference/IndSibling.Infrastructure/IndSibling.Infrastructure.csproj` | fixture | net10.0 | 1 | `64513f5ed842f761eb1bfe63093d76441ec5b463ed2bd64a80f023ba0b93fc05` |
| `mcp/LayerGuard/tests/fixtures/IndirectSiblingReference/IndSibling.PresCarrier/IndSibling.PresCarrier.csproj` | fixture | net10.0 | 1 | `88f9eaef53a0a58f5548a9d3b1693253c2625ebfef35d542b248411524a6162c` |
| `mcp/LayerGuard/tests/fixtures/IndirectSiblingReference/IndSibling.Presentation/IndSibling.Presentation.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/PrivateAssetsAttributeForm/Attr.Domain/Attr.Domain.csproj` | fixture | net10.0 | 1 | `779fc0d2b67de204862067d59869bd19d4c53fcb4e5a3f1906a13b532c6ccaf3` |
| `mcp/LayerGuard/tests/fixtures/PrivateAssetsAttributeForm/Attr.Infrastructure/Attr.Infrastructure.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/PrivateAssetsAttributeForm/Attr.OpenCarrier/Attr.OpenCarrier.csproj` | fixture | net10.0 | 1 | `af3c6443344823668aeb954eb81fd33e7a826248f8fdd9fc4b752e792fed3153` |
| `mcp/LayerGuard/tests/fixtures/PrivateAssetsAttributeForm/Attr.Presentation/Attr.Presentation.csproj` | fixture | net10.0 | 1 | `62e833607e372a387586e4a160f2f469ec1fff27ec206c83a64122b5b389a79b` |
| `mcp/LayerGuard/tests/fixtures/PrivateAssetsAttributeForm/Attr.SealedCarrier/Attr.SealedCarrier.csproj` | fixture | net10.0 | 1 | `64be40aef09fb8b56b922ec2069ba98d977f165c672f567f0e806875b1c916e2` |
| `mcp/LayerGuard/tests/fixtures/Rulebook/Billing/Acme.Billing.Application/Acme.Billing.Application.csproj` | fixture | net10.0 | 1 | `db5b13326291ef9bdaca276e4e44e63579a56fb6fc12a4866fdee1584bed017f` |
| `mcp/LayerGuard/tests/fixtures/Rulebook/Billing/Acme.Billing.Domain/Acme.Billing.Domain.csproj` | fixture | net10.0 | 2 | `e3536337b251e8dbb5e9ab19bec2ed6d3885e4d2fbd56912b24d5c8461670634` |
| `mcp/LayerGuard/tests/fixtures/Rulebook/Billing/Acme.Billing.Helper/Acme.Billing.Helper.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/Rulebook/Billing/Acme.Billing.Presentation/Acme.Billing.Presentation.csproj` | fixture | net10.0 | 0 | `e3056dc946a6f467c34e9ebc37789baa1f3306ce800d4e565324a78fb9581180` |
| `mcp/LayerGuard/tests/fixtures/Rulebook/Shared/Acme.Shared.Legacy/Acme.Shared.Legacy.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/SolutionScope/Sln.Domain/Sln.Domain.csproj` | fixture | net10.0 | 1 | `d1d430b38baa5f515509dee77691e1edfe637dc7edecd1c534479e06fb54f6ef` |
| `mcp/LayerGuard/tests/fixtures/SolutionScope/Sln.Infrastructure/Sln.Infrastructure.csproj` | fixture | net10.0 | 0 | `dbc560432e1064a38589480fae4687553c22ed6a9ba02296fb9dd80c157a2bbe` |
| `mcp/LayerGuard/tests/fixtures/SolutionScope/Sln.Presentation/Sln.Presentation.csproj` | fixture | net10.0 | 1 | `d1d430b38baa5f515509dee77691e1edfe637dc7edecd1c534479e06fb54f6ef` |
| `mcp/LayerGuard/tests/LayerGuard.Tests/LayerGuard.Tests.csproj` | test | net10.0 | 1 | `c5e43defa9df2290a061de889148a240fbddf4a300cbd562c6ef3e455c43b515` |
| `src/ApiHost/IFX.ApiHost/IFX.ApiHost.csproj` | source | net8.0 | 13 | `856503c6163622ac84b64cf665fbea99ab1d6b0581ba09b1a1616fc3592d3e3e` |
| `src/BuildingBlocks/IFX.BuildingBlocks.Application/IFX.BuildingBlocks.Application.csproj` | source | net8.0 | 1 | `8d9dc0833fe975b1e668bfe90b1823e935b023b34635704cc4344dabf99bb8d1` |
| `src/BuildingBlocks/IFX.BuildingBlocks.Composition/IFX.BuildingBlocks.Composition.csproj` | source | net8.0 | 0 | `c756bd29f4a6fb3e24cd75307f6b627bac32cb013cbb9ded457d4c84ddf4e385` |
| `src/BuildingBlocks/IFX.BuildingBlocks.Domain/IFX.BuildingBlocks.Domain.csproj` | source | net8.0 | 0 | `2da823240e0026033d25d1c29a009e59f7e1cfd0d97c6da26aa4ecae53fc49e3` |
| `src/BuildingBlocks/IFX.BuildingBlocks.EntityFrameworkCore/IFX.BuildingBlocks.EntityFrameworkCore.csproj` | source | net8.0 | 1 | `e9e5b5b84a9d29b9f0f5fec626eb1f7be8909034044d76f007f0d018fd63458c` |
| `src/BuildingBlocks/IFX.BuildingBlocks.Security/IFX.BuildingBlocks.Security.csproj` | source | net8.0 | 0 | `5efb131f6aeeee44df75953c1a58be3a10151c93cabf219b10465a5ed24b949e` |
| `src/DatabaseMigrator/IFX.DatabaseMigrator/IFX.DatabaseMigrator.csproj` | source | net8.0 | 6 | `9b96a84c5024e537c77a1d6c6a28afc0bc406e7e59edbfa71a9fa4bdf2b216f3` |
| `src/Modules/CRM/IFX.Modules.CRM.Application/IFX.Modules.CRM.Application.csproj` | source | net8.0 | 4 | `90929191de7e8b047c8fed77f58718614293a62fd62af0de20b396477fc939e4` |
| `src/Modules/CRM/IFX.Modules.CRM.Composition/IFX.Modules.CRM.Composition.csproj` | source | net8.0 | 5 | `7e2c696427dfda79a4b0d35152ddbbebe334681577ce08a192bbc7089700b830` |
| `src/Modules/CRM/IFX.Modules.CRM.Contracts/IFX.Modules.CRM.Contracts.csproj` | source | net8.0 | 1 | `a47b66d3c248abf2b8f5da09898adf506d22113988a6e5368c1f91d49afff8f9` |
| `src/Modules/CRM/IFX.Modules.CRM.Domain/IFX.Modules.CRM.Domain.csproj` | source | net8.0 | 1 | `5f70dea2db97d47cd72ea7f79ce1840e5b35d8e0e3914d262f0e4ddbc64a7710` |
| `src/Modules/CRM/IFX.Modules.CRM.Infrastructure/IFX.Modules.CRM.Infrastructure.csproj` | source | net8.0 | 6 | `4fb413b361e5eb42d13a55e564c0399dc86e8efaaab98ba60eaeb404decb2d87` |
| `src/Modules/CRM/IFX.Modules.CRM.Presentation/IFX.Modules.CRM.Presentation.csproj` | source | net8.0 | 1 | `d337d79afdc2f64b514012307c0bc778a78f00b1ede2f9312613fc5a3d23362b` |
| `src/Modules/Holdings/IFX.Modules.Holdings.Application/IFX.Modules.Holdings.Application.csproj` | source | net8.0 | 3 | `d33f3353fa56c4c87c7bbaf8b50d63d3b8513e8c3c4fdcc37394205464275272` |
| `src/Modules/Holdings/IFX.Modules.Holdings.Composition/IFX.Modules.Holdings.Composition.csproj` | source | net8.0 | 4 | `93d6c120fa186b45cfd91bf8aeb0c2abe3979f8829cf7a25b254092bc621941f` |
| `src/Modules/Holdings/IFX.Modules.Holdings.Domain/IFX.Modules.Holdings.Domain.csproj` | source | net8.0 | 1 | `32954a9978b60974697f2d78c40cf50026285f2557f3d082957e639b0363107e` |
| `src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/IFX.Modules.Holdings.Infrastructure.csproj` | source | net8.0 | 9 | `0a962563e219b2af70dfe13a00b5f6a747a7d1516c0db50241b82c981de12c3e` |
| `src/Modules/Holdings/IFX.Modules.Holdings.Presentation/IFX.Modules.Holdings.Presentation.csproj` | source | net8.0 | 1 | `df488c0c6f2c141f947f27d90c0db7d7a362ca3df80aabc14870bf39a4f282b0` |
| `src/Modules/IAM/IFX.Modules.IAM.Application/IFX.Modules.IAM.Application.csproj` | source | net8.0 | 5 | `c9f61e8aeab254b19507ee8a452d70445c9c75d305ea6f5a76f0b6da25b455bd` |
| `src/Modules/IAM/IFX.Modules.IAM.Client/IFX.Modules.IAM.Client.csproj` | source | net8.0 | 3 | `d634a42c5034901bee243f830b58549601918ee86a32224b003ef9e4259cba3e` |
| `src/Modules/IAM/IFX.Modules.IAM.Composition/IFX.Modules.IAM.Composition.csproj` | source | net8.0 | 9 | `e64656bade8c0322b7b24d34bba23f22a27ba2007a5e20573b582bfdfb473326` |
| `src/Modules/IAM/IFX.Modules.IAM.Contracts/IFX.Modules.IAM.Contracts.csproj` | source | net8.0 | 1 | `8827183a4ed3e9054126a1036f4a11d9008fa4411f082b397d8ff12fe832fafe` |
| `src/Modules/IAM/IFX.Modules.IAM.Domain/IFX.Modules.IAM.Domain.csproj` | source | net8.0 | 1 | `09eddb4bf0e7e9749d78c922985d896d114f5168eb2439b85a3b3509c3d0157a` |
| `src/Modules/IAM/IFX.Modules.IAM.Infrastructure/IFX.Modules.IAM.Infrastructure.csproj` | source | net8.0 | 9 | `442d2e50a9d0cdd7507b3f69e3244af38e3881ab764d903a805aa1082b005cb0` |
| `src/Modules/IAM/IFX.Modules.IAM.Presentation/IFX.Modules.IAM.Presentation.csproj` | source | net8.0 | 1 | `39268f4a71db832d142bc18738179e4badf8725a2244a2b249b2eb243f504377` |
| `src/Modules/Registry/IFX.Modules.Registry.Application/IFX.Modules.Registry.Application.csproj` | source | net8.0 | 4 | `8774e0561429877a0b7daddff8b2cfdd29130e12b44de3aa1e695f9fdc17c438` |
| `src/Modules/Registry/IFX.Modules.Registry.Composition/IFX.Modules.Registry.Composition.csproj` | source | net8.0 | 5 | `7f0a80b2caf6bde313167d869813721f154a476d58e66cb282c41e9fee7e2e5a` |
| `src/Modules/Registry/IFX.Modules.Registry.Contracts/IFX.Modules.Registry.Contracts.csproj` | source | net8.0 | 2 | `b0cc8c62eca0a9a3390ab14953b5a984acc87c32074e5968ebad90ae80aca72f` |
| `src/Modules/Registry/IFX.Modules.Registry.Domain/IFX.Modules.Registry.Domain.csproj` | source | net8.0 | 1 | `5f70dea2db97d47cd72ea7f79ce1840e5b35d8e0e3914d262f0e4ddbc64a7710` |
| `src/Modules/Registry/IFX.Modules.Registry.Infrastructure/IFX.Modules.Registry.Infrastructure.csproj` | source | net8.0 | 7 | `8ce92f404723fd741554deb34758f2adb7c9e964c3c3e71e2f4350c75a385c3d` |
| `src/Modules/Registry/IFX.Modules.Registry.Presentation/IFX.Modules.Registry.Presentation.csproj` | source | net8.0 | 1 | `fa06e38844b8c5e1a3d3a99e9a2ead82bca51a07eb16bf852478f2ea0d699e2d` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Application/IFX.Modules.Transaction.Application.csproj` | source | net8.0 | 3 | `a8c33259a3b2437185b06ee1afb86b8b6ff6e573a93f6d9d913e522c1e0b30a3` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Composition/IFX.Modules.Transaction.Composition.csproj` | source | net8.0 | 6 | `c83220bc9fd8b7307b74928caae2dc9c77a028c021bf1bc5a8a49290bcd712c8` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Contracts/IFX.Modules.Transaction.Contracts.csproj` | source | net8.0 | 1 | `ef1171c9c7f4dd3aa69ae22d1df756fa90afcd40e2fc36e5292842d5d7959e4e` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Domain/IFX.Modules.Transaction.Domain.csproj` | source | net8.0 | 1 | `32954a9978b60974697f2d78c40cf50026285f2557f3d082957e639b0363107e` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Infrastructure/IFX.Modules.Transaction.Infrastructure.csproj` | source | net8.0 | 11 | `1f65692794ea709f4ec5651ef77b0cd567be2d0c50366514eb9e1320da66f40c` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Presentation/IFX.Modules.Transaction.Presentation.csproj` | source | net8.0 | 1 | `01d8577125721a1d17ac3fc5dbc8709cc3cfb3bd0d24fc9de0eaac60ddd7dd55` |
| `src/Platform/Authentication/IFX.Platform.Authentication.Composition/IFX.Platform.Authentication.Composition.csproj` | source | net8.0 | 3 | `9ad44b2a248b18af444b25440778bca6dd3270f97804ca02d4f9c4cf4a2212c6` |
| `src/Platform/Authentication/IFX.Platform.Authentication.Contracts/IFX.Platform.Authentication.Contracts.csproj` | source | net8.0 | 0 | `b74e2ed65b0ed73188135dd3ff266ab11d29d0d4b990a473f6e467ec097aa497` |
| `src/Platform/Authentication/IFX.Platform.Authentication.Infrastructure.Auth0/IFX.Platform.Authentication.Infrastructure.Auth0.csproj` | source | net8.0 | 1 | `913b7e04cb00a7998b0db4c31c79e58d6bf9375b70074cea42a563d037f50d57` |
| `src/Platform/Authentication/IFX.Platform.Authentication.Infrastructure.Cognito/IFX.Platform.Authentication.Infrastructure.Cognito.csproj` | source | net8.0 | 1 | `484aaf361c1669118e73d29bbc9ebeeec241873709872985300624a7704a4635` |
| `src/Platform/Authentication/IFX.Platform.Authentication.Runtime/IFX.Platform.Authentication.Runtime.csproj` | source | net8.0 | 1 | `5bbec633fda57d62e127b3a208d0e72d499f6ba28664bde4a5d9b37d25a75e35` |
| `src/Platform/Authorization/IFX.Platform.Authorization.Composition/IFX.Platform.Authorization.Composition.csproj` | source | net8.0 | 3 | `9adebb778b75e1d1c4ff52cc97951aaa2ab91e70c1db7e504d649240d1897348` |
| `src/Platform/Authorization/IFX.Platform.Authorization.Contracts/IFX.Platform.Authorization.Contracts.csproj` | source | net8.0 | 0 | `dd1aec33430afa1b6db95a49f061df13d29def748d9952f266d42cd9a6d43d41` |
| `src/Platform/Authorization/IFX.Platform.Authorization.Infrastructure.Opa/IFX.Platform.Authorization.Infrastructure.Opa.csproj` | source | net8.0 | 2 | `c43365f8b865ab3826d9557474505f9f39de90137d11dc7d9baeefe0d744117a` |
| `src/Platform/Authorization/IFX.Platform.Authorization.Runtime/IFX.Platform.Authorization.Runtime.csproj` | source | net8.0 | 1 | `6bf93e25c5335e631ea6d2bbfbddb77853a47e973fb78c26341e21342b434dc4` |
| `src/Platform/BackgroundJobs/IFX.Platform.BackgroundJobs.Composition/IFX.Platform.BackgroundJobs.Composition.csproj` | source | net8.0 | 3 | `18723f9972f20027751b50a5407256183dc391a4f4c94ab76357bf6c5b3a2f06` |
| `src/Platform/BackgroundJobs/IFX.Platform.BackgroundJobs.Contracts/IFX.Platform.BackgroundJobs.Contracts.csproj` | source | net8.0 | 0 | `12985a174dc55d6f519f2205bf7b35d0123d6d7dfa7fe3fe34f2f3028ba30604` |
| `src/Platform/BackgroundJobs/IFX.Platform.BackgroundJobs.Infrastructure.Hangfire/IFX.Platform.BackgroundJobs.Infrastructure.Hangfire.csproj` | source | net8.0 | 1 | `99b0e5f642a3cf53d2d60e0242f4d799b3ee531da502727e3941c814d79c2b6e` |
| `src/Platform/Context/IFX.Platform.Context.Contracts/IFX.Platform.Context.Contracts.csproj` | source | net8.0 | 0 | `12985a174dc55d6f519f2205bf7b35d0123d6d7dfa7fe3fe34f2f3028ba30604` |
| `src/Platform/Context/IFX.Platform.Context.Runtime/IFX.Platform.Context.Runtime.csproj` | source | net8.0 | 2 | `7fea411e6566abf24466d662c926b13ff0e73a6cf20ccd410b6c3a7fa865c492` |
| `src/Platform/IFX.Platform.Shared/IFX.Platform.Shared.csproj` | source | net8.0 | 0 | `b540adba501c839ec1d75143e106dfb9dd5593d9ff7cdd036af82c25c9387053` |
| `src/Platform/Messaging/IFX.Platform.Messaging.Composition/IFX.Platform.Messaging.Composition.csproj` | source | net8.0 | 1 | `338480dc4902d7d9db564500b9a78026c963eb0d7b863afa81e73e96891e72d2` |
| `src/Platform/Messaging/IFX.Platform.Messaging.Contracts/IFX.Platform.Messaging.Contracts.csproj` | source | net8.0 | 0 | `12985a174dc55d6f519f2205bf7b35d0123d6d7dfa7fe3fe34f2f3028ba30604` |
| `src/Platform/Messaging/IFX.Platform.Messaging.Runtime/IFX.Platform.Messaging.Runtime.csproj` | source | net8.0 | 3 | `6da94a9675f74d9cb88602540c6dfb7b9b8bdc5583c16712e02e3783bdfffa88` |
| `src/Platform/Notifications/IFX.Platform.Notifications.Composition/IFX.Platform.Notifications.Composition.csproj` | source | net8.0 | 2 | `7d95a0411b8641afe69b127ed1ed7b39aa48c6957f259d5f72671883f95322f7` |
| `src/Platform/Notifications/IFX.Platform.Notifications.Contracts/IFX.Platform.Notifications.Contracts.csproj` | source | net8.0 | 0 | `12985a174dc55d6f519f2205bf7b35d0123d6d7dfa7fe3fe34f2f3028ba30604` |
| `src/Platform/Notifications/IFX.Platform.Notifications.Infrastructure.SendGrid/IFX.Platform.Notifications.Infrastructure.SendGrid.csproj` | source | net8.0 | 2 | `cc04bdd4e595118fbd027aa426d0a68e509e7cf61ac65be5438903ca081e28af` |
| `tests/IFX.BuildingBlocks.Application.Tests/IFX.BuildingBlocks.Application.Tests.csproj` | test | net8.0 | 1 | `7e3435410e411dd174e71b4c62d38ce599b0415cd0a1cce523d4796d99213cde` |
| `tests/IFX.BuildingBlocks.EntityFrameworkCore.Tests/IFX.BuildingBlocks.EntityFrameworkCore.Tests.csproj` | test | net8.0 | 1 | `e9f5f1f38a97c2b089c0347839737528a3ffd4189d1e325ae31d79733c67f824` |
| `tests/IFX.DatabaseBoundary.Tests/IFX.DatabaseBoundary.Tests.csproj` | test | net8.0 | 8 | `c4eb04584db82ea3e7db9929f8781d3068345ed38d462473146692316d234f91` |
| `tests/IFX.IntegrationTests/IFX.IntegrationTests.csproj` | test | net8.0 | 8 | `b090daf59320c3defe9252fe5f59af148a3eab666a4615a025cf78e1436e3840` |
| `tests/IFX.Modules.CRM.Application.Tests/IFX.Modules.CRM.Application.Tests.csproj` | test | net8.0 | 3 | `4b03fe886bf8108873f89b3cc56e9adfc61765597dcb19bbad0d1819ba532304` |
| `tests/IFX.Modules.CRM.Domain.Tests/IFX.Modules.CRM.Domain.Tests.csproj` | test | net8.0 | 1 | `bc72a9fbececcc3eaa15ab7b9fde0a635cd719370fd5a411f0cd3efe0603b941` |
| `tests/IFX.Modules.Holdings.Application.Tests/IFX.Modules.Holdings.Application.Tests.csproj` | test | net8.0 | 1 | `5a3367cab02d7ad182c2c3057a3233a08068c33859179913ef9ad63226b467ad` |
| `tests/IFX.Modules.Holdings.Domain.Tests/IFX.Modules.Holdings.Domain.Tests.csproj` | test | net8.0 | 1 | `ade96404a140b15cb93ccb92521945f3ca7d3104ab17d03ecbf7b32df46f28a3` |
| `tests/IFX.Modules.IAM.Application.Tests/IFX.Modules.IAM.Application.Tests.csproj` | test | net8.0 | 2 | `17ba3f82e06c2ceb7517486cfb40c160c916a02b6f954bd718c4e6252aaa4545` |
| `tests/IFX.Modules.IAM.Domain.Tests/IFX.Modules.IAM.Domain.Tests.csproj` | test | net8.0 | 2 | `eeb1b9185e53dc3562c76b3e666453c8906e62b8bb1f8ef73dc625c6c812aeea` |
| `tests/IFX.Modules.IAM.Infrastructure.Tests/IFX.Modules.IAM.Infrastructure.Tests.csproj` | test | net8.0 | 3 | `d4fb8a83a6e9fa75528a5e4605f38910c9635688dc49c0061f1f69f716120291` |
| `tests/IFX.Modules.IAM.Presentation.Tests/IFX.Modules.IAM.Presentation.Tests.csproj` | test | net8.0 | 2 | `a3f289b5f6c83a6b38431c5e228bad1f8b1a209e0570a4b6c2b9f4a45081114c` |
| `tests/IFX.Modules.Registry.Application.Tests/IFX.Modules.Registry.Application.Tests.csproj` | test | net8.0 | 3 | `f16893d31ee8e57e0939ed1248f7615f64626320af40a7cd88327d5a83f2568e` |
| `tests/IFX.Modules.Registry.Domain.Tests/IFX.Modules.Registry.Domain.Tests.csproj` | test | net8.0 | 1 | `831d01dfb8cadf006e95f998c3abd19aac41636105ff699a5ea09f845b6f2c02` |
| `tests/IFX.Modules.Transaction.Application.Tests/IFX.Modules.Transaction.Application.Tests.csproj` | test | net8.0 | 1 | `de0dc69523662e6e998f0270a857277eb9abb2305c202068ccc2d039b3c51873` |
| `tests/IFX.Modules.Transaction.Domain.Tests/IFX.Modules.Transaction.Domain.Tests.csproj` | test | net8.0 | 1 | `7f41f310bccd43e11673d9c4fc5fb1652aba035a6a302df61ce680044f5138f0` |
| `tests/IFX.Platform.Authentication.Tests/IFX.Platform.Authentication.Tests.csproj` | test | net8.0 | 2 | `b72b40138c4860db7c9947916a4658710fff8f379bd90b525168f6c4bc319be7` |
| `tests/IFX.Platform.Authorization.Tests/IFX.Platform.Authorization.Tests.csproj` | test | net8.0 | 2 | `e22273de60bfacb242ab43ba108ef85d16212f3acfb40fa2db1565c4f61793d4` |
| `tests/IFX.Platform.BackgroundJobs.Tests/IFX.Platform.BackgroundJobs.Tests.csproj` | test | net8.0 | 2 | `7f82d93c5151e88e20f8f700b7a9776da9366e9d499f3245d57cf6df5968493f` |
| `tests/IFX.Platform.Notifications.Tests/IFX.Platform.Notifications.Tests.csproj` | test | net8.0 | 3 | `23536817bcdbf4eb8ee0ad328e2c1f6e8918c8cb1f126bb1becea93fb1263a20` |
| `tests/IFX.Platform.ProtocolContracts.Tests/IFX.Platform.ProtocolContracts.Tests.csproj` | test | net8.0 | 6 | `dd076680fd4b935ff72943b2b0141aa5c4a6139bc850d4177e46864e5a0f04d2` |
| `tests/IFX.Tests.Common/IFX.Tests.Common.csproj` | test | net8.0 | 2 | `38741d4432d19edf325f662c416b977a1e504d4c7d3b97a1a5c9c31fb53918e6` |
| `tools/IFX.DatabaseInventory/IFX.DatabaseInventory.csproj` | source | net8.0 | 5 | `6fabff7dcb18e78d7f939430e3ddf10f6fe56a2896557e69c9de7a2ca7381ab8` |

## Manifests

- `Directory.Build.props` (Directory.Build.props, SHA-256 `1e5d8d41ae2726ae27326d9070353698655ddabe4aa31df81fbaa93dff80549c`)
- `IFX.sln` (IFX.sln, SHA-256 `a855255f5373c03301ae40a8aae1ad82382aa5038e930de025aa95371c7a4b17`)
- `mcp/LayerGuard/LayerGuard.slnx` (LayerGuard.slnx, SHA-256 `9a5f0a7215b7525eb76a76e9cc4338bfcd24add8307a943fd4fae7e5707b69ae`)
- `mcp/LayerGuard/tests/fixtures/SolutionScope/SolutionScope.sln` (SolutionScope.sln, SHA-256 `4bd18d14fa5d30e62535914c7ac313cafd99fe870bfe384a2e1afa1171e751c6`)
- `src/ApiHost/IFX.ApiHost/IFX.ApiHost.sln` (IFX.ApiHost.sln, SHA-256 `6382b0a84aeccf799abe4a1df2543b76fe020f16ee14294a7696c4cdd04d28b5`)
- `src/Frontend/IFX.FrontEnd/package.json` (package.json, SHA-256 `8c4e911c067e0e7fbd01a3926696dcb23d5d718ce3cc20c6641b89e09f737932`)

## CI workflows

- `.github/workflows/v3-ifx-guardrails.yml` (SHA-256 `b79f831af256f2131ca01eb261ebb9be0c18596463fb895246a11eaeb37ceffb`)

## Agent/owner guidance

- `.github/CODEOWNERS` (SHA-256 `0d2d27a49e49077db1a2946954118bce8b73cbb33b78c6fc13df6cbfc5d3adea`)
- `CLAUDE.md` (SHA-256 `b889dfd02dacc7ba0b7e642cdedc17f24f09ed6d8ed690e3a71027d2b013914c`)
