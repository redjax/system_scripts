<#
    Datadog documentation, Submitting metrics with PowerShell with the API:
        https://docs.datadoghq.com/metrics/custom_metrics/powershell_metrics_submission/#submitting-metrics-with-powershell-with-the-api
#>

Param(
    [Switch]$Debug,
    [String]$ApiKey = "$($env:DATADOG_API_KEY)",
    [String]$AppKey = "$($env:DATADOG_APP_KEY)",
    [String]$DataSource = $null,
    [String]$Database = $null,
    [String]$DataDogEnv = "prod"
)

## Start Logging
Start-Transcript -OutputDirectory C:\Logs\datadog_metric_upload\sql_metric\

function Resolve-Inputs() {
    ## Check script param inputs
    Param(
        [String]$api_key = $ApiKey,
        [String]$app_key = $AppKey
    )
    If ( -Not $api_key ) {
        Write-Error "API key is missing. Pass an API key with -ApiKey `"<api key>`" or set an environment variable `$DATADOG_API_KEY"
        exit(1)
    }

    If ( -Not $app_key ) {
        Write-Error "Datadog App key is missing. Pass an App key with -AppKey `"<datadog app key>`" or set an environment variable `$DATADOG_APP_KEY"
        Write-Host "App key instructions: https://docs.datadoghq.com/account_management/api-app-keys/#add-an-api-key-or-client-token" -ForegroundColor Yellow
        exit(1)
    }

    If ( -Not $DataDogEnv ) {
        Write-Host "[WARNING] Missing `$DataDogEnv, defaulting to 'prod'" -ForegroundColor Yellow
        $DataDogEnv = "prod"
    }
}

Resolve-Inputs

If ( $Debug ) {
    Write-Host "[DEBUG] API Key: $($ApiKey)" -ForegroundColor Magenta
    Write-Host "[DEBUG] App Key: $($AppKey)" -ForegroundColor Magenta
}

## SQL query to execute. Returns the count of CRM Workflows matching a status in $WFStatuses
[String]$SQL_CMD = @"
USE $($Database)
SELECT COUNT(*) AS WFCount
FROM <TABLE NAME> WITH (NOLOCK)
WHERE <CONDITION>
"@

function Invoke-SQL {
    ## Invoke a SQL command against a pre-defined datasource
    param(
        [String]$DS = $Datasource,
        [String]$DB = $Database,
        [String]$Query = $SQL_CMD
    )

    If ( $Debug ) {
        Write-Host "[DEBUG] Datasource: $($DS)" -ForegroundColor Magenta
        Write-Host "[DEBUG] Database: $($Database)" -ForegroundColor Magenta
        Write-Host "[DEBUG] SQL query:`n$($Query)" -ForegroundColor Magenta
    }

    ## Build connection string
    $ConnectionStr = "Data Source=$DS; Integrated Security=SSPI; Initial Catalog=$DB"
    
    ## Build connection object
    $Connection = New-Object System.Data.SQLClient.SQLConnection($ConnectionStr)
    # Write-Host "Connection: $($Connection)"

    ## Build command object
    $Command = New-Object System.Data.SQLClient.SQLCommand($Query, $Connection)
    # Write-Host "Command: $($Command)"

    If ( $Debug ) {
        Write-Host "[DEBUG] Connection string: $($ConnectionStr)" -ForegroundColor Magenta
        Write-Host "[DEBUG] Connection: $($Connection)" -ForegroundColor Magenta
        Write-Host "[DEBUG] Command: $($Command)" -ForegroundColor Magenta
    }

    Write-Host "Opening Database connection & running SQL" -ForegroundColor Yellow

    try {
        ## Open connection to database
        $Connection.Open()

        ## Create an adapter
        $Adapter = New-Object System.Data.SQLClient.SQLDataAdapter $Command
        ## Initialize a dataset
        $Dataset = New-Object System.Data.DataSet
        ## Fill the dataset with output from command adapter
        $Adapter.Fill($DataSet) | Out-Null

        ## Close the connection
        $Connection.Close()

        ## Extract WF count from results
        $WorkflowCount = $DataSet.Tables[0].WFCount

        return $WorkflowCount
    }
    catch {
        Write-Error "Unhandled exception while connecting to database. Exception: $($_.Exception.message)"
    }
}

