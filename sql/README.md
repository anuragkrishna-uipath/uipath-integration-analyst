# SQL Queries

This directory contains SQL query files used by Snowflake data extraction scripts.

## Files

### `subsidiary_license_query.sql`
- **Purpose**: Retrieve license consumption data for a specific subsidiary
- **Used by**: `subsidiary-license-info.sh`
- **Database**: `prod_customer360.customerprofile`
- **Table**: `CustomerSubsidiaryLicenseProfile`
- **Parameter**: `{SUBSIDIARY_NAME}` - Subsidiary name to search for (partial match)
- **Returns**: All columns for matching subsidiaries

### `is_usage_query_with_customer.sql`
- **Purpose**: Retrieve Integration Service API usage for a specific customer
- **Used by**: `snowflake-usage.sh` (with customer filter)
- **Database**: `PROD_ELEMENTSERVICE`
- **Time Range**: Last 3 months
- **Parameter**: `{CUSTOMER_NAME}` - Customer name to filter by (partial match)
- **Limit**: 500 records
- **Returns**: Subsidiary name, connector key, grouped originator, API usage count

### `is_usage_query_all.sql`
- **Purpose**: Retrieve Integration Service API usage for all customers
- **Used by**: `snowflake-usage.sh` (without customer filter)
- **Database**: `PROD_ELEMENTSERVICE`
- **Time Range**: Last 3 months
- **No Limit**: Returns all matching records
- **Returns**: Subsidiary name, connector key, grouped originator, API usage count

## Parameter Substitution

Scripts use `sed` to replace placeholder parameters in SQL files:
- `{SUBSIDIARY_NAME}` → Actual subsidiary name provided by user
- `{CUSTOMER_NAME}` → Actual customer name provided by user

Example:
```bash
QUERY=$(cat "$SQL_FILE" | sed "s/{SUBSIDIARY_NAME}/$subsidiary_name/g")
```

## Modifying Queries

To modify a query:
1. Edit the appropriate `.sql` file in this directory
2. Test the query manually in Snowflake first
3. Ensure parameter placeholders (`{PARAMETER_NAME}`) are preserved
4. No need to restart scripts - changes take effect immediately

## Query Design Patterns

All queries follow these patterns:
- Use ILIKE for case-insensitive partial matching on names
- Use proper JOINs to link telemetry with organization/subsidiary data
- Filter by date ranges using DATEADD functions
- Group and aggregate results for better analysis
- Include proper comments explaining the query purpose
