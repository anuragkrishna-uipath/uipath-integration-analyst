#!/bin/bash

# Snowflake Usage Query Tool (Generic)
# Usage: ./snowflake-usage.sh <module> [customer_name]
# Run without arguments to see available modules.

# Get script directory and load .env file from parent directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
if [ -f "$PARENT_DIR/.env" ]; then
    export $(grep -v '^#' "$PARENT_DIR/.env" | xargs)
fi

# Parse arguments
module_arg="$1"
customer_name="$2"
username=${SNOWFLAKE_USER}
snowflake_account=${SNOWFLAKE_ACCOUNT:-"UIPATH-UIPATH_OBSERVABILITY"}
project_dir=${PROJECT_DIR:-$PARENT_DIR}
config_file="$PARENT_DIR/snowflake-modules.conf"

# Expand tilde in project_dir
project_dir="${project_dir/#\~/$HOME}"

# ==========================================
# Module Resolution
# ==========================================

# Check config file exists
if [ ! -f "$config_file" ]; then
    echo "❌ Module config not found: $config_file"
    echo "Create snowflake-modules.conf in the project root. See README for format."
    exit 1
fi

# Function to parse a module line into variables
parse_module_line() {
    local line="$1"
    IFS='|' read -r ids_field display_name description cache_days sql_with_customer sql_all legacy_prefix <<< "$line"
    # ids_field contains "module_id,alias" or just "module_id"
    module_id=$(echo "$ids_field" | cut -d',' -f1)
    module_alias=$(echo "$ids_field" | cut -d',' -f2 -s)
}

# If no module argument, show help
if [ -z "$module_arg" ]; then
    echo "=========================================="
    echo "Snowflake Usage Query Tool"
    echo "=========================================="
    echo ""
    echo "Available modules:"
    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        parse_module_line "$line"
        if [ -n "$module_alias" ]; then
            printf "  %-30s - %s [cache: %s days]\n" "$module_id ($module_alias)" "$description" "$cache_days"
        else
            printf "  %-30s - %s [cache: %s days]\n" "$module_id" "$description" "$cache_days"
        fi
    done < "$config_file"
    echo ""
    echo "Usage:"
    echo "  ./snowflake-usage.sh <module> [customer_name]"
    echo ""
    echo "Examples:"
    echo "  ./snowflake-usage.sh integration-service \"PepsiCo, Inc\""
    echo "  ./snowflake-usage.sh is \"PepsiCo, Inc\""
    echo "  ./snowflake-usage.sh is"
    exit 0
fi

# Look up the module by ID or alias
found=false
while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    parse_module_line "$line"
    if [ "$module_arg" = "$module_id" ] || [ "$module_arg" = "$module_alias" ]; then
        found=true
        break
    fi
done < "$config_file"

if [ "$found" = false ]; then
    echo "❌ Unknown module: $module_arg"
    echo ""
    echo "Available modules:"
    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        parse_module_line "$line"
        if [ -n "$module_alias" ]; then
            echo "  $module_id ($module_alias)"
        else
            echo "  $module_id"
        fi
    done < "$config_file"
    exit 1
fi

# ==========================================
# Cache Check (if customer name provided)
# ==========================================

# Create snowflake-data directory if it doesn't exist
mkdir -p "$project_dir/snowflake-data"

cache_ttl=$((cache_days * 86400))

if [ -n "$customer_name" ] && [ "$cache_ttl" -gt 0 ]; then
    # Normalize customer name for filename matching
    normalized_name=$(echo "$customer_name" | tr '[:upper:]' '[:lower:]' | sed 's/[, ]/_/g')

    # Find most recent cached file — check current prefix and legacy prefix
    cached_file=$(ls -t "$project_dir/snowflake-data/snowflake_${module_id}_"*"$normalized_name"*.csv 2>/dev/null | head -1)

    # If not found and legacy prefix exists, check legacy pattern
    if [ -z "$cached_file" ] && [ -n "$legacy_prefix" ]; then
        cached_file=$(ls -t "$project_dir/snowflake-data/snowflake_${legacy_prefix}_"*"$normalized_name"*.csv 2>/dev/null | head -1)
    fi

    if [ -n "$cached_file" ]; then
        # Check cache age
        current_time=$(date +%s)
        file_mtime=$(stat -f %m "$cached_file" 2>/dev/null || stat -c %Y "$cached_file" 2>/dev/null)
        cache_age=$((current_time - file_mtime))
        cache_age_days=$((cache_age / 86400))

        # Validate cache has data (more than 3 lines: auth output + header + at least 1 data row)
        line_count=$(wc -l < "$cached_file")

        # Check if cache is valid (within TTL AND has data)
        if [ $cache_age -lt $cache_ttl ] && [ $line_count -gt 3 ]; then
            echo "=========================================="
            echo "$display_name"
            echo "=========================================="
            echo "Customer: $customer_name"
            echo "✓ Using cached data from: $(basename "$cached_file") ($cache_age_days days old)"
            echo ""

            # Display summary from cached file
            total=$(( $(wc -l < "$cached_file") - 3 ))  # Subtract auth lines + header
            if [ $total -gt 0 ]; then
                echo "📊 Total records found: $total"
                echo ""

                # Get header to determine column names
                header=$(sed -n '3p' "$cached_file")
                last_col_name=$(echo "$header" | awk -F',' '{print $NF}' | tr -d '"')

                # Show top 5 by last numeric column (strip quotes for proper sorting/display)
                echo "Top 5 by $last_col_name:"
                tail -n +4 "$cached_file" | tr -d '"' | sort -t',' -k4 -rn | head -5 | awk -F',' '{printf "  %s: %s\n", $2, $NF}'
                echo ""

                # Calculate total of last numeric column
                total_usage=$(tail -n +4 "$cached_file" | tr -d '"' | awk -F',' '{sum+=$NF} END {print sum}')
                echo "📈 Total $last_col_name: $(printf "%'d" $total_usage)"
                echo ""
                echo "💾 Cached file: $cached_file"
            fi
            exit 0
        elif [ $cache_age -ge $cache_ttl ]; then
            echo "⚠️  Cached data is stale ($cache_age_days days old, limit: $cache_days days). Querying fresh data..."
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