function unixTime() {
    Return (Get-Date -date ((get-date).ToUniversalTime()) -UFormat %s) -Replace ("[,\.]\d*", "")
}

function postMetric($metric, $tags) {
    $currenttime = unixTime
    $host_name = $env:COMPUTERNAME #optional parameter .

    If (-Not $metric.amount) {
        Write-Warning "Metric amount cannot be null."

        return 1
    }

    If ($Debug) {
        Write-Debug "DataDog ENV: $($DataDogEnv)"
        Write-Debug "Metric: $($metric)"
        Write-Debug "Metric name: $($metric.name)"
        Write-Debug "Metric amount: $($metric.amount)"
    }

    # Construct JSON
    $points = , @($currenttime, $metric.amount)
    try {
        $post_obj = [pscustomobject]@{"series" = , @{"metric" = $metric.name;
                "points"                                      = $points;
                "type"                                        = "gauge";
                "host"                                        = $host_name;
                "tags"                                        = $tags
            }
        }
    }
    catch {
        Write-Error "Error building POST body. Details: $($_.Exception.message)"
        exit 2
    }

    $post_json = $post_obj | ConvertTo-Json -Depth 5 -Compress

    Write-Debug "Post body: $($post_json)"

    # POST to DD API
    try {
        Write-Host "Posting results to DataDog" -ForegroundColor Blue

        Write-Debug "POST URL: $($url)"

        $response = Invoke-RestMethod -Method Post -Uri $url -Body $post_json -ContentType "application/json"
    
        Write-Debug "Response: $($response)"
    
    }
    catch {
        Write-Error "Unhandled exception POSTing query results to DataDog. Details: $($_.exception.message)"
        exit(1)
    }
}

$WFCount = Invoke-SQL
If ( $Debug ) {
    Write-Host "[DEBUG] SQL results: $($WFCount)" -ForegroundColor Magenta
}

If ( $WFCount -eq 0 ) {
    Write-Warning "No Workflows found in database."
    exit(0)
}

# Datadog account, API information and optional parameters
$app_key = "$($APP_KEY)" #provide your valid app key
$api_key = "$($API_KEY)" #provide your valid api key
$url_base = "https://us3.datadoghq.com/"
$url_signature = "api/v1/series"
$url = $url_base + $url_signature + "?api_key=$($APIKey)" + "&" + "application_key=$($AppKey)"
$tags = "[env:$($DataDogEnv)]" #optional parameter

<#
    !!! This is where the issue was with the script "not uploading data." It was posting the metric as "ps1.mmc"
#>

# Select what to send to Datadog. In this example, the number of handles opened by process "mmc" is being sent
$metric_ns = "crm.workflow" # your desired metric namespace
$metric_name = "$($metric_ns).all"
[System.Collections.Hashtable]$metric = @{"name" = $($metric_name); "amount" = $WFCount }


Write-Debug "Metric Name: $($metric_name)"
    
ForEach ($pair in $metric.GetEnumerator()) {
    Write-Debug "Key: $($pair.Key)`n`tValue: $($pair.Value)"
}

postMetric($metric)($tags) # pass your metric as a parameter to postMetric()

If ( $?) {
    Write-Host "[SUCCESS] Uploaded WWF job count metric to DataDog." -ForegroundColor Green
}
elseif ( $? -eq 1) {
    Write-Error "[FAILURE] Error POSTing DataDog metric."
}
else {
    Write-Error "[FAILURE] Failed uploading WWF job count metric to DataDog."
}

Stop-Transcript

exit($?)
