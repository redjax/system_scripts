# Linting & Formatting

This repository enforces linting & formatting rules for Bash, Powershell, and Python scripts.

## Bash

### Linting with shellcheck

#### Overriding Rules

Override rules with a comment above the violation. For example, `SC2016` warns about variables in single quotes. Sometimes you want to do this, like when you want to echo a literal string with `$VAR_NAME`, instead of the value of `$VAR_NAME`.

```shell
# shellcheck disable=SC2016
echo '"$HOME"'
```
