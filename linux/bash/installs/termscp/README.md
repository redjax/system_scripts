# TermSCP <!-- omit in toc -->

Terminal UI for (S)FTP, WebDAV, & more. Like a terminal-based FileZilla/Win-SCP.

## Usage

### Connect to a site

```bash
termscp ftp://user@hostname.com:21/path/on/remote -P $FTP_PASSWORD
```

You can also use `sshpass` if it's installed to load your password from a file:

```bash
sshpass -f ~/path/to/ftp_password termscp ftp://user@hostname.com:21/path/on/remote
```

## Links

- [termscp home](https://termscp.veeso.dev)
- [termscp user manual](https://termscp.veeso.dev/user-manual.html)
- [termscp Github](https://github.com/veeso/termscp)
  - [Latest release](https://github.com/veeso/termscp/releases/latest)
