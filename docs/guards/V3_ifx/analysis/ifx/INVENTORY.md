# Target inventory

Evidence is recorded in [inventory.json](inventory.json). Project references are literal XML declarations; MSBuild conditions, imports, generated files and transitive graphs are not evaluated. Source/test/fixture roles are path-name hints for review.

## .NET projects (171)

| Path | Role hint | Declared framework | Direct references | SHA-256 |
| --- | --- | --- | ---: | --- |
| `mcp/LayerGuard/src/LayerGuard/LayerGuard.csproj` | source | net10.0 | 0 | `4d6d69d7c879f04bb95441137251318e12454e145527a182d68029e892add8a1` |
| `mcp/LayerGuard/tests/fixtures/AllowedDirections/Allowed.Application/Allowed.Application.csproj` | fixture | net10.0 | 1 | `0ceaff53753c6917b4b141e4adec38d8b49e8a15653b3067b499d01b2a31c425` |
| `mcp/LayerGuard/tests/fixtures/AllowedDirections/Allowed.Domain/Allowed.Domain.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/AllowedDirections/Allowed.Infrastructure/Allowed.Infrastructure.csproj` | fixture | net10.0 | 2 | `7a01141d42c8596045bcd768dddcb0ae5d4ef1c0d151c0c0368093ae29e88ff4` |
| `mcp/LayerGuard/tests/fixtures/AllowedDirections/Allowed.Presentation/Allowed.Presentation.csproj` | fixture | net10.0 | 2 | `7a01141d42c8596045bcd768dddcb0ae5d4ef1c0d151c0c0368093ae29e88ff4` |
| `mcp/LayerGuard/tests/fixtures/AllowedReferences/Billing/Acme.Billing.Abstractions/Acme.Billing.Abstractions.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/AllowedReferences/Billing/Acme.Billing.Application/Acme.Billing.Application.csproj` | fixture | net10.0 | 2 | `9cf901245ef8781c3ca5b1529b5eeca0cb10578d228d5a09080f5c3e1da5a4f7` |
| `mcp/LayerGuard/tests/fixtures/AllowedReferences/Billing/Acme.Billing.Domain/Acme.Billing.Domain.csproj` | fixture | net10.0 | 2 | `71b202b198c23209fbac231e6818a589acb462cf168a0927781903b36ea01884` |
| `mcp/LayerGuard/tests/fixtures/AllowedReferences/Billing/Acme.Billing.Infrastructure/Acme.Billing.Infrastructure.csproj` | fixture | net10.0 | 1 | `b6959ce2ae349901e7a81a08ac6837f833f7a7734608075800b9c083bc517544` |
| `mcp/LayerGuard/tests/fixtures/AllowedReferences/Order/Acme.Order.Domain/Acme.Order.Domain.csproj` | fixture | net10.0 | 1 | `2e34214197f6e821e0b0bb4c8de5d507362f99c417d8986ae734523a0006923c` |
| `mcp/LayerGuard/tests/fixtures/AllowedReferences/Order/Acme.Order.Infrastructure/Acme.Order.Infrastructure.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/AllowedReferences/Shared/Acme.Shared.Domain/Acme.Shared.Domain.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/AllowedReferences/Shared/Acme.Shared.Legacy/Acme.Shared.Legacy.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Acme.ApiHost/Acme.ApiHost.csproj` | fixture |  | 2 | `4d2d9dc419bce839dee41f048063aa5b5840d638abd9b9c2236ca334aca9fa35` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Application.Tests/Acme.Billing.Application.Tests.csproj` | fixture |  | 0 | `e6fcb8e1e93a724d47a829cffd19d47840a5eb088e9ace43f3a34bbaf1524b07` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Application/Acme.Billing.Application.csproj` | fixture |  | 4 | `8e658ddae7690e6b5a82e3c93290c30704bce9f1cb874910e7aa1e36e555b26e` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Composition/Acme.Billing.Composition.csproj` | fixture |  | 3 | `404b1b21128a88ba381406e7fdb9d1f5d140609ca424df92bc4979e4b760a4cf` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Contracts/Acme.Billing.Contracts.csproj` | fixture |  | 2 | `4411db70bac92e8375cf15d72eb628bbab5d6922a62f08a548687a80d2d0d7cc` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Domain/Acme.Billing.Domain.csproj` | fixture |  | 1 | `bda979ee3effd55d847b8fcb0c4c428a10fd28378b48ced4a8ff89f0575b21be` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Infrastructure/Acme.Billing.Infrastructure.csproj` | fixture |  | 3 | `0fca494da180fe7790537195c3ecf87388f6264bac7de747dac030d426ed2a4a` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Integration/Acme.Billing.Integration.csproj` | fixture |  | 2 | `628de201baedaf0c45d4b4904f31cf3d57ce99fd855596275a3af536c34b0870` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Presentation/Acme.Billing.Presentation.csproj` | fixture |  | 1 | `38f30bfc2b9a29987ebb30e36256a79b95ff510dd140db2ed6f70cf2d13c8095` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/BillingPlus/Acme.BillingPlus.Contracts/Acme.BillingPlus.Contracts.csproj` | fixture |  | 0 | `e6fcb8e1e93a724d47a829cffd19d47840a5eb088e9ace43f3a34bbaf1524b07` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Legacy/Acme.Legacy.Abstractions/Acme.Legacy.Abstractions.csproj` | fixture |  | 0 | `e6fcb8e1e93a724d47a829cffd19d47840a5eb088e9ace43f3a34bbaf1524b07` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Sales/Acme.Sales.Contracts/Acme.Sales.Contracts.csproj` | fixture |  | 1 | `cbf6e9aeba4ceba1b97b7a876cbabad860e2394d889c66df5d558193bdc79d1a` |
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Sales/Acme.Sales.Domain/Acme.Sales.Domain.csproj` | fixture |  | 0 | `e6fcb8e1e93a724d47a829cffd19d47840a5eb088e9ace43f3a34bbaf1524b07` |
| `mcp/LayerGuard/tests/fixtures/CustomRules/Shop.Api/Shop.Api.csproj` | fixture | net10.0 | 2 | `e43d813b106f76100827ba5c4d04738ba815ac5324650ab347050ecaf5310e2d` |
| `mcp/LayerGuard/tests/fixtures/CustomRules/Shop.Core/Shop.Core.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/CustomRules/Shop.Persistence/Shop.Persistence.csproj` | fixture | net10.0 | 1 | `a4620332c2a64c5ab3c91958b9a021567ce74362eb69ca4c9711a5a892235d99` |
| `mcp/LayerGuard/tests/fixtures/CustomRules/Shop.UseCases/Shop.UseCases.csproj` | fixture | net10.0 | 1 | `a4620332c2a64c5ab3c91958b9a021567ce74362eb69ca4c9711a5a892235d99` |
| `mcp/LayerGuard/tests/fixtures/DeclarationPlacement/Acme.Application/Acme.Application.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/DeclarationPlacement/Acme.Domain/Acme.Domain.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/DeclarationPlacement/Acme.Infrastructure/Acme.Infrastructure.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/DeclarationPlacement/Acme.Presentation/Acme.Presentation.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/DirectReference/Direct.Application/Direct.Application.csproj` | fixture | net10.0 | 2 | `c062a526853a58aa6e32463b3906d90c632a51faddd8d23aae4b4579cdb4e096` |
| `mcp/LayerGuard/tests/fixtures/DirectReference/Direct.Domain/Direct.Domain.csproj` | fixture | net10.0 | 3 | `f13c26b75b7ace0edc1eb0ba7431ed9d9517d0e21810662d8ac87fc539a03a0f` |
| `mcp/LayerGuard/tests/fixtures/DirectReference/Direct.Infrastructure/Direct.Infrastructure.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/DirectReference/Direct.Presentation/Direct.Presentation.csproj` | fixture | net10.0 | 1 | `55271acf6a6618d73a2a21ddbb47f80bb5ddeb7a248c18996b69a9b68a514dfe` |
| `mcp/LayerGuard/tests/fixtures/DirectSiblingReference/Sibling.Infrastructure/Sibling.Infrastructure.csproj` | fixture | net10.0 | 1 | `72f4edf31075ad4eb959d993617a8d29fbe3076fd5203625b104d633a46bb15e` |
| `mcp/LayerGuard/tests/fixtures/DirectSiblingReference/Sibling.Presentation/Sibling.Presentation.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/DisableTransitive/NoFlow.Carrier/NoFlow.Carrier.csproj` | fixture | net10.0 | 1 | `ec1b32cf25804fd76fc11ba4f03f6f48e28d37811f691eee4d1d0ef48e641a6a` |
| `mcp/LayerGuard/tests/fixtures/DisableTransitive/NoFlow.Domain/NoFlow.Domain.csproj` | fixture | net10.0 | 1 | `0f17cb06de084ea267842b00b9ea52b72820a14c065b0eb23c00faa70fdab4d2` |
| `mcp/LayerGuard/tests/fixtures/DisableTransitive/NoFlow.Infrastructure/NoFlow.Infrastructure.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/DisableTransitive/NoFlow.Presentation/NoFlow.Presentation.csproj` | fixture | net10.0 | 1 | `dcd563690f68db1a618788c26d92e579684a313da02a2bcf1a63fd509c52d492` |
| `mcp/LayerGuard/tests/fixtures/ForbiddenDependencies/Acme.Application/Acme.Application.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/ForbiddenDependencies/Acme.Infrastructure/Acme.Infrastructure.csproj` | fixture | net10.0 | 1 | `c8b7d515e027af36e6d7fe87a6ac13c726ddd044749185127b8d09cc44948f37` |
| `mcp/LayerGuard/tests/fixtures/ForbiddenDependencies/Acme.Presentation/Acme.Presentation.csproj` | fixture | net10.0 | 1 | `c8b7d515e027af36e6d7fe87a6ac13c726ddd044749185127b8d09cc44948f37` |
| `mcp/LayerGuard/tests/fixtures/ForbiddenPackages/Shop.Application/Shop.Application.csproj` | fixture | net10.0 | 1 | `da3d88fd9b7013b31878340ecf8a89648c24f92c72e2a3942231092f98cd46db` |
| `mcp/LayerGuard/tests/fixtures/ForbiddenPackages/Shop.Domain/Shop.Domain.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/ForbiddenPackages/Shop.Presentation/Shop.Presentation.csproj` | fixture | net10.0 | 1 | `ae76350c0d965be21d32329316ead7df521ebb7dd647156a16dad7606134742c` |
| `mcp/LayerGuard/tests/fixtures/Implements/Acme.Domain/Acme.Domain.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/Implements/Acme.Infrastructure/Acme.Infrastructure.csproj` | fixture | net10.0 | 1 | `2326d5d760005d56fc9638b33564ae04af4ddad516f7eef71da7ee515be437e5` |
| `mcp/LayerGuard/tests/fixtures/Imports/Acme.Application/Acme.Application.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/Imports/Acme.Domain/Acme.Domain.csproj` | fixture | net10.0 | 1 | `7faebb52b518a0856806c83902bb29de1c2914174393a9d3392ae61cd078f859` |
| `mcp/LayerGuard/tests/fixtures/Imports/Acme.Shared/Acme.Shared.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/IndirectKeptPrivate/Private.AppCarrier/Private.AppCarrier.csproj` | fixture | net10.0 | 1 | `52268b98a614996b72b8c5af681764c90e6b81444c9b306c232d72f6a0f57009` |
| `mcp/LayerGuard/tests/fixtures/IndirectKeptPrivate/Private.Application/Private.Application.csproj` | fixture | net10.0 | 2 | `d8d47bb1ec0d92489b9ab5a6b07474479c825e522649782b394be16f726a1b23` |
| `mcp/LayerGuard/tests/fixtures/IndirectKeptPrivate/Private.Domain/Private.Domain.csproj` | fixture | net10.0 | 3 | `50ebe3019791fbdba1251aeb463c4ab801393dcea818916796fc0aa4458caafb` |
| `mcp/LayerGuard/tests/fixtures/IndirectKeptPrivate/Private.InfraCarrier/Private.InfraCarrier.csproj` | fixture | net10.0 | 1 | `af2f78de836932deabc98fc42699a649e0b4ed306afcca273ad1cf1027045bc4` |
| `mcp/LayerGuard/tests/fixtures/IndirectKeptPrivate/Private.Infrastructure/Private.Infrastructure.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/IndirectKeptPrivate/Private.PresCarrier/Private.PresCarrier.csproj` | fixture | net10.0 | 1 | `1709dfcb1eb44801340f7774ebd70fe57eee4ff159edf3a220728a35d7bd954c` |
| `mcp/LayerGuard/tests/fixtures/IndirectKeptPrivate/Private.Presentation/Private.Presentation.csproj` | fixture | net10.0 | 1 | `0f1583e1379db9d1518e6cde5449f89be5466490cb55a32177fab1768a0ba30c` |
| `mcp/LayerGuard/tests/fixtures/IndirectReference/Indirect.AppCarrier/Indirect.AppCarrier.csproj` | fixture | net10.0 | 1 | `59ae570c0a95a711304af5785d4f49f5fe4bb6f2037e2340ddcfe240cad4a0c4` |
| `mcp/LayerGuard/tests/fixtures/IndirectReference/Indirect.Application/Indirect.Application.csproj` | fixture | net10.0 | 2 | `46375b452543ea5e354651ab71dd3b1c270093b0b724fe5d4fa675c6b9cce68f` |
| `mcp/LayerGuard/tests/fixtures/IndirectReference/Indirect.Domain/Indirect.Domain.csproj` | fixture | net10.0 | 3 | `33a9c3103220a5afa01a2e8db1a2710d99097ff805949046ac48f6c2397efb45` |
| `mcp/LayerGuard/tests/fixtures/IndirectReference/Indirect.InfraCarrier/Indirect.InfraCarrier.csproj` | fixture | net10.0 | 1 | `8c129bbd83e8c3207baff507577976ec99cd1f20f45ed525d90ed06e49a3a9c4` |
| `mcp/LayerGuard/tests/fixtures/IndirectReference/Indirect.Infrastructure/Indirect.Infrastructure.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/IndirectReference/Indirect.PresCarrier/Indirect.PresCarrier.csproj` | fixture | net10.0 | 1 | `373cb69106e662fe6443b466fa92ba70224e54e3b58824d451d7a15abced9fd8` |
| `mcp/LayerGuard/tests/fixtures/IndirectReference/Indirect.Presentation/Indirect.Presentation.csproj` | fixture | net10.0 | 1 | `afd9ba72f208ccb2adab44d186f4a32ab014c546ce335f908b587320e306de0d` |
| `mcp/LayerGuard/tests/fixtures/IndirectSharedHop/Hop.Application/Hop.Application.csproj` | fixture | net10.0 | 1 | `947885773d0ffdf11a3331a93e5c57843c8f2e22b0ea5bdcc8b3a2203d485d47` |
| `mcp/LayerGuard/tests/fixtures/IndirectSharedHop/Hop.Carrier/Hop.Carrier.csproj` | fixture | net10.0 | 1 | `bae42eea7a0b2e615325063d0a98253f42b4102c46b395a12fdb7562a61df7ac` |
| `mcp/LayerGuard/tests/fixtures/IndirectSharedHop/Hop.Domain/Hop.Domain.csproj` | fixture | net10.0 | 1 | `c9230e22725cd724a0fb8efe44ed09c67ab6527bdef023fe7ba1a7f85e253a40` |
| `mcp/LayerGuard/tests/fixtures/IndirectSharedHop/Hop.Infrastructure/Hop.Infrastructure.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/IndirectSiblingReference/IndSibling.Infrastructure/IndSibling.Infrastructure.csproj` | fixture | net10.0 | 1 | `8a9317e45c569021a06dd7a8565431a8559849b3bb6320eff21d290e16e0add6` |
| `mcp/LayerGuard/tests/fixtures/IndirectSiblingReference/IndSibling.PresCarrier/IndSibling.PresCarrier.csproj` | fixture | net10.0 | 1 | `ecf19b56a435ba2143b3d54d045c81f257627f4da1bdef2beb76142d4d0ba774` |
| `mcp/LayerGuard/tests/fixtures/IndirectSiblingReference/IndSibling.Presentation/IndSibling.Presentation.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/PrivateAssetsAttributeForm/Attr.Domain/Attr.Domain.csproj` | fixture | net10.0 | 1 | `d5beb532073186113f0a2158b6a699ac93767e64719c587724c77346a29c39f0` |
| `mcp/LayerGuard/tests/fixtures/PrivateAssetsAttributeForm/Attr.Infrastructure/Attr.Infrastructure.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/PrivateAssetsAttributeForm/Attr.OpenCarrier/Attr.OpenCarrier.csproj` | fixture | net10.0 | 1 | `529a4d8b7785c227952ddd3190cc3a47880e88aa00da6c69e76c338e231ecec4` |
| `mcp/LayerGuard/tests/fixtures/PrivateAssetsAttributeForm/Attr.Presentation/Attr.Presentation.csproj` | fixture | net10.0 | 1 | `ae097e4195ad34128a468ddf0f74f38e6f1640262831a1a33000b5d19bced49b` |
| `mcp/LayerGuard/tests/fixtures/PrivateAssetsAttributeForm/Attr.SealedCarrier/Attr.SealedCarrier.csproj` | fixture | net10.0 | 1 | `daea151daf90b02b49763e562cf3641ff1fe80161a78ecc354090146a4a4c85e` |
| `mcp/LayerGuard/tests/fixtures/Rulebook/Billing/Acme.Billing.Application/Acme.Billing.Application.csproj` | fixture | net10.0 | 1 | `b6959ce2ae349901e7a81a08ac6837f833f7a7734608075800b9c083bc517544` |
| `mcp/LayerGuard/tests/fixtures/Rulebook/Billing/Acme.Billing.Domain/Acme.Billing.Domain.csproj` | fixture | net10.0 | 2 | `bca0eccea7f2c17c87684bdb37121ab4aa0f5043e6b3a56640284e7194985f54` |
| `mcp/LayerGuard/tests/fixtures/Rulebook/Billing/Acme.Billing.Helper/Acme.Billing.Helper.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/Rulebook/Billing/Acme.Billing.Presentation/Acme.Billing.Presentation.csproj` | fixture | net10.0 | 0 | `64085fe457fbf08f82cc8a8ab142fa2f9902ff1ef5cfbcb28080c2f6182efdc7` |
| `mcp/LayerGuard/tests/fixtures/Rulebook/Shared/Acme.Shared.Legacy/Acme.Shared.Legacy.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/SolutionScope/Sln.Domain/Sln.Domain.csproj` | fixture | net10.0 | 1 | `bbfa76f84fe201270674fe22ead5606d27549b58abc4a4a0543d3f0d6d91fdeb` |
| `mcp/LayerGuard/tests/fixtures/SolutionScope/Sln.Infrastructure/Sln.Infrastructure.csproj` | fixture | net10.0 | 0 | `1c43c7cc8c35b222c7c4b03bf4237ba9301a67db28f76a85ef1b77d2a46c0df3` |
| `mcp/LayerGuard/tests/fixtures/SolutionScope/Sln.Presentation/Sln.Presentation.csproj` | fixture | net10.0 | 1 | `bbfa76f84fe201270674fe22ead5606d27549b58abc4a4a0543d3f0d6d91fdeb` |
| `mcp/LayerGuard/tests/LayerGuard.Tests/LayerGuard.Tests.csproj` | test | net10.0 | 1 | `46f59f744b7aefd7ca445d9572c086c5e076ad788fafb125df927703dbedb66e` |
| `src/ApiHost/IFX.ApiHost/IFX.ApiHost.csproj` | source | net8.0 | 13 | `856503c6163622ac84b64cf665fbea99ab1d6b0581ba09b1a1616fc3592d3e3e` |
| `src/BuildingBlocks/IFX.BuildingBlocks.Application/IFX.BuildingBlocks.Application.csproj` | source | net8.0 | 1 | `f0ae1c7f9fd9f87d725f0b5e75963f07cbbd58be624923f577d45bf0b05be139` |
| `src/BuildingBlocks/IFX.BuildingBlocks.Composition/IFX.BuildingBlocks.Composition.csproj` | source | net8.0 | 0 | `56a0ea1413047a986c2bf5cdb2e2090bd729d990ce53ffe50e5098aae0e43722` |
| `src/BuildingBlocks/IFX.BuildingBlocks.Domain/IFX.BuildingBlocks.Domain.csproj` | source | net8.0 | 0 | `50a4358f1cf8fe20edf3862e58aff352f66812d56899196d82ae2963cc9d0455` |
| `src/BuildingBlocks/IFX.BuildingBlocks.EntityFrameworkCore/IFX.BuildingBlocks.EntityFrameworkCore.csproj` | source | net8.0 | 1 | `9de264d06d9749d59f764d0bb45118e1040747314d7a5d78dd27089cf68cbe86` |
| `src/BuildingBlocks/IFX.BuildingBlocks.Security/IFX.BuildingBlocks.Security.csproj` | source | net8.0 | 0 | `b375d7c4b26bab8437ca9540888062677fab0f55ba0a82a03cbae5917d986eb3` |
| `src/DatabaseMigrator/IFX.DatabaseMigrator/IFX.DatabaseMigrator.csproj` | source | net8.0 | 6 | `941afd9bbb9c81b77b7e875a59dbbde0a29aa0b7437823730eba0c30b00e28da` |
| `src/Modules/CRM/IFX.Modules.CRM.Application/IFX.Modules.CRM.Application.csproj` | source | net8.0 | 4 | `0ca2f1daebe1f4f44db7018bbc423dfc9e63fb5b80a3ec946d9554a9dd2e6b72` |
| `src/Modules/CRM/IFX.Modules.CRM.Composition/IFX.Modules.CRM.Composition.csproj` | source | net8.0 | 5 | `0d8253b68367ae9d2f41bcf1c84eefb539bcbcef43bc69bb6f39307c537c4ca5` |
| `src/Modules/CRM/IFX.Modules.CRM.Contracts/IFX.Modules.CRM.Contracts.csproj` | source | net8.0 | 1 | `81d607516ea40e0c0d39902e465a462ad452aa2525ac4b0f30a164c4ac0a4d5d` |
| `src/Modules/CRM/IFX.Modules.CRM.Domain/IFX.Modules.CRM.Domain.csproj` | source | net8.0 | 1 | `af748c968f3b3137ae6dbe5e0d693078684bcc3bc44bc85ec1f66765c2467db9` |
| `src/Modules/CRM/IFX.Modules.CRM.Infrastructure/IFX.Modules.CRM.Infrastructure.csproj` | source | net8.0 | 6 | `676927caa5dbef8f24f0df622b4012e9bde6de9d209bf3542766858531a210c9` |
| `src/Modules/CRM/IFX.Modules.CRM.Presentation/IFX.Modules.CRM.Presentation.csproj` | source | net8.0 | 1 | `4a4dc642e4ff06d9401a6e01f5a9c50c2e9489e48da1ea8eeecfcae0f4cb3eb0` |
| `src/Modules/Holdings/IFX.Modules.Holdings.Application/IFX.Modules.Holdings.Application.csproj` | source | net8.0 | 3 | `221608dce4609c8d38c68fa045b00c1f38ec3b3581e84d1daf13c54195223dca` |
| `src/Modules/Holdings/IFX.Modules.Holdings.Composition/IFX.Modules.Holdings.Composition.csproj` | source | net8.0 | 4 | `45a4f317367e48bd66eca7d98e6a1bb83976fd2c1efa5fb9e3560d156956a1de` |
| `src/Modules/Holdings/IFX.Modules.Holdings.Domain/IFX.Modules.Holdings.Domain.csproj` | source | net8.0 | 1 | `4c19d957ae3fd8b3d5545059df2299ae1a04380a6b89579d208780a15b4dfba4` |
| `src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/IFX.Modules.Holdings.Infrastructure.csproj` | source | net8.0 | 9 | `6ab1d69a99ed7279c69def5353b5a216ab3d84c9d7184072e0b7891facf6858c` |
| `src/Modules/Holdings/IFX.Modules.Holdings.Presentation/IFX.Modules.Holdings.Presentation.csproj` | source | net8.0 | 1 | `3349276a3e7c920701f66c573d15ca87a4ab710db9d67942eb2c87ef57e075e4` |
| `src/Modules/IAM/IFX.Modules.IAM.Application/IFX.Modules.IAM.Application.csproj` | source | net8.0 | 5 | `9ea1a4c798fa0df367f9bc810e388c30024b9135ca354f4749edba42c542e338` |
| `src/Modules/IAM/IFX.Modules.IAM.Client/IFX.Modules.IAM.Client.csproj` | source | net8.0 | 3 | `b9f390e078baab773a619ee1bf55761c88479435c350766e5af2c86704257a20` |
| `src/Modules/IAM/IFX.Modules.IAM.Composition/IFX.Modules.IAM.Composition.csproj` | source | net8.0 | 9 | `2f21358d51dac3cb9fa304a0a32021cb34afaafadd2b90ab2d0de133384768a9` |
| `src/Modules/IAM/IFX.Modules.IAM.Contracts/IFX.Modules.IAM.Contracts.csproj` | source | net8.0 | 1 | `e7f3004505f4f571ba8cb094831693317977bff768a1ac683b808800cbdb8995` |
| `src/Modules/IAM/IFX.Modules.IAM.Domain/IFX.Modules.IAM.Domain.csproj` | source | net8.0 | 1 | `deb8a2728bb003f0e227feaa8ea2ea79761a3bae2c8e4c680775ff16ef9f1470` |
| `src/Modules/IAM/IFX.Modules.IAM.Infrastructure/IFX.Modules.IAM.Infrastructure.csproj` | source | net8.0 | 9 | `469cab8533ea8fa651d33fff6ebe0d54736642f8c1ea4e81f454b5939dea11fe` |
| `src/Modules/IAM/IFX.Modules.IAM.Presentation/IFX.Modules.IAM.Presentation.csproj` | source | net8.0 | 1 | `8b22e5c0cd33690b2a806eefd959f7479873b63e5a51621b403a618e5922468a` |
| `src/Modules/Registry/IFX.Modules.Registry.Application/IFX.Modules.Registry.Application.csproj` | source | net8.0 | 4 | `d6c1c08cead7946f9b8d4c66a5ce1414d6262a3d6dae1d6556754864b5a20dbb` |
| `src/Modules/Registry/IFX.Modules.Registry.Composition/IFX.Modules.Registry.Composition.csproj` | source | net8.0 | 5 | `4f777730e37389fe20d962bb1a1f32e44e0debc623effd93010a1aa07e67fda9` |
| `src/Modules/Registry/IFX.Modules.Registry.Contracts/IFX.Modules.Registry.Contracts.csproj` | source | net8.0 | 2 | `897ca2f7a3dfb11ccc8dc2db1af1e3cb35b2dc1c1c6cea8b84851cb80890f66a` |
| `src/Modules/Registry/IFX.Modules.Registry.Domain/IFX.Modules.Registry.Domain.csproj` | source | net8.0 | 1 | `af748c968f3b3137ae6dbe5e0d693078684bcc3bc44bc85ec1f66765c2467db9` |
| `src/Modules/Registry/IFX.Modules.Registry.Infrastructure/IFX.Modules.Registry.Infrastructure.csproj` | source | net8.0 | 7 | `70f93285e40e582be760a5d3fd56760cf311aef12de6394f6de6e450c528fc62` |
| `src/Modules/Registry/IFX.Modules.Registry.Presentation/IFX.Modules.Registry.Presentation.csproj` | source | net8.0 | 1 | `a293d1a23b7093ca8b2c25f6d6b6692c3017868844e96c90be8bc42ab6a1bf29` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Application/IFX.Modules.Transaction.Application.csproj` | source | net8.0 | 3 | `4ae3aaa6f7880df8cf3c24054ec5deef9cddca31efca1bff0fc1bbc108cb8585` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Composition/IFX.Modules.Transaction.Composition.csproj` | source | net8.0 | 6 | `d3d76563882c0f603b688bbedf3eb0687a50e4d35d4d3cbf5e248c623f58321f` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Contracts/IFX.Modules.Transaction.Contracts.csproj` | source | net8.0 | 1 | `594d622837dca2aa1a6f264dc3f3b94c12ab1fdfdbc2458628456918ded6e1bf` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Domain/IFX.Modules.Transaction.Domain.csproj` | source | net8.0 | 1 | `4c19d957ae3fd8b3d5545059df2299ae1a04380a6b89579d208780a15b4dfba4` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Infrastructure/IFX.Modules.Transaction.Infrastructure.csproj` | source | net8.0 | 11 | `4abbba9cbe0bf0c4ead2e156895164ac4f59d98e2a6883f11c0bff11d0a113c0` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Presentation/IFX.Modules.Transaction.Presentation.csproj` | source | net8.0 | 1 | `fb0f7936f7fd44cb1c608ae0e45603803a4738693ba438f7b9bf9862a6d18829` |
| `src/Platform/Authentication/IFX.Platform.Authentication.Composition/IFX.Platform.Authentication.Composition.csproj` | source | net8.0 | 3 | `e4e3f30aa931e93f8743425b5720c98a3d030dba7a36d0b79357eb10cd8ccdb8` |
| `src/Platform/Authentication/IFX.Platform.Authentication.Contracts/IFX.Platform.Authentication.Contracts.csproj` | source | net8.0 | 0 | `8bfbe2bf0c6036509cacdfd064a59d230c80b49cac589bd8119be4e9f07c9084` |
| `src/Platform/Authentication/IFX.Platform.Authentication.Infrastructure.Auth0/IFX.Platform.Authentication.Infrastructure.Auth0.csproj` | source | net8.0 | 1 | `871b0a48855036c877a0b868e75bfcc5f7dace6f9a054e4d96ecf548e595a5d0` |
| `src/Platform/Authentication/IFX.Platform.Authentication.Infrastructure.Cognito/IFX.Platform.Authentication.Infrastructure.Cognito.csproj` | source | net8.0 | 1 | `056aa1d23fe521edd7eb27eb4d74a35743c559f52ca31d324fd328b6975eb951` |
| `src/Platform/Authentication/IFX.Platform.Authentication.Runtime/IFX.Platform.Authentication.Runtime.csproj` | source | net8.0 | 1 | `9361b49ce7b947e627f5845731a0c0843141231edf80d96fe4bdd1ea47ff83ef` |
| `src/Platform/Authorization/IFX.Platform.Authorization.Composition/IFX.Platform.Authorization.Composition.csproj` | source | net8.0 | 3 | `effe9a99bcd3aa0359e06eefd696c403c87b9cf9ac8b2b3b4b1362daabbf409f` |
| `src/Platform/Authorization/IFX.Platform.Authorization.Contracts/IFX.Platform.Authorization.Contracts.csproj` | source | net8.0 | 0 | `db5f6c13ee05bb9c620cf8a3549ff9bac4d367116fb11c0f3c3a1e8bd5d52ad6` |
| `src/Platform/Authorization/IFX.Platform.Authorization.Infrastructure.Opa/IFX.Platform.Authorization.Infrastructure.Opa.csproj` | source | net8.0 | 2 | `e02903ba0784916a75d8ab9ea0ecf103a6cc48ef494f017b20332c962171fc49` |
| `src/Platform/Authorization/IFX.Platform.Authorization.Runtime/IFX.Platform.Authorization.Runtime.csproj` | source | net8.0 | 1 | `825c991113164cc89f1e32ef424b7a8e1d6516c17eb8764beb6cfb3ff4c0a5eb` |
| `src/Platform/BackgroundJobs/IFX.Platform.BackgroundJobs.Composition/IFX.Platform.BackgroundJobs.Composition.csproj` | source | net8.0 | 3 | `c4a89c6eefd456fd8c3d99ac88b6e72b2e46280149956913862314fe3232b4e1` |
| `src/Platform/BackgroundJobs/IFX.Platform.BackgroundJobs.Contracts/IFX.Platform.BackgroundJobs.Contracts.csproj` | source | net8.0 | 0 | `427d1e050e34969c21ed62ae104c9f0d53391d4c9f6f6d67e43ac6cada4d0dca` |
| `src/Platform/BackgroundJobs/IFX.Platform.BackgroundJobs.Infrastructure.Hangfire/IFX.Platform.BackgroundJobs.Infrastructure.Hangfire.csproj` | source | net8.0 | 1 | `ff87cf4f71d036701b607f3af7feb9239a500bc31e4f28d9360f889f5ce3ec77` |
| `src/Platform/Context/IFX.Platform.Context.Contracts/IFX.Platform.Context.Contracts.csproj` | source | net8.0 | 0 | `427d1e050e34969c21ed62ae104c9f0d53391d4c9f6f6d67e43ac6cada4d0dca` |
| `src/Platform/Context/IFX.Platform.Context.Runtime/IFX.Platform.Context.Runtime.csproj` | source | net8.0 | 2 | `51481621e645025c19887baead51a6e3489999771d9465b53059e6ba7f79f843` |
| `src/Platform/IFX.Platform.Shared/IFX.Platform.Shared.csproj` | source | net8.0 | 0 | `e151f959964eb450a5b86b72765e3f9c505645fa9516eae485743d2b43911c8e` |
| `src/Platform/Messaging/IFX.Platform.Messaging.Composition/IFX.Platform.Messaging.Composition.csproj` | source | net8.0 | 1 | `d18c86af33ae75522df3ded32e586c3d5d55679fc8b9dd054a7d8776ca2edbdc` |
| `src/Platform/Messaging/IFX.Platform.Messaging.Contracts/IFX.Platform.Messaging.Contracts.csproj` | source | net8.0 | 0 | `427d1e050e34969c21ed62ae104c9f0d53391d4c9f6f6d67e43ac6cada4d0dca` |
| `src/Platform/Messaging/IFX.Platform.Messaging.Runtime/IFX.Platform.Messaging.Runtime.csproj` | source | net8.0 | 3 | `c5a8c79ae33a994299bfadbe98b05f15ce6e08448566e11dbb4d4f35f103a987` |
| `src/Platform/Notifications/IFX.Platform.Notifications.Composition/IFX.Platform.Notifications.Composition.csproj` | source | net8.0 | 2 | `04a2bddd5cbefb08a0f34740fc2f9a7a7b121db543bebbc3fad52e7716ba52bd` |
| `src/Platform/Notifications/IFX.Platform.Notifications.Contracts/IFX.Platform.Notifications.Contracts.csproj` | source | net8.0 | 0 | `427d1e050e34969c21ed62ae104c9f0d53391d4c9f6f6d67e43ac6cada4d0dca` |
| `src/Platform/Notifications/IFX.Platform.Notifications.Infrastructure.SendGrid/IFX.Platform.Notifications.Infrastructure.SendGrid.csproj` | source | net8.0 | 2 | `3912e766d3f5748da9247c4ee5048bfac5f1510a6eee9357068502c01af16f01` |
| `tests/IFX.BuildingBlocks.Application.Tests/IFX.BuildingBlocks.Application.Tests.csproj` | test | net8.0 | 1 | `8b3cb70c92b0c132c72be6b8b7772f50f7f1e94ce843d170bf325d84b509dbc4` |
| `tests/IFX.BuildingBlocks.EntityFrameworkCore.Tests/IFX.BuildingBlocks.EntityFrameworkCore.Tests.csproj` | test | net8.0 | 1 | `5a1080ebcd98bc87a973caf81f3d82e8e8a73e904cf4f5ae252f6318491c9ae9` |
| `tests/IFX.DatabaseBoundary.Tests/IFX.DatabaseBoundary.Tests.csproj` | test | net8.0 | 8 | `03714839c57f17cdadb179a3a8475318100a44bc0ed15b3cfe86d6f102a82376` |
| `tests/IFX.IntegrationTests/IFX.IntegrationTests.csproj` | test | net8.0 | 8 | `fc02fbcbedecb0539611ecd565ed989ad2eff20d387dab13e9ed3da8a6737736` |
| `tests/IFX.Modules.CRM.Application.Tests/IFX.Modules.CRM.Application.Tests.csproj` | test | net8.0 | 3 | `fc17d5a866eec2e15b73ecdcc612de16145282ecd6b93526ed2386e8caafb4a9` |
| `tests/IFX.Modules.CRM.Domain.Tests/IFX.Modules.CRM.Domain.Tests.csproj` | test | net8.0 | 1 | `0ace8d9b67281e080eadcd652d04595b0896d1237c9efa29aeb236aa4f6f8c42` |
| `tests/IFX.Modules.Holdings.Application.Tests/IFX.Modules.Holdings.Application.Tests.csproj` | test | net8.0 | 1 | `8fb87c0f3115c56f16db50dc75ae39d32ca955b1020d4d6fe905a92f4d7c9fc5` |
| `tests/IFX.Modules.Holdings.Domain.Tests/IFX.Modules.Holdings.Domain.Tests.csproj` | test | net8.0 | 1 | `7f219de9ae3d8b7d7748b037cd6005f91cac10965ad183aa3c484cabc57b2a24` |
| `tests/IFX.Modules.IAM.Application.Tests/IFX.Modules.IAM.Application.Tests.csproj` | test | net8.0 | 2 | `ea7e1f4fc5469e881f3aa4f12ca86d471dbe1673630a43f582ab41d71ad17020` |
| `tests/IFX.Modules.IAM.Domain.Tests/IFX.Modules.IAM.Domain.Tests.csproj` | test | net8.0 | 2 | `2a205f246cd39053bea56ae6746a0ec295d75f386e11665900ad48d3b0b1a4e8` |
| `tests/IFX.Modules.IAM.Infrastructure.Tests/IFX.Modules.IAM.Infrastructure.Tests.csproj` | test | net8.0 | 3 | `1e6440b1806350d709a67f2e8b9ef7d693101babf0d07fce498b6715ec309741` |
| `tests/IFX.Modules.IAM.Presentation.Tests/IFX.Modules.IAM.Presentation.Tests.csproj` | test | net8.0 | 2 | `1dc9b5f8ec2401b6863dba365e0989807fcd69fc6faa064d0eff9b98f5effd46` |
| `tests/IFX.Modules.Registry.Application.Tests/IFX.Modules.Registry.Application.Tests.csproj` | test | net8.0 | 3 | `73a8d5830a74fe97facf9a9ebdff194028359b86467501c417cea7cdd5ed9734` |
| `tests/IFX.Modules.Registry.Domain.Tests/IFX.Modules.Registry.Domain.Tests.csproj` | test | net8.0 | 1 | `663ec0e31342ecdda8007bd5bf07fe32202c5ce799362ca2ba8ab9fcc544af0c` |
| `tests/IFX.Modules.Transaction.Application.Tests/IFX.Modules.Transaction.Application.Tests.csproj` | test | net8.0 | 1 | `f765e9e3e706b23a7b233da90f280888b707db91aee2fd1e2ea62823a2e905c4` |
| `tests/IFX.Modules.Transaction.Domain.Tests/IFX.Modules.Transaction.Domain.Tests.csproj` | test | net8.0 | 1 | `6955b5502520ecd3c872bbdfd095c01ee0011b6a3f175c10f3e2d1ecfcbfdb02` |
| `tests/IFX.Platform.Authentication.Tests/IFX.Platform.Authentication.Tests.csproj` | test | net8.0 | 2 | `97560bf9567d00d30ba611fe4b74d6d9030c93c530122a40ca4ae54e2e321b8e` |
| `tests/IFX.Platform.Authorization.Tests/IFX.Platform.Authorization.Tests.csproj` | test | net8.0 | 2 | `4cfb1a844f6338d077c57d0a7c6b44272306effa5fdcc680ca8c1e128057f5f2` |
| `tests/IFX.Platform.BackgroundJobs.Tests/IFX.Platform.BackgroundJobs.Tests.csproj` | test | net8.0 | 2 | `166e55ef7292dfd482bab5651787de1f37846fbe7c38e005a8d32e96a893be7d` |
| `tests/IFX.Platform.Notifications.Tests/IFX.Platform.Notifications.Tests.csproj` | test | net8.0 | 3 | `980362bc3856397a851a4abde4283aa15030138d9baa574f1adce18661fffe3c` |
| `tests/IFX.Platform.ProtocolContracts.Tests/IFX.Platform.ProtocolContracts.Tests.csproj` | test | net8.0 | 6 | `39f4d39206ce9fbb1ee26e62d5cf4cda7ade67204f7e2090325ecc1290f6ea3c` |
| `tests/IFX.Tests.Common/IFX.Tests.Common.csproj` | test | net8.0 | 2 | `b1e08f2785be07775e92be6275859aa57c1c7390e6b8dbe10d5c719f6c2fed58` |
| `tools/IFX.DatabaseInventory/IFX.DatabaseInventory.csproj` | source | net8.0 | 5 | `df069526d2a1c30797b76e893a442606bff7bcf49189e0214316ad91ff23ee58` |

