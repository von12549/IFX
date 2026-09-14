# Target inventory

Evidence is recorded in [inventory.json](inventory.json). Project references are literal XML declarations; MSBuild conditions, imports, generated files and transitive graphs are not evaluated. Source/test/fixture roles are path-name hints for review.

## .NET projects (169)

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
| `mcp/LayerGuard/tests/fixtures/BootstrapArchitecture/Billing/Acme.Billing.Infrastructure/Acme.Billing.Infrastructure.csproj` | fixture |  | 2 | `628de201baedaf0c45d4b4904f31cf3d57ce99fd855596275a3af536c34b0870` |
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
| `src/ApiHost/IFX.ApiHost/IFX.ApiHost.csproj` | source | net8.0 | 13 | `50df26397f9a5bd48c0be771dc68bf36519c7e3bc769273c337c8d0b0d5a5652` |
| `src/BuildingBlocks/IFX.BuildingBlocks.Application/IFX.BuildingBlocks.Application.csproj` | source | net8.0 | 1 | `fbbe64e4072ad17dc43f919abad1984e1a3276f018d0b22b11afe7c37bbff55d` |
| `src/BuildingBlocks/IFX.BuildingBlocks.Composition/IFX.BuildingBlocks.Composition.csproj` | source | net8.0 | 0 | `56a0ea1413047a986c2bf5cdb2e2090bd729d990ce53ffe50e5098aae0e43722` |
| `src/BuildingBlocks/IFX.BuildingBlocks.Domain/IFX.BuildingBlocks.Domain.csproj` | source | net8.0 | 0 | `aa302c9b24cabfd510bc24c5fe2fe9f1d564a71a5868147b7650d6a5c9c83688` |
| `src/BuildingBlocks/IFX.BuildingBlocks.EntityFrameworkCore/IFX.BuildingBlocks.EntityFrameworkCore.csproj` | source | net8.0 | 1 | `b46139546c25b230ab71aa55f372f77b6821d0c918aebd26c2c903ad0e825a6e` |
| `src/BuildingBlocks/IFX.BuildingBlocks.Security/IFX.BuildingBlocks.Security.csproj` | source | net8.0 | 0 | `f428bbfb809b06c4891ce650a7ee121d32aaf298607b6bb1e7e5afdcf55e2f6c` |
| `src/DatabaseMigrator/IFX.DatabaseMigrator/IFX.DatabaseMigrator.csproj` | source | net8.0 | 6 | `dd065986c7a4f86b12b211c09c2a65ac8dbc953b4b8cf03f49d513b80775b681` |
| `src/Modules/CRM/IFX.Modules.CRM.Application/IFX.Modules.CRM.Application.csproj` | source | net8.0 | 5 | `6f692ceb23c353ac3b7fa2286e13e0dc6a8e9be05c06b8f46a08fcfced594629` |
| `src/Modules/CRM/IFX.Modules.CRM.Composition/IFX.Modules.CRM.Composition.csproj` | source | net8.0 | 5 | `2e037c713583e0f902914b8ba203fafb158ee3a6729f94efda121d4ecbd6cca5` |
| `src/Modules/CRM/IFX.Modules.CRM.Contracts/IFX.Modules.CRM.Contracts.csproj` | source | net8.0 | 1 | `81d607516ea40e0c0d39902e465a462ad452aa2525ac4b0f30a164c4ac0a4d5d` |
| `src/Modules/CRM/IFX.Modules.CRM.Domain/IFX.Modules.CRM.Domain.csproj` | source | net8.0 | 1 | `af748c968f3b3137ae6dbe5e0d693078684bcc3bc44bc85ec1f66765c2467db9` |
| `src/Modules/CRM/IFX.Modules.CRM.Infrastructure/IFX.Modules.CRM.Infrastructure.csproj` | source | net8.0 | 4 | `339b52f007fe0b6a13446e386dda9bad8ab98fa4d5fc0c4cdbc43bdbbfc9b5e9` |
| `src/Modules/CRM/IFX.Modules.CRM.Presentation/IFX.Modules.CRM.Presentation.csproj` | source | net8.0 | 1 | `1584b720c11fbd7f54f10d479ae6c46be20794867380de3920ea48764c40ac8c` |
| `src/Modules/Holdings/IFX.Modules.Holdings.Application/IFX.Modules.Holdings.Application.csproj` | source | net8.0 | 3 | `852766aa8162184ea6498749047ddb50be2e02281bd535035a90a1637496af26` |
| `src/Modules/Holdings/IFX.Modules.Holdings.Composition/IFX.Modules.Holdings.Composition.csproj` | source | net8.0 | 4 | `107557864c5b854c86590331b2ff5f279aa9950369dccbeffb33363c4deba9f2` |
| `src/Modules/Holdings/IFX.Modules.Holdings.Domain/IFX.Modules.Holdings.Domain.csproj` | source | net8.0 | 1 | `4c19d957ae3fd8b3d5545059df2299ae1a04380a6b89579d208780a15b4dfba4` |
| `src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/IFX.Modules.Holdings.Infrastructure.csproj` | source | net8.0 | 8 | `f209d4bbc67b63209a28396e5da411e58cd3b110184348a492c1ed36bc601ef6` |
| `src/Modules/Holdings/IFX.Modules.Holdings.Presentation/IFX.Modules.Holdings.Presentation.csproj` | source | net8.0 | 1 | `265c0072e941eb196fa634bcbce4fc0771109327e2a789cac512f96417d73e7d` |
| `src/Modules/IAM/IFX.Modules.IAM.Application/IFX.Modules.IAM.Application.csproj` | source | net8.0 | 5 | `b52471d2d3dede4788c14e0738e92b666348e0d7e5d34864d44a5ed7ad1a1921` |
| `src/Modules/IAM/IFX.Modules.IAM.Composition/IFX.Modules.IAM.Composition.csproj` | source | net8.0 | 9 | `9fe0c134d0600004d42e1eb92820712ec683a3bd6034d3eb60073bb77db67afe` |
| `src/Modules/IAM/IFX.Modules.IAM.Contracts/IFX.Modules.IAM.Contracts.csproj` | source | net8.0 | 1 | `e7f3004505f4f571ba8cb094831693317977bff768a1ac683b808800cbdb8995` |
| `src/Modules/IAM/IFX.Modules.IAM.Domain/IFX.Modules.IAM.Domain.csproj` | source | net8.0 | 1 | `deb8a2728bb003f0e227feaa8ea2ea79761a3bae2c8e4c680775ff16ef9f1470` |
| `src/Modules/IAM/IFX.Modules.IAM.Infrastructure/IFX.Modules.IAM.Infrastructure.csproj` | source | net8.0 | 6 | `f730775d5883f3e034b3b83a5a0a16b2f41aae97096ff8d9925eb9656bfe6380` |
| `src/Modules/IAM/IFX.Modules.IAM.Presentation/IFX.Modules.IAM.Presentation.csproj` | source | net8.0 | 1 | `cb18b9536faf5fc15db8a6d312723acdd275482ab931b7a413cf30ad396f2d65` |
| `src/Modules/Registry/IFX.Modules.Registry.Application/IFX.Modules.Registry.Application.csproj` | source | net8.0 | 5 | `c42d3dc46720288276b591ee405e3938666c28b833168cf4f2f553496810f017` |
| `src/Modules/Registry/IFX.Modules.Registry.Composition/IFX.Modules.Registry.Composition.csproj` | source | net8.0 | 5 | `ccaafb88cfe2b6daae76c4575b39585abbd3345edbe598ee70a1b4079bc3051a` |
| `src/Modules/Registry/IFX.Modules.Registry.Contracts/IFX.Modules.Registry.Contracts.csproj` | source | net8.0 | 2 | `897ca2f7a3dfb11ccc8dc2db1af1e3cb35b2dc1c1c6cea8b84851cb80890f66a` |
| `src/Modules/Registry/IFX.Modules.Registry.Domain/IFX.Modules.Registry.Domain.csproj` | source | net8.0 | 1 | `af748c968f3b3137ae6dbe5e0d693078684bcc3bc44bc85ec1f66765c2467db9` |
| `src/Modules/Registry/IFX.Modules.Registry.Infrastructure/IFX.Modules.Registry.Infrastructure.csproj` | source | net8.0 | 6 | `91251b58816100128e1baa776eb9c7e22b79ba046245c8f48629f34b9f2b3b62` |
| `src/Modules/Registry/IFX.Modules.Registry.Presentation/IFX.Modules.Registry.Presentation.csproj` | source | net8.0 | 1 | `5d63854dec00854392c28f47f6297ccaaa7890d7a1e99feb3791d90fd81ef3ce` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Application/IFX.Modules.Transaction.Application.csproj` | source | net8.0 | 4 | `0a774580e8d53d6674ad6ee81b61955ceca4838c36dba32c3734b2562fdbc152` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Composition/IFX.Modules.Transaction.Composition.csproj` | source | net8.0 | 6 | `320900ac4f478e06a38ba8e856494c3b70e06aa00ed2955cc72be80a7658c382` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Contracts/IFX.Modules.Transaction.Contracts.csproj` | source | net8.0 | 1 | `594d622837dca2aa1a6f264dc3f3b94c12ab1fdfdbc2458628456918ded6e1bf` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Domain/IFX.Modules.Transaction.Domain.csproj` | source | net8.0 | 1 | `4c19d957ae3fd8b3d5545059df2299ae1a04380a6b89579d208780a15b4dfba4` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Infrastructure/IFX.Modules.Transaction.Infrastructure.csproj` | source | net8.0 | 10 | `07f19b2f9d331c8b4746f96b0e86dcf743d30cf50b63f6641cbca2f61d952efe` |
| `src/Modules/Transaction/IFX.Modules.Transaction.Presentation/IFX.Modules.Transaction.Presentation.csproj` | source | net8.0 | 1 | `50a68b007c902f3003b6156f517a485d6ba4f79a56881933b58b3bb77ed00bb6` |
| `src/Platform/Authentication/IFX.Platform.Authentication.Composition/IFX.Platform.Authentication.Composition.csproj` | source | net8.0 | 3 | `e4e3f30aa931e93f8743425b5720c98a3d030dba7a36d0b79357eb10cd8ccdb8` |
| `src/Platform/Authentication/IFX.Platform.Authentication.Contracts/IFX.Platform.Authentication.Contracts.csproj` | source | net8.0 | 0 | `8bfbe2bf0c6036509cacdfd064a59d230c80b49cac589bd8119be4e9f07c9084` |
| `src/Platform/Authentication/IFX.Platform.Authentication.Infrastructure.Auth0/IFX.Platform.Authentication.Infrastructure.Auth0.csproj` | source | net8.0 | 1 | `125ca93bf5c48e1aa0a6c60d5f4b2ead0b8fec3bc12d7ddd34d2c0a9113920b3` |
| `src/Platform/Authentication/IFX.Platform.Authentication.Infrastructure.Cognito/IFX.Platform.Authentication.Infrastructure.Cognito.csproj` | source | net8.0 | 1 | `33df7c632ed98e28aa5a0d32a84631d9c938688a6a7f8ff534c66d2f865e0bec` |
| `src/Platform/Authentication/IFX.Platform.Authentication.Runtime/IFX.Platform.Authentication.Runtime.csproj` | source | net8.0 | 1 | `ff980e56b2dd04f69600ab6cb19481575aac6be5a4643bbe3ad630c4c1094df3` |
| `src/Platform/Authorization/IFX.Platform.Authorization.Composition/IFX.Platform.Authorization.Composition.csproj` | source | net8.0 | 3 | `effe9a99bcd3aa0359e06eefd696c403c87b9cf9ac8b2b3b4b1362daabbf409f` |
| `src/Platform/Authorization/IFX.Platform.Authorization.Contracts/IFX.Platform.Authorization.Contracts.csproj` | source | net8.0 | 0 | `db5f6c13ee05bb9c620cf8a3549ff9bac4d367116fb11c0f3c3a1e8bd5d52ad6` |
| `src/Platform/Authorization/IFX.Platform.Authorization.Infrastructure.Opa/IFX.Platform.Authorization.Infrastructure.Opa.csproj` | source | net8.0 | 2 | `e02903ba0784916a75d8ab9ea0ecf103a6cc48ef494f017b20332c962171fc49` |
| `src/Platform/Authorization/IFX.Platform.Authorization.Runtime/IFX.Platform.Authorization.Runtime.csproj` | source | net8.0 | 1 | `825c991113164cc89f1e32ef424b7a8e1d6516c17eb8764beb6cfb3ff4c0a5eb` |
| `src/Platform/BackgroundJobs/IFX.Platform.BackgroundJobs.Composition/IFX.Platform.BackgroundJobs.Composition.csproj` | source | net8.0 | 3 | `2aa2091eb6f454c9ca1cfe246dc219b1c9c0eccaaa8b164ad11985052d3d60bb` |
| `src/Platform/BackgroundJobs/IFX.Platform.BackgroundJobs.Contracts/IFX.Platform.BackgroundJobs.Contracts.csproj` | source | net8.0 | 0 | `427d1e050e34969c21ed62ae104c9f0d53391d4c9f6f6d67e43ac6cada4d0dca` |
| `src/Platform/BackgroundJobs/IFX.Platform.BackgroundJobs.Infrastructure.Hangfire/IFX.Platform.BackgroundJobs.Infrastructure.Hangfire.csproj` | source | net8.0 | 1 | `075ed54691e2d7c4857fbe9c1398998710119d12a59ee1ff8f338999ff50ab45` |
| `src/Platform/Context/IFX.Platform.Context.Contracts/IFX.Platform.Context.Contracts.csproj` | source | net8.0 | 0 | `427d1e050e34969c21ed62ae104c9f0d53391d4c9f6f6d67e43ac6cada4d0dca` |
| `src/Platform/IFX.Platform.Shared/IFX.Platform.Shared.csproj` | source | net8.0 | 0 | `e151f959964eb450a5b86b72765e3f9c505645fa9516eae485743d2b43911c8e` |
| `src/Platform/Messaging/IFX.Platform.Messaging.Composition/IFX.Platform.Messaging.Composition.csproj` | source | net8.0 | 1 | `d9bc915aa0c4b66e55659fc4f3f72d826b635ab86639ed7ad0e55e266d22a47d` |
| `src/Platform/Messaging/IFX.Platform.Messaging.Contracts/IFX.Platform.Messaging.Contracts.csproj` | source | net8.0 | 0 | `427d1e050e34969c21ed62ae104c9f0d53391d4c9f6f6d67e43ac6cada4d0dca` |
| `src/Platform/Messaging/IFX.Platform.Messaging.Runtime/IFX.Platform.Messaging.Runtime.csproj` | source | net8.0 | 3 | `475d123483613e8beffc0a793a1fe1448d6d9336879302fdb647177160b0dc6a` |
| `src/Platform/Notifications/IFX.Platform.Notifications.Composition/IFX.Platform.Notifications.Composition.csproj` | source | net8.0 | 2 | `e728bb1812a170e6efc0580b5953cdd3c62594188af1859e034ecfb8e10a505a` |
| `src/Platform/Notifications/IFX.Platform.Notifications.Contracts/IFX.Platform.Notifications.Contracts.csproj` | source | net8.0 | 0 | `427d1e050e34969c21ed62ae104c9f0d53391d4c9f6f6d67e43ac6cada4d0dca` |
| `src/Platform/Notifications/IFX.Platform.Notifications.Infrastructure.SendGrid/IFX.Platform.Notifications.Infrastructure.SendGrid.csproj` | source | net8.0 | 2 | `1ce38c4d63bbc64074a7928fd37d9182bea5b8db88bbd9381676231c4b2f560e` |
| `tests/IFX.BuildingBlocks.Application.Tests/IFX.BuildingBlocks.Application.Tests.csproj` | test | net8.0 | 1 | `566b72f7a90d5e9ec78369bcfa95478a0323656599eb8c3176cf9d8317ba042c` |
| `tests/IFX.BuildingBlocks.EntityFrameworkCore.Tests/IFX.BuildingBlocks.EntityFrameworkCore.Tests.csproj` | test | net8.0 | 1 | `743041505ad134bf07fd035ce0b4d31e3b229bb2c4586d389d0a01658fcf7f64` |
| `tests/IFX.DatabaseBoundary.Tests/IFX.DatabaseBoundary.Tests.csproj` | test | net8.0 | 8 | `3e1dae7978a2ed00e58f36e223510badbb8ee332673e91f5cabd96f69ccc374d` |
| `tests/IFX.IntegrationTests/IFX.IntegrationTests.csproj` | test | net8.0 | 8 | `713d829a23f0f480eafbedde4a49d3e533cc040647aa32d9a11621392ebf0a45` |
| `tests/IFX.Modules.CRM.Application.Tests/IFX.Modules.CRM.Application.Tests.csproj` | test | net8.0 | 3 | `d0b593455c85e7f0ab0e85603048e682d66f20a035be87f8a31fa6fe60eb9711` |
| `tests/IFX.Modules.CRM.Domain.Tests/IFX.Modules.CRM.Domain.Tests.csproj` | test | net8.0 | 1 | `bcd9a82ed4bf6a325597999554adf7db30b63a25c31811dca64df5c26d9e1319` |
| `tests/IFX.Modules.Holdings.Application.Tests/IFX.Modules.Holdings.Application.Tests.csproj` | test | net8.0 | 1 | `e471d00cf897652286e172b853f9a7c18b2fe347f8973a97c91f0a3a9d0e3e37` |
| `tests/IFX.Modules.Holdings.Domain.Tests/IFX.Modules.Holdings.Domain.Tests.csproj` | test | net8.0 | 1 | `7377fd3575d045c87790479000fde3ea52d1399880e703e4915bdb1454f0b97b` |
| `tests/IFX.Modules.IAM.Application.Tests/IFX.Modules.IAM.Application.Tests.csproj` | test | net8.0 | 2 | `cf347a238f1a5f4be50e1a0fe4566ec8021cf0ed7d4efe1802a837f5a1fc5635` |
| `tests/IFX.Modules.IAM.Domain.Tests/IFX.Modules.IAM.Domain.Tests.csproj` | test | net8.0 | 2 | `da923b1aad4667c399ce67ee3ef794f2df5b6db8a7bd0570625fda7819c33cf1` |
| `tests/IFX.Modules.IAM.Infrastructure.Tests/IFX.Modules.IAM.Infrastructure.Tests.csproj` | test | net8.0 | 3 | `564f302bb50fdc3f3416b1d7937f028ca2849e13172fdb1af8b4256b16f58251` |
| `tests/IFX.Modules.IAM.Presentation.Tests/IFX.Modules.IAM.Presentation.Tests.csproj` | test | net8.0 | 2 | `d483c819b1dbfbb483a0ce212c0ed71b2d4e6fdce9a971ec8b754fdf70136817` |
| `tests/IFX.Modules.Registry.Application.Tests/IFX.Modules.Registry.Application.Tests.csproj` | test | net8.0 | 3 | `8120bb63524624c5a5790b8171e1aa3058adb70a89e3acf953d743448c5fe7f4` |
| `tests/IFX.Modules.Registry.Domain.Tests/IFX.Modules.Registry.Domain.Tests.csproj` | test | net8.0 | 1 | `70156cbaab0b49d0acd396e7403302f9c32e567b7a0e6df51992e1e9e366a162` |
| `tests/IFX.Modules.Transaction.Application.Tests/IFX.Modules.Transaction.Application.Tests.csproj` | test | net8.0 | 1 | `76dcf2105a328195b34300f5f209d28f440104036fdf9d306adf6c03f9fe3492` |
| `tests/IFX.Modules.Transaction.Domain.Tests/IFX.Modules.Transaction.Domain.Tests.csproj` | test | net8.0 | 1 | `f17fd1ccc52e2caa011093960e7e144d5a0aa02c1b7acc2481c3214df7c391e0` |
| `tests/IFX.Platform.Authentication.Tests/IFX.Platform.Authentication.Tests.csproj` | test | net8.0 | 2 | `6563e339654581182adafb86cf731a491717098661789ebbf9731030454892bc` |
| `tests/IFX.Platform.Authorization.Tests/IFX.Platform.Authorization.Tests.csproj` | test | net8.0 | 2 | `299e9e48e7e5cb4b0427cebc4a688923a34beb6dd769e3874e1d6cd4b2d26061` |
| `tests/IFX.Platform.BackgroundJobs.Tests/IFX.Platform.BackgroundJobs.Tests.csproj` | test | net8.0 | 2 | `bd1dcfe56d9900e0b09a63f0ad1db5d1761ebb49b90bb929dc04148e14f4c6d8` |
| `tests/IFX.Platform.Notifications.Tests/IFX.Platform.Notifications.Tests.csproj` | test | net8.0 | 3 | `195ef1486f7866e9fa3eaed93deab98c14ffb66b1722bb16a97177a1416e59c5` |
| `tests/IFX.Platform.ProtocolContracts.Tests/IFX.Platform.ProtocolContracts.Tests.csproj` | test | net8.0 | 5 | `060dcc391e4d960b7d0c53aeae98afbfd3ebd22bbeb817a95231eed0f370dea7` |
| `tests/IFX.Tests.Common/IFX.Tests.Common.csproj` | test | net8.0 | 2 | `2c3ad240f23002eb8e2507cf4bf82f52fa5e16cc08884a76ee260b509fda0a0c` |
| `tools/IFX.DatabaseInventory/IFX.DatabaseInventory.csproj` | source | net8.0 | 5 | `b724bcc328bcba034530a07ec41fb0357a6747b5796c75ecdcd002341729914e` |

## Manifests

- `IFX.sln` (IFX.sln, SHA-256 `315e199f46d924339492ea4a07dd495ea66b655630c9e6b032a92dea8cb3bf60`)
- `mcp/LayerGuard/LayerGuard.slnx` (LayerGuard.slnx, SHA-256 `f00e5b973bed62eaf8c1b87b37befae3d5c1ae979e307056b4d83e351f8f4adb`)
- `mcp/LayerGuard/tests/fixtures/SolutionScope/SolutionScope.sln` (SolutionScope.sln, SHA-256 `5a7f66cef572db5d3bbc1f3643828c3504d6e5992b661d2adc5241dcdf640ac2`)
- `src/ApiHost/IFX.ApiHost/IFX.ApiHost.sln` (IFX.ApiHost.sln, SHA-256 `0a56236cd32f80c399c5b003852ffa301d8cadf7fdaaa561734bcf238b032b91`)
- `src/Frontend/IFX.FrontEnd/package.json` (package.json, SHA-256 `42095d50bc43d63199367e51524a1cebde3445cb1651f26c09b169364860f53f`)

## CI workflows

- `.github/workflows/coding-guardrails.yml` (SHA-256 `90c49a4e1a180923675a164b73ded77d371a5ae31ad0896e09aac5b477fb6f8c`)
- `.github/workflows/contract-event-governance.yml` (SHA-256 `e45adf009591375df6a3a81b14dac5bce65cab08faa225bed1ff67b22a391582`)
- `.github/workflows/database-migrations.yml` (SHA-256 `01fa77075221501047c42acc8f30d12fcfac7717106903c6297b81fc650b3bff`)
- `.github/workflows/g04-deployment-runtime.yml` (SHA-256 `63948cc571641d7ba7ccbdd08d6f2b8b9eb5d6eded540ab7e545aae3fd6175a5`)
- `.github/workflows/g05-context-boundary.yml` (SHA-256 `e42352f4be364e98296c6ac56462f5221182e28750ca6c8f4349f2d2acead13c`)
- `.github/workflows/layerguard.yml` (SHA-256 `2be88a446f64af86149a28af6471e514feb6d47a034673508c30d835335047fe`)
- `.github/workflows/plan04-governance.yml` (SHA-256 `d4fb0572e3fbf54e614e32de37df405db0213606f6e01cb839806d03c029867b`)

## Agent/owner guidance

- `.github/CODEOWNERS` (SHA-256 `4792156e26256378c17d209dc9e23e4c3406d64ba4c70669a82dc90ffaead720`)
- `CLAUDE.md` (SHA-256 `a7c485a879101d4e60113d6530a0b418c7ead808280b3a2a6e275ac305c9a4c4`)
