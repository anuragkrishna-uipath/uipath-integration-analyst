#!/bin/bash

# Snowflake Integration Service Usage Query Script
# Usage: ./snowflake-is-usage.sh [customer_name] [username]

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Parse arguments
customer_name=""
username=""

if [ $# -eq 2 ]; then
    customer_name="$1"
    username="$2"
elif [ $# -eq 1 ]; then
    # If only one argument, check if it contains @ (email) or is a customer name
    if [[ "$1" == *"@"* ]]; then
        username="$1"
    else
        customer_name="$1"
    fi
fi

# Use environment variable as fallback for username
username=${username:-$SNOWFLAKE_USER}
snowflake_account=${SNOWFLAKE_ACCOUNT:-"UIPATH-UIPATH_OBSERVABILITY"}

# Create snowflake-data directory if it doesn't exist
mkdir -p ~/Documents/uipath-integration-analyst/snowflake-data

# If customer name provided, check for cached data first
if [ -n "$customer_name" ]; then
    # Normalize customer name for filename matching
    normalized_name=$(echo "$customer_name" | tr '[:upper:]' '[:lower:]' | sed 's/[, ]/_/g')

    # Find most recent cached file for this customer
    cached_file=$(ls -t ~/Documents/uipath-integration-analyst/snowflake-data/snowflake_is_usage_*"$normalized_name"*.csv 2>/dev/null | head -1)

    if [ -n "$cached_file" ]; then
        # Check cache age (7 days = 604800 seconds)
        current_time=$(date +%s)
        file_mtime=$(stat -f %m "$cached_file" 2>/dev/null || stat -c %Y "$cached_file" 2>/dev/null)
        cache_age=$((current_time - file_mtime))
        cache_age_days=$((cache_age / 86400))

        # Validate cache has data (more than 3 lines: auth output + header + at least 1 data row)
        line_count=$(wc -l < "$cached_file")

        # Check if cache is valid (< 7 days old AND has data)
        if [ $cache_age -lt 604800 ] && [ $line_count -gt 3 ]; then
            echo "=========================================="
            echo "Snowflake Integration Service API Usage"
            echo "=========================================="
            echo "Customer: $customer_name"
            echo "✓ Using cached data from: $(basename "$cached_file") ($cache_age_days days old)"
            echo ""

            # Display summary from cached file
            total=$(( $(wc -l < "$cached_file") - 3 ))  # Subtract auth lines + header
            if [ $total -gt 0 ]; then
                echo "📊 Total records found: $total"
                echo ""

                # Show top 5 connector keys by API usage
                echo "Top 5 connector keys by API usage:"
                tail -n +4 "$cached_file" | sort -t',' -k4 -rn | head -5 | awk -F',' '{printf "  %s: %s calls\n", $2, $4}'
                echo ""

                # Calculate total API usage
                total_usage=$(tail -n +4 "$cached_file" | awk -F',' '{sum+=$4} END {print sum}')
                echo "📈 Total API Usage: $(printf "%'d" $total_usage) calls"
                echo ""
                echo "💾 Cached file: $cached_file"
            fi
            exit 0
        elif [ $cache_age -ge 604800 ]; then
            echo "⚠️  Cached data is stale ($cache_age_days days old, limit: 7 days). Querying fresh data..."
            echo ""
        elif [ $line_count -le 3 ]; then
            echo "⚠️  Cached file is empty (no data rows). Querying fresh data..."
            echo ""
        fi
    else
        echo "ℹ️  No cached data found for '$customer_name'. Querying Snowflake..."
        echo ""
    fi
fi

if [ -z "$username" ]; then
    echo "❌ Error: Snowflake username required"
    echo ""
    echo "Usage: ./snowflake-is-usage.sh [customer_name] <username>"
    echo "   OR: export SNOWFLAKE_USER=<username> && ./snowflake-is-usage.sh [customer_name]"
    echo ""
    echo "Examples:"
    echo "  ./snowflake-is-usage.sh your.email@company.com"
    echo "  ./snowflake-is-usage.sh \"PepsiCo, Inc\" your.email@company.com"
    exit 1
fi

timestamp=$(date +%Y%m%d_%H%M%S)

# Set output filename with customer name if provided
if [ -n "$customer_name" ]; then
    normalized_name=$(echo "$customer_name" | tr '[:upper:]' '[:lower:]' | sed 's/[, ]/_/g')
    output_file=~/Documents/uipath-integration-analyst/snowflake-data/snowflake_is_usage_${timestamp}_${normalized_name}.csv
else
    output_file=~/Documents/uipath-integration-analyst/snowflake-data/snowflake_is_usage_${timestamp}.csv
fi

echo "=========================================="
echo "Snowflake Integration Service API Usage"
echo "=========================================="
if [ -n "$customer_name" ]; then
    echo "Customer: $customer_name"
fi
echo "User: $username"
echo "Account: $snowflake_account"
echo "Querying last 3 months of data..."
echo ""

# Build the SQL query with optional customer filter
if [ -n "$customer_name" ]; then
    # Query with customer filter
    read -r -d '' QUERY << EOF
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
    and s.name ILIKE '%$customer_name%'
group by 1,2,3
order by 4 desc
LIMIT 500;
EOF
else
    # Query without customer filter
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
fi

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

        # Show top results by API usage
        if [ -n "$customer_name" ]; then
            echo "Top 5 connector keys by API usage:"
            tail -n +2 "$output_file" | sort -t',' -k4 -rn | head -5 | awk -F',' '{printf "  %s: %s calls\n", $2, $4}'
        else
            echo "Top 5 subsidiaries by API usage:"
            tail -n +2 "$output_file" | sort -t',' -k4 -rn | head -5 | awk -F',' '{printf "  %s: %s calls\n", $1, $4}'
        fi
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
