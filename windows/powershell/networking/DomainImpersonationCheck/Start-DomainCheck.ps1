[CmdletBinding()]
Param(
  [Parameter(
    Mandatory = $false,
    HelpMessage = "Path to a text file containing one monitoring term per line."
  )]
  [ValidateScript({
      if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) {
        throw "Monitoring terms file does not exist or is not a file: $_"
      }

      $true
    })]
  [string]$MonitoringTermsFile = $env:DOMAINCHECK_MONITORING_TERMS_FILE,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Path to a text file containing one TLD per line."
  )]
  [ValidateScript({
      if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) {
        throw "TLD file does not exist or is not a file: $_"
      }

      $true
    })]
  [string]$TLDsFile = $env:DOMAINCHECK_TLDS_FILE,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Maximum number of candidate domains to generate."
  )]
  [ValidateRange(1, 1000000)]
  [int]$MaxCandidates = $(if ([string]::IsNullOrWhiteSpace($env:DOMAINCHECK_MAX_CANDIDATES)) {
      10000
    }
    else {
      $env:DOMAINCHECK_MAX_CANDIDATES
    }),

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Optional DNS resolver IP address or hostname to query."
  )]
  [string]$DnsServer = $env:DOMAINCHECK_DNS_SERVER,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Write CSV results to this directory."
  )]
  [string]$OutputDir = $(if ([string]::IsNullOrWhiteSpace($env:DOMAINCHECK_OUTPUT_DIR)) {
      "./output"
    }
    else {
      $env:DOMAINCHECK_OUTPUT_DIR
    })
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#############
# Functions #
#############

