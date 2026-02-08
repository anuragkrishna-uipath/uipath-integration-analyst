---
name: snowflake-customer-license-info
description: Pull customer/subsidiary license consumption information from Snowflake
user-invocable: true
argument-hint: "[subsidiary_name]"
allowed-tools: Bash, Read, Write, AskUserQuestion
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

When this skill is invoked, execute the bash script at `~/Documents/pm-assistant/subsidiary-license-info.sh`:

1. **Get parameters**:
   - First argument (required): Subsidiary name (e.g., "PepsiCo, Inc", "Microsoft Corporation")
   - Second argument (optional): Snowflake username (defaults to SNOWFLAKE_USER environment variable)
   - If subsidiary name not provided, ask the user using AskUserQuestion
   - If username not provided and SNOWFLAKE_USER not set, ask the user using AskUserQuestion

2. **Execute the script**:
   ```bash
   bash ~/Documents/pm-assistant/subsidiary-license-info.sh "<subsidiary_name>" "<username>"
   ```
   Examples:
   ```bash
   bash ~/Documents/pm-assistant/subsidiary-license-info.sh "PepsiCo, Inc" "your.email@company.com"
   bash ~/Documents/pm-assistant/subsidiary-license-info.sh "Microsoft Corporation"
   ```

3. **Display results**:
   - The script will output a summary with total records found
   - The script saves detailed CSV results to `~/Documents/pm-assistant/snowflake-data/subsidiary_license_<subsidiary_slug>_<timestamp>.csv`
   - After the script completes, read the CSV file and create a formatted table showing:
     - Subsidiary Name
     - Product/SKU information
     - License counts (Consumed, Allocated, Available)
     - License types and tiers
     - Subscription details
     - Any relevant license metrics

4. **Handle errors**:
   - If the script fails (exit code != 0), inform the user about authentication issues
   - Suggest running: `snowsql -a UIPATH-UIPATH_OBSERVABILITY -u <username> --authenticator externalbrowser`
   - If no results found, inform the user and suggest checking the subsidiary name spelling

## Query Details

The query retrieves all columns from CustomerSubsidiaryLicenseProfile for the specified subsidiary:
- **Source**: Customer360 database, customer profile schema
- **Filter**: SUBSIDIARYNAME = '<subsidiary_name>'
- **Scope**: All license consumption data for that subsidiary
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
- Results are saved in ~/Documents/pm-assistant/snowflake-data/ directory with timestamp
- Query is read-only and does not modify any data
- Subsidiary name must match exactly (case-sensitive)
- Use quotes around subsidiary names with spaces or special characters
- If unsure of exact subsidiary name, try partial matches or check Salesforce first
