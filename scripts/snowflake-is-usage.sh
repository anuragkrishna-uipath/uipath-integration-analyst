#!/bin/bash

# Snowflake Integration Service Usage Query Script
# Usage: ./snowflake-is-usage.sh [customer_name]

# Get script directory and load .env file from parent directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
if [ -f "$PARENT_DIR/.env" ]; then
    export $(grep -v '^#' "$PARENT_DIR/.env" | xargs)
fi

# Parse arguments
customer_name="$1"
username=${SNOWFLAKE_USER}
snowflake_account=${SNOWFLAKE_ACCOUNT:-"UIPATH-UIPATH_OBSERVABILITY"}
project_dir=${PROJECT_DIR:-$SCRIPT_DIR}

# Expand tilde in project_dir
project_dir="${project_dir/#\~/$HOME}"

# Create snowflake-data directory if it doesn't exist
mkdir -p "$project_dir/snowflake-data"

# If customer name provided, check for cached data first
if [ -n "$customer_name" ]; then
    # Normalize customer name for filename matching
    normalized_name=$(echo "$customer_name" | tr '[:upper:]' '[:lower:]' | sed 's/[, ]/_/g')

    # Find most recent cached file for this customer
    cached_file=$(ls -t "$project_dir/snowflake-data/snowflake_is_usage_*"$normalized_name"*.csv" 2>/dev/null | head -1)

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
    echo "❌ Error: Snowflake username not configured"
    echo ""
    echo "Please set SNOWFLAKE_USER in .env file:"
    echo "  SNOWFLAKE_USER=your.email@company.com"
    echo ""
    echo "Usage: ./snowflake-is-usage.sh [customer_name]"
    echo ""
    echo "Examples:"
    echo "  ./snowflake-is-usage.sh                    # Query all customers"
    echo "  ./snowflake-is-usage.sh \"PepsiCo, Inc\"     # Query specific customer"
    echo ""
    echo "Current .env location: $SCRIPT_DIR/.env"
    exit 1
fi

timestamp=$(date +%Y%m%d_%H%M%S)

# Set output filename with customer name if provided
if [ -n "$customer_name" ]; then
    normalized_name=$(echo "$customer_name" | tr '[:upper:]' '[:lower:]' | sed 's/[, ]/_/g')
    output_file="$project_dir/snowflake-data/snowflake_is_usage_${timestamp}_${normalized_name}.csv"
else
    output_file="$project_dir/snowflake-data/snowflake_is_usage_${timestamp}.csv"
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

# Load SQL query from file with optional customer filter
if [ -n "$customer_name" ]; then
    SQL_FILE="$PARENT_DIR/sql/is_usage_query_with_customer.sql"
    if [ ! -f "$SQL_FILE" ]; then
        echo "❌ SQL file not found: $SQL_FILE"
        exit 1
    fi
    # Read SQL and replace parameter
    QUERY=$(cat "$SQL_FILE" | sed "s/{CUSTOMER_NAME}/$customer_name/g")
else
    SQL_FILE="$PARENT_DIR/sql/is_usage_query_all.sql"
    if [ ! -f "$SQL_FILE" ]; then
        echo "❌ SQL file not found: $SQL_FILE"
        exit 1
    fi
    QUERY=$(cat "$SQL_FILE")
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
