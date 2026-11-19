"""Report Copilot AI-credit usage using only Python's standard library.

Description:
    Retrieves monthly GitHub Copilot AI-credit usage for an enterprise,
    organization, or user through the GitHub REST API.

    Reports total credits consumed, gross USD usage value, discounts,
    net USD cost, and a breakdown of usage by model. Optionally accepts
    a monthly credit allowance to calculate remaining credits and usage
    above the allowance.

    Supports raw JSON output for inspecting the underlying API response.
    Reporting defaults to the current UTC month but can be configured
    for a specific year and month.

    Note: This tool reports credit quantities, not token counts. It does
    not retrieve the included credit allowance, subscription fees, or
    taxes. Any allowance comparison uses the caller-supplied value and
    assumes it applies to the same reporting scope and monthly credit pool.

Args:
    `--enterprise`: Enterprise slug to report usage for.

    `--org`, `--organization`: Organization name or slug to report usage for.

    `--user`: GitHub username to report usage for.

    `--user-filter`: Filter enterprise or organization usage to a specific GitHub user.
        Only valid with --enterprise or --org.

    `--year`: Reporting year in UTC. Defaults to the current year.

    `--month`: Reporting month (1-12). Defaults to the current month.

    `--timeout`: HTTP request timeout in seconds. Defaults to 30.

    `--raw`: Print the complete API response as JSON instead of a usage summary.

    `--allowance`: Optional monthly credit allowance for the selected reporting scope.
        Used to calculate remaining credits and usage above the allowance.

    `--api-url`: GitHub API base URL. Defaults to GITHUB_API_URL or https://api.github.com.

    `--api-version`: GitHub API version. Defaults to GITHUB_API_VERSION or 2026-03-10.

Environment Variables:
    GITHUB_TOKEN: (Required) GitHub authentication token with permission to access
    the selected AI-credit billing usage endpoint.

    GITHUB_ENTERPRISE: Default enterprise slug when --enterprise is not provided.

    GITHUB_ORG: Default organization when --org is not provided.

    GITHUB_USER: Default GitHub username when --user is not provided.

    GITHUB_API_URL: (Optional) GitHub API base URL override.

    GITHUB_API_VERSION: (Optional) GitHub API version override.

Examples:
    python report_copilot_usage.py --org my-org

    python report_copilot_usage.py --enterprise my-enterprise --year 2026 --month 3

    python report_copilot_usage.py --org my-org --user-filter octocat

    python report_copilot_usage.py --user octocat --allowance 1000

    python report_copilot_usage.py --org my-org --raw

    GITHUB_TOKEN=ghp_xxx python report_copilot_usage.py --org my-org

"""
from __future__ import annotations

import argparse
from collections import defaultdict
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
import json
import os
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode, urlsplit
from urllib.request import Request, urlopen

class ReportError(Exception):
    pass


def nonnegative_decimal(text):
    try:
        value = Decimal(text)
    except InvalidOperation:
        raise argparse.ArgumentTypeError("must be a decimal number")
    if not value.is_finite() or value < 0:
        raise argparse.ArgumentTypeError("must be finite and nonnegative")
    return value


def arguments():
    now = datetime.now(timezone.utc)
    parser = argparse.ArgumentParser(description=__doc__)

    targets = parser.add_mutually_exclusive_group()
    targets.add_argument("--enterprise")
    targets.add_argument("--org", "--organization", dest="organization")
    targets.add_argument("--user")

    parser.add_argument("--user-filter")
    parser.add_argument("--year", type=int, default=now.year)
    parser.add_argument("--month", type=int, default=now.month)
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--raw", action="store_true",
                        help="Print the API response instead of a summary.")
    parser.add_argument(
        "--allowance",
        type=nonnegative_decimal,
        help="Known monthly credit allowance for exactly this report scope."
    )
    parser.add_argument(
        "--api-url",
        default=os.getenv("GITHUB_API_URL", "https://api.github.com")
    )
    parser.add_argument(
        "--api-version",
        default=os.getenv("GITHUB_API_VERSION", "2026-03-10")
    )
    args = parser.parse_args()

    targets = [
        ("enterprise", args.enterprise),
        ("organization", args.organization),
        ("user", args.user),
    ]
    if not any(value for _, value in targets):
        targets = [
            ("enterprise", os.getenv("GITHUB_ENTERPRISE")),
            ("organization", os.getenv("GITHUB_ORG")),
            ("user", os.getenv("GITHUB_USER")),
        ]

    selected = [(scope, value) for scope, value in targets if value]
    if len(selected) != 1:
        parser.error("choose exactly one enterprise, organization, or user")

    args.scope, args.target = selected[0]

    if args.scope == "user" and args.user_filter:
        parser.error("--user-filter requires --org or --enterprise")
    if not 1 <= args.year <= 9998 or not 1 <= args.month <= 12:
        parser.error("use a year from 1 to 9998 and a month from 1 to 12")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")

    args.api_url = args.api_url.rstrip("/")
    parsed = urlsplit(args.api_url)
    if (parsed.scheme != "https" or not parsed.netloc
            or parsed.username or parsed.password
            or parsed.query or parsed.fragment):
        parser.error("--api-url must be an HTTPS base URL without credentials")

    if not os.getenv("GITHUB_TOKEN"):
        parser.error("GITHUB_TOKEN is required")

    return args


