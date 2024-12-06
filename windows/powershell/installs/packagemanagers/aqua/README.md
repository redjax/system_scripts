# Aqua Package Manager

[aqua](aquaproj.github.io/) is a cross-platform  "version manager" more than a package manager, although it can be used to install a number of packages. Version managers focus more on managing multiple versions of an application, allowing for per-project version management of things like coding languages or development tools.

`aqua` is configured with an `aqua.yaml` file (created with `aqua init`), and has a visual installer/selector, but no options for installing from the command line...you must use the `aqua.yaml` config.

Setting up `aqua` can be a bit more involved than other package managers if you don't want to use the default locations for `aqua` paths. That being said, it is well suited for cross-platform development and CI pipelines.

Compare to tools like [`asdf`](https://asdf-vm.com), [`proto`](https://moonrepo.dev/docs/proto), [`mise`](https://mise.jdx.dev), and [`version-manager (vmr)`](https://vdocs.vmr.us.kg).
