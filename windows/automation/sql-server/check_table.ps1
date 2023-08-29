<#
    Description:
        ...

    Params:
        $WEBHOOK_URL = "<Teams integration URL>":
            The webhook URL for a Teams channel to send alerts to
        $DATASOURCE = "<Database Server>":
            The server running SQL Server
        $DATABASE = "<Database>":
            The database to connect to in SQL Server
        $SQL_CMD = <multi-line here-string>:
            The SQL command to run
        $ALERT_THRESHOLD = 3000:
            When the Count value in the SQL query crosses this threshold,
            an alert will be triggered if $SEND_ALERT = $true
        $SEND_ALERT = $true:
            Bool value to override alerting, even if threshold is breached.
            When set to false (i.e. -SEND_ALERT $false), no message will be
            sent, regardless of Count.

    Usage:
        Script will execute with the default values
        defined in the "Global script params" section.

        You can override any of these params with command-line args. For example,
        to override the default value of ALERT_THRESHOLD, launch the script like:
            $ .\check_table.ps1 -ALERT_THRESHOLD 5000
#>

########################
# Global script params #
########################
param(
    ## Webhook for Teams channel to send Alerts to
    [string] $WEBHOOK_URL = $null,
    ## Set the data source (server hosting the database)
    [string] $DATASOURCE = $null,
    ## Set the database to connect to
    [string] $DATABASE = $null,
    ## Query to execute
    [string] $SQL_CMD = @"
DECLARE @someVariable AS VARCHAR(128)
SET @someVariable = 'Some value'

USE <database>
SELECT COUNT(*) AS Count
FROM <table> WITH (NOLOCK)
WHERE someColumn = @someVariable
"@,

    ## Number that Count needs to exceed before alert is triggered
    [int] $ALERT_THRESHOLD = 3000,
    ## Bool to determine if alert is sent when threshold is crossed
    [bool] $SEND_ALERT = $true
)

## Turn off alerting if no $WEBHOOK_URL was passed
If ( ! $WEBHOOK_URL ) {
    Write-Host "No webhook URL was passed, disabling alerts."
    $SEND_ALERT = $False
}

## Store alert colors. These colors fill the 'themeColor'
#  property of an $AlertMessageBody object, and determine
#  the color along the top of the message box in Teams.
$AlertMsgColors = [PSCustomObject]@{
    ## Green
    notify = '048720'
    ## Yellow
    warn   = 'fcba03'
    ## Red
    alert  = 'cc0404'
}

## Custom object will be converted to a JSON body to
#  send in a request to the webhook URL
$AlertMessageBody = [PSCustomObject][Ordered]@{
    "@type"      = "MessageCard"
    "@context"   = "<http://schema.org/extensions>"
    "summary"    = ""
    "themeColor" = $AlertMsgColors.notify
    "title"      = ""
    "text"       = ""
}


####################
# Script functions #
####################
function Invoke-SQL {
    ## Build a connection to a SQL database and execute a command.
    #  Return the output
    param(
        [string] $DS = $DATASOURCE,
        [string] $DB = $DATABASE,
        [string] $CMD = $SQL_CMD
    )

    ## Build connection string
    $ConnectionStr = "Data Source=$DS; Integrated Security=SSPI; Initial Catalog=$DB"
    # Write-Host "Connection String: $($ConnectionStr)"

    ## Build connection object
    $Connection = New-Object System.Data.SQLClient.SQLConnection($ConnectionStr)
    # Write-Host "Connection: $($Connection)"

    ## Build command object
    $Command = New-Object System.Data.SQLClient.SQLCommand($CMD, $Connection)
    # Write-Host "Command: $($Command)"

    Write-Host "Opening Database connection & running SQL"

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
        $WFCount = $DataSet.Tables[0].WFCount

        return $WFCount
    }
    catch {
        Write-Error "Unhandled exception while connecting to database. Details: {$($_.Exception.Message)}"
    }

}

function New-AlertMsg {
    ## https://www.scriptrunner.com/en/blog/teams-webhooks-via-powershell-part-1
    #  Build a message to send to Teams
    param(
        [string] $AlertColor = $AlertMsgColors.notify,
        [string] $MsgTitle = "No message title detected",
        [string] $MsgBody = "No message body detected",
        [string] $MsgSummary = "Threshold has been breached"
    )

    try {
        ## Build message
        $AlertMessageBody.themeColor = $AlertColor
        $AlertMessageBody.title = $MsgTitle
        $AlertMessageBody.text = $MsgBody
        $AlertMessageBody.summary = $MsgSummary

        ## Convert message to JSON
        $TeamsMsgBody = ConvertTo-Json $AlertMessageBody

        return $TeamsMsgBody
    }
    catch {
        Write-Error "Unhandled exception formatting Alert message"
    }
}

