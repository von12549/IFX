using LayerGuard;
using LayerGuard.Ifx;

// The IFX host is the engine command line with the IFX policy binding registered (Plan 06 P6.3, D27).
IfxArchitectureConformance.Register();
return Cli.Run(args);
