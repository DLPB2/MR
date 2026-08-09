# Makou Reactor

[![CI/CD](https://github.com/myst6re/makoureactor/actions/workflows/build.yml/badge.svg)](https://github.com/myst6re/makoureactor/actions/workflows/build.yml)
[![Coverity Scan Build Status](https://img.shields.io/coverity/scan/8102.svg)](https://scan.coverity.com/projects/myst6re-makoureactor) [![Stable Release](https://img.shields.io/github/downloads/myst6re/makoureactor/total?label=Total%20Downloads)](#)

![Makou Reactor](src/qt/images/logo-shinra.png)

Final Fantasy VII field archive editor ([Forum](http://forums.qhimm.com/index.php?topic=9658.0)).

## Installing

[![Stable Release](https://img.shields.io/github/downloads/myst6re/makoureactor/2.0.0/total?logo=github&label=Download%20Stable%20Release)](https://github.com/myst6re/makoureactor/releases/tag/2.0.0) [![Continious Release](https://img.shields.io/github/downloads/myst6re/makoureactor/continuous/total?logo=github&label=Download%20Continuous%20Release)](https://github.com/myst6re/makoureactor/releases/tag/continuous)

## Contributing

You are welcome to contribute on this project, feel free to open issues and
PR on [GitHub](https://github.com/myst6re/makoureactor).

## Building

Makou Reactor is built and supported as a **64-bit Windows application**.
The supported toolchain is Qt 6 with the MSVC 2022 64-bit kit.

### Requirements

- CMake 3.25+
- Qt 6 with the MSVC 2022 64-bit kit and Qt 5 Compatibility Module
- Visual Studio with the Desktop development with C++ workload
- vcpkg (the repository submodule or a local checkout)

### Qt + Qt Creator

1. Install Qt 6 with `MSVC 2022 64-bit`, `Qt Creator`, and `Qt 5 Compatibility Module`.
2. Install CMake and Ninja from the Qt installer developer tools.
3. Open the repository `CMakeLists.txt` in Qt Creator and use a 64-bit MSVC kit.

### Visual Studio 2022

1. Install Qt as described above.
2. Import `.vsconfig` in the Visual Studio installer.
3. Make sure the English language pack is installed.
4. Open this repository **as a folder** in Visual Studio 2022.
5. Select one of the CMake presets and build. The presets force the `x64-windows` vcpkg target and host triplets.

### Visual Studio Code

1. Install Qt and Visual Studio as described above.
2. Install the Microsoft C/C++ and CMake Tools extensions.
3. Open this repository as a folder.
4. Select a CMake preset such as `Release`.
5. Configure and build.

### GitHub Actions

`.github/workflows/build.yml` builds the Windows x64 GUI package with MSVC, Qt 6, Ninja, CMake, and the `x64-windows` vcpkg triplet.
