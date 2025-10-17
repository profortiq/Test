# Profortiq Netstat

This folder contains a lightweight reproduction of the Profortiq Netstat WPF application that can be used to verify package restore on clean systems.

## Build

```bash
dotnet build Profortiq.Netstat/Profortiq.Netstat.App/Profortiq.Netstat.App.csproj
```

> **Note**
> Building WPF projects on non-Windows hosts requires the .NET SDK 7.0 or newer and the `EnableWindowsTargeting` property that is already included in the project file.
