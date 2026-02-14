#!/bin/bash

# Snowflake Subsidiary License Information Query Script
# Usage: ./subsidiary-license-info.sh <subsidiary_name> [username]

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Get parameters
subsidiary_name=$1
username=${2:-$SNOWFLAKE_USER}
snowflake_account=${SNOWFLAKE_ACCOUNT:-"UIPATH-UIPATH_OBSERVABILITY"}

# Validate inputs
if [ -z "$subsidiary_name" ]; then
    echo "❌ Error: Subsidiary name is required"
    echo ""
    echo "Usage: ./subsidiary-license-info.sh <subsidiary_name> [username]"
    echo ""
    echo "Examples:"
    echo "  ./subsidiary-license-info.sh \"PepsiCo, Inc\" your.email@company.com"
    echo "  ./subsidiary-license-info.sh \"Microsoft Corporation\""
    exit 1
fi

if [ -z "$username" ]; then
    echo "❌ Error: Snowflake username required"
    echo ""
    echo "Usage: ./subsidiary-license-info.sh <subsidiary_name> <username>"
    echo "   OR: export SNOWFLAKE_USER=<username> && ./subsidiary-license-info.sh <subsidiary_name>"
    echo ""
    echo "Example: ./subsidiary-license-info.sh \"PepsiCo, Inc\" your.email@company.com"
    exit 1
fi

timestamp=$(date +%Y%m%d_%H%M%S)

# Create snowflake-data directory if it doesn't exist
mkdir -p ~/Documents/uipath-integration-analyst/snowflake-data

# Build output filename with subsidiary slug
subsidiary_slug=$(echo "$subsidiary_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr ',' '_' | tr -d '.')
output_file=~/Documents/uipath-integration-analyst/snowflake-data/subsidiary_license_${subsidiary_slug}_${timestamp}.csv

echo "=========================================="
echo "Subsidiary License Information"
echo "=========================================="
echo "Subsidiary: $subsidiary_name"
echo "User: $username"
echo "Account: $snowflake_account"
echo ""

# The SQL query to execute (using ILIKE for partial matching, case-insensitive)
QUERY="select * from prod_customer360.customerprofile.CustomerSubsidiaryLicenseProfile where SUBSIDIARYNAME ILIKE '%$subsidiary_name%';"

# Check if snowsql is available
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
    # Check if file has actual data (more than just auth messages)
    # Count lines that look like CSV data (contain quotes or commas)
    data_lines=$(grep -c '","' "$output_file" 2>/dev/null || echo "0")

    if [ "$data_lines" -gt 0 ]; then
        # Count records (subtract header)
        total=$((data_lines - 1))

        if [ $total -gt 0 ]; then
            echo "✅ Query completed successfully!"
            echo "📊 Total records found: $total"
            echo "💾 Results saved to: $output_file"
            echo ""

            # Show column count
            header_line=$(grep -m 1 '","' "$output_file" 2>/dev/null)
            if [ -n "$header_line" ]; then
                col_count=$(echo "$header_line" | tr ',' '\n' | wc -l)
                echo "📋 Columns retrieved: $col_count"
            fi
        else
            echo "⚠️  No records found for subsidiary matching: $subsidiary_name"
            echo "💡 Tip: Using partial matching (ILIKE). Try a shorter search term or check Salesforce for exact name"
            echo "💾 Results saved to: $output_file"
        fi
    else
        echo "⚠️  No data returned for subsidiary matching: $subsidiary_name"
        echo "💡 Tip: Using partial matching (ILIKE). Try different search terms"
        echo "💾 Results saved to: $output_file"
    fi
else
    echo "❌ Query failed. Check your Snowflake authentication."
    echo "Error output:"
    cat "$output_file"
    exit 1
fi
