# Copilot AI-Credit Usage Report

A Python script for retrieving GitHub Copilot AI-credit usage through the GitHub REST API.

## Requirements

- Python 3.9+
- GitHub token with access to the AI-credit billing usage endpoint

Set the required token:

```bash
export GITHUB_TOKEN="your-token"
```

## Usage

```bash
python report_copilot_usage.py --org my-org
```

Choose one reporting scope:

```bash
--enterprise my-enterprise
--org my-org
--user octocat
```

Optional arguments:

| Argument      | Description                                                |
| ------------- | ---------------------------------------------------------- |
| --year        | Reporting year (defaults to current year)                  |
| --month       | Reporting month (defaults to current month)                |
| --user-filter | Filter enterprise or organization usage by user            |
| --allowance   | Monthly credit allowance for calculating remaining credits |
| --raw         | Print the raw API response as JSON                         |
| --timeout     | HTTP timeout in seconds (default: 30)                      |
| --api-url     | GitHub API base URL                                        |
| --api-version | GitHub API version                                         |

Run `--help` for the full argument list.

## Environment Variables

| Variable           | Description                       |
| ------------------ | --------------------------------- |
| GITHUB_TOKEN       | Required API authentication token |
| GITHUB_ENTERPRISE  | Default enterprise                |
| GITHUB_ORG         | Default organization              |
| GITHUB_USER        | Default user                      |
| GITHUB_API_URL     | API base URL override             |
| GITHUB_API_VERSION | API version override              |

Command-line scope arguments take precedence over environment defaults.

## Output

The summary includes:

- Credits used
- Gross usage value (USD)
- Discounts
- Net usage cost (USD)
- Usage breakdown by model
- Remaining credits and overage, when an allowance is supplied

The script uses Python's standard library and preserves API numeric values using Decimal. Token counts, subscription fees, taxes, and included credit allowances are not provided by the billing endpoint.