def fetch_usage(args):
    prefixes = {
        "enterprise": "enterprises",
        "organization": "organizations",
        "user": "users",
    }
    path = (
        f"/{prefixes[args.scope]}/{quote(args.target, safe='')}"
        "/settings/billing/ai_credit/usage"
    )
    query = {"year": args.year, "month": args.month}
    if args.user_filter:
        query["user"] = args.user_filter

    url = f"{args.api_url}{path}?{urlencode(query)}"
    token = os.environ["GITHUB_TOKEN"]
    request = Request(url, headers={
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {token}",
        "X-GitHub-Api-Version": args.api_version,
        "User-Agent": "copilot-usage-on-demand",
    })

    try:
        with urlopen(request, timeout=args.timeout) as response:
            # Keep JSON numeric values exact, including for --raw output.
            return json.loads(
                response.read(), parse_float=Decimal, parse_int=Decimal
            )
    except HTTPError as error:
        message = error.read().decode("utf-8", errors="replace")
        try:
            message = json.loads(message).get("message", message)
        except (ValueError, AttributeError):
            pass
        message = str(message).replace(token, "[REDACTED]")
        raise ReportError(f"HTTP {error.code}: {message}") from error
    except (URLError, TimeoutError, OSError) as error:
        raise ReportError(f"Request failed: {error}") from error
    except (ValueError, UnicodeError) as error:
        raise ReportError("API returned invalid JSON") from error


def number(item, field):
    value = item.get(field)
    if not isinstance(value, Decimal) or not value.is_finite():
        raise ReportError(f"Missing or invalid numeric field: {field}")
    return value


def raw_json(value):
    # Decimal values become strings to preserve their exact representation.
    return json.dumps(value, indent=2, default=str)


def summarize(args, data):
    if not isinstance(data, dict) or not isinstance(data.get("usageItems"), list):
        raise ReportError("Expected an object containing a usageItems list")

    # Group by unit as well as model: never silently sum unlike quantities.
    groups = defaultdict(lambda: [Decimal(0) for _ in range(4)])
    for item in data["usageItems"]:
        if not isinstance(item, dict):
            raise ReportError("Unexpected usage item")
        unit = item.get("unitType")
        if unit not in ("credits", "ai-credits"):
            raise ReportError(f"Unexpected usage unit: {unit!r}; inspect --raw")

        model = item.get("model") or "(unspecified)"
        values = [
            number(item, field)
            for field in (
                "grossQuantity", "grossAmount", "discountAmount", "netAmount"
            )
        ]
        group = groups[(model, unit)]
        for index, value in enumerate(values):
            group[index] += value

    totals = [
        sum((values[i] for values in groups.values()), Decimal(0))
        for i in range(4)
    ]
    used, gross, discount, net = totals

    start = datetime(args.year, args.month, 1, tzinfo=timezone.utc)
    end = datetime(
        args.year + (args.month == 12),
        1 if args.month == 12 else args.month + 1,
        1,
        tzinfo=timezone.utc,
    )

    subject = f"{args.scope}: {args.target}"
    if args.user_filter:
        subject += f" / user: {args.user_filter}"

    print(f"Copilot AI-credit usage — {subject}")
    print(f"Requested period: {start:%Y-%m-%d} to {end:%Y-%m-%d} UTC (end exclusive)")
    print(f"API timePeriod: {raw_json(data.get('timePeriod', {}))}")
    print(f"Included-credit reset boundary: {end:%Y-%m-%d %H:%M UTC}")
    print(f"Credits used (gross): {used:f}")
    print(f"Gross usage value:    ${gross:,.2f} USD")
    print(f"Reported discounts:  ${discount:,.2f} USD")
    print(f"Net usage cost:      ${net:,.2f} USD")
    print("Subscription fees/taxes: not included in this usage summary")
    print("Token counts: not provided by this billing endpoint")

    if args.allowance is None:
        print("Included allowance / remaining: not returned by this endpoint")
    else:
        remaining = max(Decimal(0), args.allowance - used)
        over = max(Decimal(0), used - args.allowance)
        print(f"User-supplied allowance: {args.allowance:f} credits")
        print(f"Calculated remaining:   {remaining:f} credits")
        print(f"Usage above allowance:  {over:f} credits")
        print("Allowance comparison assumes the same scope and monthly pool.")

    if not groups:
        print("\nNo usage items returned; this does not establish your entitlement.")
        return

    print("\nBy model:")
    print(f"{'Model':32} {'Credits':>14} {'Gross USD':>12} {'Net USD':>12}")
    for (model, unit), values in sorted(groups.items()):
        quantity, gross_value, _, net_value = values
        print(
            f"{model:32} {quantity:14,.4f}"
            f" {gross_value:12,.2f} {net_value:12,.2f}"
        )


def main():
    args = arguments()
    try:
        data = fetch_usage(args)
        if args.raw:
            print(raw_json(data))
        else:
            summarize(args, data)
    except ReportError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

