---
name: snowflake-customer-license-info
description: Pull customer/subsidiary license consumption information from Snowflake
user-invocable: true
argument-hint: "[subsidiary_name]"
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
---

# Snowflake Customer License Information Skill

Query Snowflake to retrieve license consumption information for a specific customer subsidiary.

## Configuration
- **Snowflake Account**: UIPATH-UIPATH_OBSERVABILITY.snowflakecomputing.com
- **Authentication**: SSO via SnowSQL CLI
- **Database**: prod_customer360
- **Schema**: customerprofile
- **Table**: CustomerSubsidiaryLicenseProfile
- **Query Type**: Read-only (license consumption data)

## Instructions

When this skill is invoked:

1. **Get parameters**:
   - First argument (required): Subsidiary name (e.g., "PepsiCo, Inc", "Microsoft Corporation")
   - Second argument (optional): Snowflake username (defaults to SNOWFLAKE_USER environment variable)
   - If subsidiary name not provided, ask the user using AskUserQuestion
   - If username not provided and SNOWFLAKE_USER not set, ask the user using AskUserQuestion

2. **Check cache first**:
   - Look for files in `~/Documents/uipath-integration-analyst/snowflake-data/` matching pattern: `subsidiary_license_<subsidiary_normalized>_*.csv`
   - Normalize subsidiary name: lowercase, replace spaces/commas/periods with underscores
   - If cache file exists (any age):
     - **Validate data exists**: Check if CSV has data rows beyond header (line count > 3, since lines 1-2 are auth output, line 3 is header)
     - If data validation passes:
       - Display: "✓ Using cached data from <file>"
       - Skip to step 4 (display results from cache)
     - If data validation fails (no data rows):
       - Display: "⚠️ Cached file is empty, querying fresh data..."
       - Proceed to step 3
   - Otherwise, proceed to step 3

3. **Execute the script**:
   ```bash
   bash ~/Documents/uipath-integration-analyst/subsidiary-license-info.sh "<subsidiary_name>" "<username>"
   ```
   Examples:
   ```bash
   bash ~/Documents/uipath-integration-analyst/subsidiary-license-info.sh "PepsiCo, Inc" "your.email@company.com"
   bash ~/Documents/uipath-integration-analyst/subsidiary-license-info.sh "Microsoft Corporation"
   ```

4. **Display results**:
   - The script will output a summary with total records found
   - The script saves detailed CSV results to `~/Documents/uipath-integration-analyst/snowflake-data/subsidiary_license_<subsidiary_slug>_<timestamp>.csv`
   - After the script completes, read the CSV file and create a formatted table showing:
     - Subsidiary Name
     - Product/SKU information
     - License counts (Consumed, Allocated, Available)
     - License types and tiers
     - Subscription details
     - Any relevant license metrics

5. **Handle errors**:
   - If the script fails (exit code != 0), inform the user about authentication issues
   - Suggest running: `snowsql -a UIPATH-UIPATH_OBSERVABILITY -u <username> --authenticator externalbrowser`
   - If no results found, inform the user and suggest checking the subsidiary name spelling

## Query Details

The query retrieves all columns from CustomerSubsidiaryLicenseProfile for the specified subsidiary:
- **Source**: Customer360 database, customer profile schema
- **Filter**: SUBSIDIARYNAME ILIKE '%<subsidiary_name>%' (partial, case-insensitive matching)
- **Limit**: None (retrieves all matching records)
- **Scope**: All license consumption data for matching subsidiaries
- **Use Case**: Understanding customer license usage, allocation, and consumption patterns

## Example Usage

```bash
/snowflake-customer-license-info "PepsiCo, Inc"              # Query PepsiCo license info
/snowflake-customer-license-info "Microsoft Corporation"     # Query Microsoft license info
/snowflake-customer-license-info "Acme Corp"                 # Query Acme Corp license info
```

## Notes
- Requires SnowSQL CLI to be installed
- Requires active SSO authentication to Snowflake
- Results are saved in ~/Documents/uipath-integration-analyst/snowflake-data/ directory with timestamp
- Query is read-only and does not modify any data
- **Uses partial matching (ILIKE)**: Query matches any subsidiary name containing the search term (case-insensitive)
- Use quotes around subsidiary names with spaces or special characters
- For ambiguous names (e.g., "T-Mobile" matches "T-Mobile USA, Inc", "T-Mobile Polska"), results may include multiple subsidiaries
- No record limit - retrieves all matching records (large customers may return thousands of records)
