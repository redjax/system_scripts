# Domain Monitor <!-- omit in toc -->

Script to monitor domain names for new registrations. Script loads a list of terms and TLDs, creates permutations of each term and TLD, and tests the DNS lookup for each combination.

## Table of Contents <!-- omit in toc -->

- Setup
- Usage

## Setup

- Create a file with terms to monitor.
  - These are not FQDNs or IP addresses; they are words and phrases associated with the business that we want to monitor to avoid impersonation.
  - You can use the provided `ingest/monitorTerms.txt` file
- Create a file with TLDs to monitor.
  - e.g. `com`, `net`, `org`, etc.
  - You can use the provided `ingest/tlds.txt` file

## Usage

- Run `Get-Help ./Start-DomainCheck.ps1 -Full` to see the script's help menu.
- Run the `Start-DomainCheck.ps1` script with the files you created.
  - Provide the monitoring terms file with `-MonitoringTermsFile <path/to/monitoringTerms.txt>`.
  - Provide the TLDs file with `-TLDsFile <path/to/tlds.txt>`.
- Most params have a corresponding environment variable you can use instead of a script arg.
  - For example, you can set `$env:DOMAINCHECK_MONITORING_TERMS_FILE = "path/to/monitorTerms.txt"` instead of passing `-MonitoringTermsFile`.
  - See the example `env.ps1` file for available environment variables.
  - For local development, you can copy `example.env.ps1` to a new `env.ps1` file and source it to provide variables:
    - `./env.ps1 ; ./Start-DomainCheck.ps1`.

Each time the script runs, it ouputs a CSV file to the provided `-OutputDir <path/to/output>` directory with the results of the scan.

If the script is not querying domains as expected, you can run the `Resolve-DnsName` command (built into Powershell) manually to see the results:

```powershell
Resolve-DnsName `
  -Name "example.com" `
  -Type A `
  -DnsOnly `
  -ErrorAction Stop
```

If `Resolve-DnsName` is not available in your environment, try a simple `dig` request:

```shell
dig example.com A +noall +comments +answer +authority
```

If your machine uses a company's internal resolvers, i.e. `10.10.0.5`, give `dig` a DNS server to use for the test (note: this type of request may not be possible, depending on the company's DNS configuration):

```shell
dig '@1.1.1.1' example.com A +noall +comments +answer +authority
```