function New-AlertParams {
    ## Build params object to send a message to Teams via webhook
    param(
        [string] $AlertURI = $WEBHOOK_URL,
        [string] $AlertMethod = "POST",
        $AlertBody = $null,
        [string] $AlertContentType = "application/json"
    )

    try {
        $AlertParams = @{
            "URI"         = $AlertURI
            "Method"      = $AlertMethod
            "Body"        = $AlertBody
            "ContentType" = $AlertContentType
        }

    
        return $AlertParams
    }
    catch {
        Write-Error "Unhandled exception setting params"
    }
}

function Send-Alert {
    ## Send alert message to Teams via webhook
    param(
        $MsgParams = $null
    )

    try {
        Invoke-RestMethod @MsgParams
    }
    catch {
        Write-Error "Unhandled exception making $($MsgParams.Method) request to $($MsgParams.URI). Details: $($_.Exception.Message)"
    }
}

function Set-DynamicThresholdMultiplier {
    ## Dynamically adjust the threshold multipler when determining
    #  which type of alert to send, if any. A larger threshold value
    #  in $ALERT_THRESHOLD equals a smaller multiplier.
    param(
        [int] $Threshold = $ALERT_THRESHOLD
    )

    IF ( $Threshold -le 100) {
        ## 100%
        $Multiplier = 1
    }
    ElseIf ( $Threshold -gt 500 -and $Threshold -le 1000) {
        ## 150%
        $Multiplier = 1.5
    }
    ElseIf ( $Threshold -le 10000 ) {
        ## 125%
        $Multiplier = 1.25
    }
    ElseIf ( $Threshold -gt 10000 -and $Threshold -le 20000 ) {
        ## 50%
        $Multiplier = .5
    }
    ElseIf ( $Threshold -gt 20000 -and $Threshold -le 50000 ) {
        ## 20%
        $Multiplier = .2
    }
    ElseIf ( $Threshold -gt 50000 -and $Threshold -le 100000 ) {
        ## 5%
        $Multiplier = .05

    }
    Else {
        ## Count is over 100,000, scale to 2%
        $Multiplier = .02
    }

    # $DynamicThreshold = ( $ALERT_THRESHOLD * $Multiplier )

    # return $DynamicThreshold

    return $Multiplier

}

# function main {
function Start-Checks {

    $DBCount = Invoke-SQL
    # Write-Host "Workflows in the queue: $($DBCount)"

    If ( $DBCount -ge $ALERT_THRESHOLD ) {
        
        $Multiplier = Set-DynamicThresholdMultiplier -Threshold $ALERT_THRESHOLD
        # Write-Host "Multiplier: $($Multiplier). DynamicThreshold: $($ALERT_THRESHOLD * $Multiplier)"
        
        If ( $DBCount -ge ( $AlertThreshold * $Multiplier) -and $DBCount -lt $ALERT_THRESHOLD * 2) {
            ## Warn
            $AlertMsgText = "Alert threshold [$($ALERT_THRESHOLD)] exceeded. There are $($DBCount) rows in the column."
            $ThemeColor = $AlertMsgColors.warn
        }
        ElseIf ( $DBCount -ge ( $ALERT_THRESHOLD * 2 ) ) {
            ## Alert
            $AlertMsgText = "Alert threshold [$($ALERT_THRESHOLD)] exceeded by 200% or more. There are $($DBCount) rows in the column"
            $ThemeColor = $AlertMsgColors.alert
        }
        Else {
            ## Info
            $ThemeColor = $AlertMsgColors.notify
            $AlertMsgText = "Alert threshold [$($ALERT_THRESHOLD)] exceeded. There are $($DBCount) rows in the column"
        }

        ## Display Alert message to console
        Write-Host $AlertMsgText

        ## Build alert message body JSON
        $AlertMsgBody = New-AlertMsg -MsgBody $AlertMsgText -AlertColor $ThemeColor
        # Write-Host "Alert Message Body: $($AlertMsgBody)"

        ## Build request params object
        $TeamsMsgParams = New-AlertParams -AlertBody $AlertMsgBody

        # Write-Host "Message Params: $($TeamsMsgParams)"

        ## Check if alert should be sent
        If ( $SEND_ALERT -eq $true ) {
            try {
                Send-Alert -MsgParams $TeamsMsgParams
            }
            catch {
                Write-Error "Unhandled exception sending webhook request to $($WEBHOOK_URL). Details: $($_.Exception.Message)"
            }
        }
        else {
            Write-Host "SEND_ALERT is set to False. Skipping alert message send."
        }
    }
    else {
        ## Threshold has not been breached, don't alert
        $AlertMsgText = "Column Count [$($DBCount)] is less than the alert threshold [$($ALERT_THRESHOLD)]. No action needed."
        Write-Host $AlertMsgText
    }

}

## Run the script
Start-Checks
