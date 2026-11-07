# cpp-utilities

## profile-catalogue

A [Pkl](https://pkl-lang.org) package that describes C and C++ build profiles
and renders the files CMake and vcpkg need to build them.

A profile is one value on each axis: system, arch, compiler, build type, IPO,
sanitizer, instrumentation, target CPU, C++ and C standard, GNU extensions,
`import std`, reflection, precompiled headers, generator and compiler
launcher. Every axis is a Pkl enum, so a value outside it fails to evaluate.
`catalogue/rules.pkl` refuses combinations that cannot build, such as two
runtime sanitizers together, or reflection on a compiler without it.

From a list of profiles, `catalogue.files` renders:

- **preset shards** under `cmake/presets/`: one hidden configure preset per
  axis value, and one hidden preset per profile that inherits them;
- **a toolchain file**, `ProfileToolchain.cmake`, that picks the compilers and
  sets flags from the profile;
- **vcpkg overlay triplets**, one per profile, that chainload the toolchain
  file with the axes that change a library's ABI;
- **a CMake check module**. `ProfileRules.cmake` runs before `project()` and
  refuses a configure whose profile breaks a rule, whose axis values don't
  spell its name, or whose generator or launcher is ruled out.
  `ProfileCheck.cmake` runs after `project()`. It checks the compiler's ID and
  version, or the clang-p2996 commit, against the preset name. It checks the
  settings and flags, and runs the compiler-flag, linker-flag and IPO checks.
  A refusal or mismatch stops configure, including one made through a user
  override.

### Use

```pkl
// PklProject
dependencies {
  ["profile-catalogue"] { uri = "package://pkg.pkl-lang.org/github.com/ray-manaloto/cpp-utilities/profile-catalogue@0.1.0" }
}
```

```pkl
import "@profile-catalogue/catalogue.pkl"
import "@profile-catalogue/profile.pkl"

local profiles = List(new profile.Profile { system = "linux"; compiler = "gcc16_2_0" })

output {
  files {
    for (path, body in catalogue.files(profiles, new catalogue.Layout {})) {
      [path] { text = body }
    }
  }
}
```

Run it with `pkl eval -m . <file>.pkl`, and include
`cmake/presets/profiles.json` from your `CMakePresets.json`. `fixture/` is a
worked example.

### Develop

[mise](https://mise.jdx.dev) pins the tools. The compilers come from `PATH`;
the check module refuses one whose version doesn't match the profile.

| Task | What it does |
| --- | --- |
| `mise run test` | `pkl test`: facts on the axes and rules, and golden examples of every rendered file |
| `mise run fixture:generate` | regenerates the fixture's generated files |
| `mise run fixture:fresh` | fails if the committed generated files are stale |
| `mise run fixture:schema` | validates the generated presets against CMake's presets schema |
| `mise run fixture:build` | configures, builds and tests each fixture preset this machine can run |
| `mise run fixture:refusals` | checks that configure refuses ruled overrides (macOS) |
| `mise run check` | all of the above |