## Manifests

- `Directory.Build.props` (Directory.Build.props, SHA-256 `92b9390a169bd048f661d260145dc2c176c2886d2e7551b66e322e78a55cae06`)
- `IFX.sln` (IFX.sln, SHA-256 `078bc0b7266ba0be545229492a7a9a93f36d750d0984ba7c63822abf07856994`)
- `mcp/LayerGuard/LayerGuard.slnx` (LayerGuard.slnx, SHA-256 `f00e5b973bed62eaf8c1b87b37befae3d5c1ae979e307056b4d83e351f8f4adb`)
- `mcp/LayerGuard/tests/fixtures/SolutionScope/SolutionScope.sln` (SolutionScope.sln, SHA-256 `5a7f66cef572db5d3bbc1f3643828c3504d6e5992b661d2adc5241dcdf640ac2`)
- `src/ApiHost/IFX.ApiHost/IFX.ApiHost.sln` (IFX.ApiHost.sln, SHA-256 `0a56236cd32f80c399c5b003852ffa301d8cadf7fdaaa561734bcf238b032b91`)
- `src/Frontend/IFX.FrontEnd/package.json` (package.json, SHA-256 `42095d50bc43d63199367e51524a1cebde3445cb1651f26c09b169364860f53f`)

## CI workflows

- `.github/workflows/v3-ifx-guardrails.yml` (SHA-256 `d9dfa2f7e519efcb5a377de9b9dd2a78b2cff34e770ff863f82a75252ab560f6`)

## Agent/owner guidance

- `.github/CODEOWNERS` (SHA-256 `e6df36b23aa0578b02ef8135e67e22b3b93370f60f408e9feee9f591993529f4`)
- `CLAUDE.md` (SHA-256 `a7c485a879101d4e60113d6530a0b418c7ead808280b3a2a6e275ac305c9a4c4`)