# ==========================================
# Validate Prerequisites
# ==========================================

if [ -z "$username" ]; then
    echo "❌ Error: Snowflake username not configured"
    echo ""
    echo "Please set SNOWFLAKE_USER in .env file:"
    echo "  SNOWFLAKE_USER=your.email@company.com"
    exit 1
fi

if ! command -v snowsql &> /dev/null; then
    echo "❌ SnowSQL CLI not found. Please install it first."
    echo "Visit: https://docs.snowflake.com/en/user-guide/snowsql-install-config.html"
    exit 1
fi

# ==========================================
# SQL Load & Execute
# ==========================================

timestamp=$(date +%Y%m%d_%H%M%S)

# Set output filename
if [ -n "$customer_name" ]; then
    normalized_name=$(echo "$customer_name" | tr '[:upper:]' '[:lower:]' | sed 's/[, ]/_/g')
    output_file="$project_dir/snowflake-data/snowflake_${module_id}_${timestamp}_${normalized_name}.csv"
else
    output_file="$project_dir/snowflake-data/snowflake_${module_id}_${timestamp}.csv"
fi

echo "=========================================="
echo "$display_name"
echo "=========================================="
if [ -n "$customer_name" ]; then
    echo "Customer: $customer_name"
fi
echo "User: $username"
echo "Account: $snowflake_account"
echo "Querying data..."
echo ""

# Load SQL query from file
if [ -n "$customer_name" ]; then
    SQL_FILE="$PARENT_DIR/sql/$sql_with_customer"
    if [ ! -f "$SQL_FILE" ]; then
        echo "❌ SQL file not found: $SQL_FILE"
        exit 1
    fi
    QUERY=$(cat "$SQL_FILE" | sed "s/{CUSTOMER_NAME}/$customer_name/g")
else
    SQL_FILE="$PARENT_DIR/sql/$sql_all"
    if [ ! -f "$SQL_FILE" ]; then
        echo "❌ SQL file not found: $SQL_FILE"
        exit 1
    fi
    QUERY=$(cat "$SQL_FILE")
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

# ==========================================
# Results Display
# ==========================================

if [ $? -eq 0 ]; then
    # Count records (subtract 1 for header)
    total=$(( $(wc -l < "$output_file") - 1 ))

    if [ $total -gt 0 ]; then
        echo "✅ Query completed successfully!"
        echo "📊 Total records found: $total"
        echo "💾 Results saved to: $output_file"
        echo ""

        # Get header to determine column names
        header=$(head -1 "$output_file")
        last_col_name=$(echo "$header" | awk -F',' '{print $NF}' | tr -d '"')

        # Show top 5 results by last numeric column (strip quotes for proper sorting/display)
        if [ -n "$customer_name" ]; then
            echo "Top 5 by $last_col_name:"
            tail -n +2 "$output_file" | tr -d '"' | sort -t',' -k4 -rn | head -5 | awk -F',' '{printf "  %s: %s\n", $2, $NF}'
        else
            echo "Top 5 by $last_col_name:"
            tail -n +2 "$output_file" | tr -d '"' | sort -t',' -k4 -rn | head -5 | awk -F',' '{printf "  %s: %s\n", $1, $NF}'
        fi
        echo ""

        # Calculate total of last numeric column
        total_usage=$(tail -n +2 "$output_file" | tr -d '"' | awk -F',' '{sum+=$NF} END {print sum}')
        echo "📈 Total $last_col_name: $(printf "%'d" $total_usage)"
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
