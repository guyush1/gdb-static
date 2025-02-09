<h1 align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="./.github/assets/gdb-static_logo_dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="./.github/assets/gdb-static_logo_light.svg">
    <img src="./.github/assets/gdb-static_logo_light.svg" alt="gdb-static" width="210px">
  </picture>
</h1>

<p align="center">
  <i align="center">Frozen static builds of everyone's favorite debugger!🧊</i>
</p>

<h4 align="center">
  <a href="https://github.com/guyush1/gdb-static/releases/latest">
    <img src="https://img.shields.io/github/v/release/guyush1/gdb-static?style=flat-square" alt="release" style="height: 20px;">
  <a href="https://github.com/guyush1/gdb-static/actions/workflows/pr-pipeline.yaml">
    <img src="https://img.shields.io/github/actions/workflow/status/guyush1/gdb-static/pr-pipeline.yaml?style=flat-square&label=pipeline" alt="continuous integration" style="height: 20px;">
  </a>
  <a href="https://github.com/guyush1/gdb-static/graphs/contributors">
    <img src="https://img.shields.io/github/contributors-anon/guyush1/gdb-static?color=yellow&style=flat-square" alt="contributors" style="height: 20px;">
  </a>
  <br>
  <img src="https://img.shields.io/badge/GDB-v16.2-orange?logo=gnu&logoColor=white&style=flat-square" alt="gdb" style="height: 20px;">
  <img src="https://img.shields.io/badge/Python-built--in-blue?logo=python&logoColor=white&style=flat-square" alt="python" style="height: 20px;">
</h4>

## TL;DR

- **Download**: Get the latest release from the [releases page](https://github.com/guyush1/gdb-static/releases/latest).

## Introduction

Who doesn't love GDB? It's such a powerful tool, with such a great package.  
But sometimes, you run into one of these problems:
- You can't install GDB on your machine
- You can't install an updated version of GDB on your machine
- Some other strange embedded reasons...

This is where `gdb-static` comes in! We provide static builds of `gdb` (and `gdbserver` of course), so you can run them on any machine, without any dependencies!

<details open>
<summary>
 Features
</summary> <br />

- **Static Builds**: No dependencies, no installation, just download and run!
- **Latest Versions**: We keep our builds up-to-date with the latest versions of GDB.
- **Builtin Python (Optional)**: We provide builds with Python support built-in.
- **XML Support**: Our builds come with XML support built-in, which is useful for some GDB commands.
- **Wide Architecture Support**: We support a wide range of architectures:
  - aarch64
  - arm
  - mips
  - mipsel
  - powerpc
  - x86_64

</details>

## Usage 

To get started with `gdb-static`, simply download the build for your architecture from the [releases page](https://github.com/guyush1/gdb-static/releases/latest), extract the archive, and copy the binary to your desired platform.

> [!NOTE]
> We provide two types of builds:
> 1. Builds with Python support, which are approximately ~30 MB in size.
> 2. Slimmer builds without Python support, which are approximately ~7 MB in size.

You may choose to copy the `gdb` binary to the platform, or use `gdbserver` to debug remotely.

## Development

> [!NOTE]
> Before building, make sure to initialize & sync the git submodules.

Alternatively, you can build `gdb-static` from source. To do so, follow the instructions below:

<details open>
<summary>
Pre-requisites
</summary> <br />
To be able to build `gdb-static`, you will need the following tools installed on your machine:

###

- Docker
- Docker buildx
- Git
</details>

<details open>
<summary>
Building for a specific architecture
</summary> <br />

To build `gdb-static` for a specific architecture, run the following command:

```bash
make build[-with-python]-<ARCH>
```

Where `<ARCH>` is the architecture you want to build for, and `-with-python` may be added in order to compile gdb with Python support.

The resulting binary will be placed in the `build/artifacts/` directory:

```bash
build/
└── artifacts/
    └── <ARCH>/
        └── ...
```

</details>

<details open>
<summary>
Building for all architectures
</summary> <br />

To build `gdb-static` for all supported architectures, run the following command:

```bash
make build
```

The resulting binary will be placed in the `build/artifacts/` directory.

</details>

<a name="contributing_anchor"></a>
## Contributing

- Bug Report: If you see an error message or encounter an issue while using gdb-static, please create a [bug report](https://github.com/guyush1/gdb-static/issues/new?assignees=&labels=bug&title=%F0%9F%90%9B+Bug+Report%3A+).

- Feature Request: If you have an idea or if there is a capability that is missing and would make `gdb-static` more robust, please submit a [feature request](https://github.com/guyush1/gdb-static/issues/new?assignees=&labels=enhancement&title=%F0%9F%9A%80+Feature+Request%3A+).

## Contributors

<!---
npx contributor-faces --exclude "*bot*" --limit 70 --repo "https://github.com/guyush1/gdb-static"

change the height and width for each of the contributors from 80 to 50.
--->

[//]: contributor-faces
<a href="https://github.com/guyush1"><img src="https://avatars.githubusercontent.com/u/82650790?v=4" title="guyush1" width="80" height="80"></a>
<a href="https://github.com/RoiKlevansky"><img src="https://avatars.githubusercontent.com/u/78471889?v=4" title="RoiKlevansky" width="80" height="80"></a>
<a href="https://github.com/roddyrap"><img src="https://avatars.githubusercontent.com/u/37045659?v=4" title="roddyrap" width="80" height="80"></a>

[//]: contributor-faces
