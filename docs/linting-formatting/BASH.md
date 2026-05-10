# Bash Linting & Formatting

Bash files are linted with `shellcheck` and formatted with `shfmt`.

## Overriding Shellcheck Rules

Override rules with a comment above the violation. For example, `SC2016` warns about variables in single quotes. Sometimes you want to do this, like when you want to echo a literal string with `$VAR_NAME`, instead of the value of `$VAR_NAME`.

```shell
# shellcheck disable=SC2016
echo '"$HOME"'
```