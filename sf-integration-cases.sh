#!/bin/bash

# Salesforce Integration Service Cases Query Script
# Usage: ./sf-integration-cases.sh [days] [customer_name]
# Default: 7 days, all customers

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

days=${1:-7}
customer_name=$2
timestamp=$(date +%Y%m%d_%H%M%S)
sf_org=${SALESFORCE_ORG_ALIAS:-"uipath"}

# Create is-cases directory if it doesn't exist
mkdir -p ~/Documents/uipath-integration-analyst/is-cases

# Build output filename
if [ -n "$customer_name" ]; then
    customer_slug=$(echo "$customer_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
    output_file=~/Documents/uipath-integration-analyst/is-cases/sf_integration_cases_${days}days_${customer_slug}_${timestamp}.json
else
    output_file=~/Documents/uipath-integration-analyst/is-cases/sf_integration_cases_${days}days_${timestamp}.json
fi

echo "=========================================="
echo "Salesforce Integration Service Cases"
echo "=========================================="
echo "Querying cases from last $days days..."
if [ -n "$customer_name" ]; then
    echo "Filtering by customer: $customer_name"
fi
echo ""

# Build the WHERE clause
where_clause="CreatedDate = LAST_N_DAYS:$days AND Deployment_Type_Product_Component__c LIKE '%Integration Service%'"
if [ -n "$customer_name" ]; then
    where_clause="$where_clause AND Account.Name LIKE '%$customer_name%'"
fi

# Run the query
sf data query --query "SELECT Id, CaseNumber, Subject, RecordType.Name, Status, CreatedDate, Priority, Description, Solution__c, Owner.Name, Account.Name, Deployment_Type_Product_Component__c FROM Case WHERE $where_clause ORDER BY CreatedDate DESC" --target-org "$sf_org" --json > "$output_file"

# Check if query was successful
if [ $? -eq 0 ]; then
    total=$(cat "$output_file" | jq -r '.result.records | length')
    echo "✅ Query completed successfully!"
    echo "📊 Total cases found: $total"
    echo "💾 Results saved to: $output_file"
    echo ""

    # Show summary by status
    echo "Status breakdown:"
    cat "$output_file" | jq -r '.result.records | group_by(.Status) | .[] | "\(length) cases: \(.[0].Status)"' | sort -rn
    echo ""

    # Show high priority cases
    high_priority=$(cat "$output_file" | jq -r '.result.records | map(select(.Priority == "High" or .Priority == "Urgent" or .Priority == "Critical")) | length')
    if [ "$high_priority" -gt 0 ]; then
        echo "⚠️  High priority cases: $high_priority"
    fi
else
    echo "❌ Query failed. Check your Salesforce authentication."
    exit 1
fi
