#!/bin/bash

# Snowflake Subsidiary License Information Query Script
# Usage: ./subsidiary-license-info.sh <subsidiary_name>

# Get script directory and load .env file from parent directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
if [ -f "$PARENT_DIR/.env" ]; then
    export $(grep -v '^#' "$PARENT_DIR/.env" | xargs)
fi

# Get parameters
subsidiary_name=$1
username=${SNOWFLAKE_USER}
snowflake_account=${SNOWFLAKE_ACCOUNT:-"UIPATH-UIPATH_OBSERVABILITY"}
project_dir=${PROJECT_DIR:-$SCRIPT_DIR}

# Expand tilde in project_dir
project_dir="${project_dir/#\~/$HOME}"

# Validate inputs
if [ -z "$subsidiary_name" ]; then
    echo "❌ Error: Subsidiary name is required"
    echo ""
    echo "Usage: ./subsidiary-license-info.sh <subsidiary_name>"
    echo ""
    echo "Examples:"
    echo "  ./subsidiary-license-info.sh \"PepsiCo, Inc\""
    echo "  ./subsidiary-license-info.sh \"Microsoft Corporation\""
    echo ""
    echo "Configuration: Set SNOWFLAKE_USER in .env file"
    exit 1
fi

if [ -z "$username" ]; then
    echo "❌ Error: Snowflake username not configured"
    echo ""
    echo "Please set SNOWFLAKE_USER in .env file:"
    echo "  SNOWFLAKE_USER=your.email@company.com"
    echo ""
    echo "Current .env location: $SCRIPT_DIR/.env"
    exit 1
fi

timestamp=$(date +%Y%m%d_%H%M%S)

# Create snowflake-data directory if it doesn't exist
mkdir -p "$project_dir/snowflake-data"

# Build output filename with subsidiary slug
subsidiary_slug=$(echo "$subsidiary_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr ',' '_' | tr -d '.')
output_file="$project_dir/snowflake-data/subsidiary_license_${subsidiary_slug}_${timestamp}.csv"

echo "=========================================="
echo "Subsidiary License Information"
echo "=========================================="
echo "Subsidiary: $subsidiary_name"
echo "User: $username"
echo "Account: $snowflake_account"
echo ""

# Load SQL query from file and substitute parameter
SQL_FILE="$PARENT_DIR/sql/subsidiary_license_query.sql"
if [ ! -f "$SQL_FILE" ]; then
    echo "❌ SQL file not found: $SQL_FILE"
    exit 1
fi

# Read SQL and replace parameter
QUERY=$(cat "$SQL_FILE" | sed "s/{SUBSIDIARY_NAME}/$subsidiary_name/g")

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
