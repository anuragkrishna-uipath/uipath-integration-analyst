#!/bin/bash

# Snowflake Integration Service Usage Query Script
# Usage: ./snowflake-is-usage.sh [username]

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Get username from argument or environment variable
username=${1:-$SNOWFLAKE_USER}
snowflake_account=${SNOWFLAKE_ACCOUNT:-"UIPATH-UIPATH_OBSERVABILITY"}

if [ -z "$username" ]; then
    echo "❌ Error: Snowflake username required"
    echo ""
    echo "Usage: ./snowflake-is-usage.sh <username>"
    echo "   OR: export SNOWFLAKE_USER=<username> && ./snowflake-is-usage.sh"
    echo ""
    echo "Example: ./snowflake-is-usage.sh your.email@company.com"
    exit 1
fi

timestamp=$(date +%Y%m%d_%H%M%S)

# Create snowflake-data directory if it doesn't exist
mkdir -p ~/Documents/pm-assistant/snowflake-data

output_file=~/Documents/pm-assistant/snowflake-data/snowflake_is_usage_${timestamp}.csv

echo "=========================================="
echo "Snowflake Integration Service API Usage"
echo "=========================================="
echo "User: $username"
echo "Account: $snowflake_account"
echo "Querying last 3 months of data..."
echo ""

# The SQL query to execute
read -r -d '' QUERY << 'EOF'
select
    s.name,
    its.connectorkey,
    case
     when its.originator in ('UiPath.PO', 'Uipath.AgenticOrchestration.Designer') then 'Maestro'
     when its.originator in ('UiPath.AgentService', 'Uipath.Agent.Designer') then 'Agents'
     when its.originator = 'UiPath.IntegrationService.Poller' then 'IS Pollers'
     when its.originator ILIKE '%robot%' then 'Robot'
     when its.originator = 'api-workflow' then 'API Workflows'
     when its.originator = 'UiPath.Studio' then 'Studio'
     when its.originator ILIKE '%StudioWeb%' then 'Studio Web'
     when its.originator in ('UiPath.IntegrationService.ConnectionService', 'UiPath.IntegrationService.Triggers', 'UiPath.IntegrationService.Webhook', 'UiPath.Ezra') then 'Connections OR Trigger Creation'
     when its.originator = 'Autopilot' then 'Autopilot'
     when its.originator = 'integration-tests' then 'Tests'
     when its.originator = 'ElementService.OauthTokenRefreshJob' then 'ConnectionsTokenRefreshJob'
     when its.originator in ('ElementService.Soba', 'denali', 'folder-auth') then 'IS Internal Chained Calls'
     else 'Others'
    end as GroupedOriginator,
    count(*) as APIUsage
from
        PROD_ELEMENTSERVICE.APPINS.INTEGRATIONSERVICE_TELEMETRY_STANDARDIZED as its
    join prod_customer360.standard.cloudorganizationexclusivesubcodehistory as sch
        on its.cloudorganizationid = sch.cloudorganizationid
            and sch.Date = current_date() - 1
    join prod_customer360.constants.SubscriptionCodeAttributes as sca
        on sch.subscriptioncode = sca.subscriptioncode
    join prod_customer360.standard.cloudorganizationtosubsidiarymap as cmap
        on sch.cloudorganizationid=cmap.cloudorganizationid
    left join prod_customer360.standard.SubsidiaryHistory s
        on s.Id =  cmap.subsidiaryid
where
    its.eventname = 'API.Request'
    and its.RequestType = 'vendor'
    and its.Date >= DATEADD(month, -3, CURRENT_DATE)
    and its.activationtype = 'AutomationCloud'
group by 1,2,3
order by 4 desc;
EOF

# Run the query using SnowSQL
# First check if snowsql is available
if ! command -v snowsql &> /dev/null; then
    echo "❌ SnowSQL CLI not found. Please install it first."
    echo "Visit: https://docs.snowflake.com/en/user-guide/snowsql-install-config.html"
    exit 1
fi

# Run the query with SSO authentication
snowsql -a "$snowflake_account" \
    -u "$username" \
    --authenticator externalbrowser \
    -o output_format=csv \
    -o header=true \
    -o timing=false \
    -o friendly=false \
    -o log_level=ERROR \
    -q "$QUERY" \
    > "$output_file" 2>&1

# Check if query was successful
if [ $? -eq 0 ]; then
    # Count records (subtract 1 for header)
    total=$(( $(wc -l < "$output_file") - 1 ))

    if [ $total -gt 0 ]; then
        echo "✅ Query completed successfully!"
        echo "📊 Total records found: $total"
        echo "💾 Results saved to: $output_file"
        echo ""

        # Show top 5 subsidiaries by API usage
        echo "Top 5 subsidiaries by API usage:"
        tail -n +2 "$output_file" | sort -t',' -k4 -rn | head -5 | awk -F',' '{printf "  %s: %s calls\n", $1, $4}'
        echo ""

        # Calculate total API usage
        total_usage=$(tail -n +2 "$output_file" | awk -F',' '{sum+=$4} END {print sum}')
        echo "📈 Total API Usage: $(printf "%'d" $total_usage) calls"
    else
        echo "⚠️  Query returned no results."
        echo "💾 Results saved to: $output_file"
    fi
else
    echo "❌ Query failed. Check your Snowflake authentication."
    echo "Error output:"
    cat "$output_file"
    exit 1
fi