function ConvertTo-ValidDnsName {
  <#
  .SYNOPSIS
      Normalizes a DNS hostname to lowercase ASCII/Punycode.

  .DESCRIPTION
      Accepts a valid DNS hostname or internationalized domain name,
      returning normalized ASCII/Punycode form. Returns $null for
      malformed names, URLs, paths, addresses, ports, or oversized labels.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [AllowEmptyString()]
    [string]$InputValue
  )

  $name = $InputValue.Trim()

  ## Normalize Unicode dot-equivalent characters.
  $name = $name `
    -replace [char]0x3002, '.' `
    -replace [char]0xFF0E, '.' `
    -replace [char]0xFF61, '.'

  ## Normalize a fully qualified DNS name to its non-root-dot form.
  $name = $name.TrimEnd('.')

  if ([string]::IsNullOrWhiteSpace($name)) {
    return $null
  }

  ## Ensure extracted text is a DNS name, not a URL, path, email address, or host:port.
  if ($name -match '[:/\\@\s]') {
    return $null
  }

  ## Reject empty labels before calling the IDN converter.
  if ($name.StartsWith('.') -or $name.Contains('..')) {
    return $null
  }

  try {
    $idn = [System.Globalization.IdnMapping]::new()
    $asciiName = $idn.GetAscii($name).ToLowerInvariant()
  }
  catch {
    return $null
  }

  if ($asciiName.Length -gt 253) {
    return $null
  }

  foreach ($label in $asciiName.Split('.')) {
    if ([string]::IsNullOrWhiteSpace($label)) {
      return $null
    }

    if ($label.Length -gt 63) {
      return $null
    }

    if ($label.StartsWith('-') -or $label.EndsWith('-')) {
      return $null
    }

    if ($label -notmatch '^[a-z0-9-]+$') {
      return $null
    }
  }

  return $asciiName
}

function ConvertTo-ValidDnsSuffix {
  <#
  .SYNOPSIS
      Normalizes a TLD or multi-label DNS suffix.

  .DESCRIPTION
      Accepts values such as "com", ".com", "co.uk", and "рф".
      Returns lowercase ASCII/Punycode form without a leading period.
      Returns $null for invalid values.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [AllowEmptyString()]
    [string]$InputValue
  )

  $suffix = $InputValue.Trim()

  if ([string]::IsNullOrWhiteSpace($suffix)) {
    return $null
  }

  ## Allow exactly one optional leading period:
  #  ".com" becomes "com".
  if ($suffix.StartsWith('.')) {
    $suffix = $suffix.Substring(1)
  }

  ## Reject a second leading dot, a trailing dot, empty labels,
  #  URLs, paths, email addresses, host:port syntax, and whitespace.
  if ([string]::IsNullOrWhiteSpace($suffix) -or
    $suffix.StartsWith('.') -or
    $suffix.EndsWith('.') -or
    $suffix.Contains('..') -or
    $suffix -match '[:/\\@\s]') {
    return $null
  }

  ## Reuse the full DNS-name normalizer. This handles:
  #  - lowercasing
  #  - Unicode dot normalization
  #  - IDN/Punycode conversion
  #  - 63-character label limits
  #  - 253-character full-name limit
  #  - valid ASCII DNS label checks
  return ConvertTo-ValidDnsName -InputValue $suffix
}

function Get-MonitoringTerms {
  <# Load monitoring terms from a file, normalize, & return as array. #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Path
  )

  ## Read terms from a file
  $terms = foreach ($line in Get-Content -LiteralPath $Path) {
    $rawValue = $line.Trim()

    if ([string]::IsNullOrWhiteSpace($rawValue)) {
      continue
    }

    if ($rawValue.StartsWith('#') -or $rawValue.StartsWith(';')) {
      continue
    }

    $term = ConvertTo-ValidDnsName -InputValue $rawValue

    if ($null -eq $term) {
      Write-Warning "Skipping invalid domain input: '$line'"
      continue
    }

    $term
  }

  return @($terms | Sort-Object -Unique)
}

function Get-TLDs {
  <#
  .SYNOPSIS
      Loads TLDs or DNS suffixes from a text file.

  .DESCRIPTION
      Reads one suffix per line, ignores blank/comment lines, normalizes
      valid values into ASCII/Punycode, and returns unique sorted values.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Path
  )

  $tlds = foreach ($line in Get-Content -LiteralPath $Path) {
    $rawValue = $line.Trim()

    if ([string]::IsNullOrWhiteSpace($rawValue)) {
      continue
    }

    if ($rawValue.StartsWith('#') -or $rawValue.StartsWith(';')) {
      continue
    }

    $tld = ConvertTo-ValidDnsSuffix -InputValue $rawValue

    if ($null -eq $tld) {
      Write-Warning "Skipping invalid TLD entry: '$line'"
      continue
    }

    $tld
  }

  return @($tlds | Sort-Object -Unique)
}

function Get-DomainCandidates {
  <#
  .SYNOPSIS
      Builds domain candidates from terms, adjacent transpositions, and suffixes.

  .DESCRIPTION
      For each monitoring term, includes the original term and all unique
      adjacent-character transposition variants. Every value is then combined
      with every supplied TLD/suffix.

      A hard candidate limit prevents unexpectedly large output and DNS query
      volume in later stages.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string[]]$MonitoringTerms,

    [Parameter(Mandatory)]
    [string[]]$TLDs,

    [Parameter()]
    [ValidateRange(1, 1000000)]
    [int]$MaxCandidates = 10000
  )

  $candidateSet = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
  )

  foreach ($term in $MonitoringTerms) {
    ## A set prevents duplicate variants caused by repeated characters or
    #  overlap between an input term and a generated transposition.
    $termVariants = [System.Collections.Generic.HashSet[string]]::new(
      [System.StringComparer]::OrdinalIgnoreCase
    )

    ## Always retain the original term.
    [void]$termVariants.Add($term)

    ## Always add adjacent-character transposition variants.
    foreach ($variant in Get-AdjacentCharacterTranspositions -InputValue $term) {
      [void]$termVariants.Add($variant)
    }

    Write-Verbose "Term '$term' produced $($termVariants.Count) total variant(s), including the original."

    foreach ($termVariant in $termVariants) {
      foreach ($tld in $TLDs) {
        $rawCandidate = "$termVariant.$tld"

        ## Validate after composition, including total hostname length.
        $candidate = ConvertTo-ValidDnsName -InputValue $rawCandidate

        if ($null -eq $candidate) {
          Write-Warning "Skipping invalid combined candidate: '$rawCandidate'"
          continue
        }

        [void]$candidateSet.Add($candidate)

        ## Fail immediately rather than silently truncate the candidate list.
        #  This makes it obvious that the configured safety limit was exceeded.
        if ($candidateSet.Count -gt $MaxCandidates) {
          throw @"
Candidate count exceeded the configured maximum of $MaxCandidates.

Monitoring terms loaded: $($MonitoringTerms.Count)
TLD/suffix values loaded: $($TLDs.Count)
Candidate-generation methods: original term + adjacent transposition

Reduce the source lists, increase -MaxCandidates after review, or adjust
candidate-generation logic.
"@
        }
      }
    }
  }

  return @($candidateSet | Sort-Object)
}

function Get-AdjacentCharacterTranspositions {
  <#
  .SYNOPSIS
      Returns variants created by swapping one adjacent character pair.

  .DESCRIPTION
      Produces one variant for every unique swap of two neighboring
      characters. The original value is not returned.

      Example:
          Input:  company
          Output: ocmpany, cmopany, comapny, compnay, compayn
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [AllowEmptyString()]
    [string]$InputValue
  )

  if ([string]::IsNullOrWhiteSpace($InputValue)) {
    return @()
  }

  if ($InputValue.Length -lt 2) {
    return @()
  }

  ## Do not transpose dots in multi-label inputs. A period represents DNS
  #  structure, not a character inside the brand label.
  if ($InputValue.Contains('.')) {
    Write-Verbose "Skipping transpositions for multi-label input: $InputValue"
    return @()
  }

  $variants = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
  )

  for ($index = 0; $index -lt ($InputValue.Length - 1); $index++) {
    ## A swap such as "tt" -> "tt" does not make a new variant.
    if ($InputValue[$index] -eq $InputValue[$index + 1]) {
      continue
    }

    $characters = $InputValue.ToCharArray()

    $temporaryCharacter = $characters[$index]
    $characters[$index] = $characters[$index + 1]
    $characters[$index + 1] = $temporaryCharacter

    $variant = -join $characters

    if ($variant -ne $InputValue) {
      [void]$variants.Add($variant)
    }
  }

  return @($variants | Sort-Object)
}

function Get-DomainARecordResult {
  <#
  .SYNOPSIS
      Queries a candidate domain for IPv4 A records.

  .DESCRIPTION
      Returns one structured result per candidate domain. DNS failures do not
      stop the monitoring run; they return a result with Resolved = $false.

      This intentionally checks only A records in the first DNS stage.
      Later, add AAAA, CNAME, MX, NS, and TXT enrichment separately.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Domain,

    [Parameter()]
    [AllowEmptyString()]
    [string]$DnsServer
  )

  $queryParameters = @{
    Name         = $Domain
    Type         = 'A'
    DnsOnly      = $true
    QuickTimeout = $true
    ErrorAction  = 'Stop'
  }

  if (-not [string]::IsNullOrWhiteSpace($DnsServer)) {
    $queryParameters['Server'] = $DnsServer
  }

  try {
    $records = @(
      Resolve-DnsName @queryParameters |
      Where-Object {
        $_.Type -eq 'A' -and
        -not [string]::IsNullOrWhiteSpace($_.IPAddress)
      }
    )

    $ipAddresses = @(
      $records |
      Select-Object -ExpandProperty IPAddress -Unique |
      Sort-Object
    )

    if ($ipAddresses.Count -eq 0) {
      return [PSCustomObject]@{
        Domain        = $Domain
        Resolved      = $false
        IPv4Addresses = ''
        QueryStatus   = 'NoARecord'
        ErrorMessage  = ''
        CheckedUtc    = (Get-Date).ToUniversalTime().ToString('o')
      }
    }

    return [PSCustomObject]@{
      Domain        = $Domain
      Resolved      = $true
      IPv4Addresses = ($ipAddresses -join ';')
      QueryStatus   = 'Resolved'
      ErrorMessage  = ''
      CheckedUtc    = (Get-Date).ToUniversalTime().ToString('o')
    }
  }
  catch {
    return [PSCustomObject]@{
      Domain        = $Domain
      Resolved      = $false
      IPv4Addresses = ''
      QueryStatus   = 'DnsError'
      ErrorMessage  = $_.Exception.Message
      CheckedUtc    = (Get-Date).ToUniversalTime().ToString('o')
    }
  }
}

function Initialize-OutputDirectory {
  <# Ensure output directory exists & return the full path to it. #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }

  $resolvedPath = Resolve-Path -LiteralPath $Path

  if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
    throw "Output path is not a directory: $Path"
  }

  return $resolvedPath.Path
}

########
# Main #
########

## Validate inputs

if ([string]::IsNullOrWhiteSpace($MonitoringTermsFile)) {
  throw @"
No monitoring terms file was provided.

Specify -MonitoringTermsFile or set the DOMAINCHECK_MONITORING_TERMS_FILE
environment variable.
"@
}

if ([string]::IsNullOrWhiteSpace($TLDsFile)) {
  throw @"
No TLD file was provided.

Specify -TLDsFile or set the DOMAINCHECK_TLDS_FILE environment variable.
"@
}

## Ensure file paths

if (-not (Test-Path -LiteralPath $MonitoringTermsFile -PathType Leaf)) {
  throw "Monitoring terms file does not exist or is not a file: $MonitoringTermsFile"
}

if (-not (Test-Path -LiteralPath $TLDsFile -PathType Leaf)) {
  throw "TLD file does not exist or is not a file: $TLDsFile"
}

## Load monitoring terms & TLDs
$MonitoringTerms = Get-MonitoringTerms -Path $MonitoringTermsFile
$TLDs = Get-TLDs -Path $TLDsFile

if ($MonitoringTerms.Count -eq 0) {
  throw "No valid monitoring terms were found in '$MonitoringTermsFile'."
}

if ($TLDs.Count -eq 0) {
  throw "No valid TLDs were found in '$TLDsFile'."
}

Write-Verbose "Loaded $($MonitoringTerms.Count) monitoring term(s)."
Write-Verbose "Loaded $($TLDs.Count) TLD/suffix value(s)."

## Get list of monitoring term + TLD permutations to test
$CandidateDomains = Get-DomainCandidates `
  -MonitoringTerms $MonitoringTerms `
  -TLDs $TLDs `
  -MaxCandidates $MaxCandidates

Write-Verbose "Generated $($CandidateDomains.Count) unique candidate domain(s)."

$ResolvedOutputDir = Initialize-OutputDirectory -Path $OutputDir
$RunTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$DnsResultsCsv = Join-Path -Path $ResolvedOutputDir -ChildPath "DnsResults-$RunTimestamp.csv"
  
Write-Host "Querying DNS for $($CandidateDomains.Count) candidate domain(s)..."

## Test each domain's DNS A record
$DnsResults = foreach ($candidateDomain in $CandidateDomains) {
  Get-DomainARecordResult `
    -Domain $candidateDomain `
    -DnsServer $DnsServer
}
  
$DnsResults = @($DnsResults | Sort-Object Domain)
  
$DnsResults |
Export-Csv `
  -LiteralPath $DnsResultsCsv `
  -NoTypeInformation `
  -Encoding utf8
  
$ResolvedDomains = @(
  $DnsResults |
  Where-Object { $_.Resolved }
)

Write-Host "DNS checks completed."
Write-Host "Candidates checked: $($DnsResults.Count)"
Write-Host "Candidates with IPv4 A records: $($ResolvedDomains.Count)"
Write-Host "Results written to: $DnsResultsCsv"

## Temporary console output while developing.
$ResolvedDomains
