---
name: snowflake-is-usage
description: Pull Integration Service API usage data from Snowflake for the last 3 months
user-invocable: true
argument-hint: "[customer_name] [username]"
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
---

# Snowflake Integration Service Usage Skill

Query Snowflake to retrieve Integration Service API usage data grouped by subsidiary, connector key, and originator for the last 3 months. Supports customer-specific queries with intelligent caching.

## Configuration
- **Snowflake Account**: UIPATH-UIPATH_OBSERVABILITY.snowflakecomputing.com
- **Authentication**: SSO via SnowSQL CLI
- **Database**: PROD_ELEMENTSERVICE
- **Time Range**: Last 3 months
- **Query Type**: Read-only (API usage analytics)
- **Caching**: Customer-specific data is cached locally

## Instructions

When this skill is invoked:

1. **Parse arguments**:
   - If invoked as `/snowflake-is-usage "Customer Name" your.email@company.com`, use customer name and username
   - If invoked as `/snowflake-is-usage "Customer Name"`, use customer name and check for cached data or prompt for username
   - If invoked as `/snowflake-is-usage your.email@company.com`, use username only (query all customers)
   - If no arguments, check SNOWFLAKE_USER environment variable or ask user

2. **Check cache first** (if customer name provided):
   - Look for files in `~/Documents/uipath-integration-analyst/snowflake-data/` matching pattern: `snowflake_is_usage_*<customer_normalized>*.csv`
   - Normalize customer name: lowercase, replace spaces/commas/periods with underscores
   - Use `stat -f %m` (macOS) or `stat -c %Y` (Linux) to get modification timestamp
   - Calculate age: `current_time - file_mtime`
   - If cache file exists AND age < 7 days (604800 seconds):
     - **Validate data exists**: Check if CSV has data rows beyond header (line count > 3, since lines 1-2 are auth output, line 3 is header)
     - If data validation passes:
       - Display: "✓ Using cached data from <file> (X days old)"
       - Skip to step 4 (display results from cache)
     - If data validation fails (no data rows):
       - Display: "⚠️ Cached file is empty, querying fresh data..."
       - Proceed to step 3
   - Otherwise, proceed to step 3

3. **Execute the script**:
   ```bash
   bash ~/Documents/uipath-integration-analyst/snowflake-is-usage.sh "<customer_name>" <username>
   ```
   Examples:
   ```bash
   # Query specific customer (checks cache first)
   bash ~/Documents/uipath-integration-analyst/snowflake-is-usage.sh "PepsiCo, Inc" your.email@company.com

   # Query all customers (no cache check)
   bash ~/Documents/uipath-integration-analyst/snowflake-is-usage.sh your.email@company.com
   ```

4. **Display results**:
   - If using cached data, the script will display a summary from the cached file
   - If querying Snowflake, the script saves results to:
     - With customer: `~/Documents/uipath-integration-analyst/snowflake-data/snowflake_is_usage_<timestamp>_<customer_normalized>.csv`
     - Without customer: `~/Documents/uipath-integration-analyst/snowflake-data/snowflake_is_usage_<timestamp>.csv`
   - After the script completes, read the CSV file and create a formatted summary showing:
     - For customer-specific queries: Top connector keys by usage and breakdown by GroupedOriginator
     - For all customers: Top subsidiaries by API usage
     - Total API usage count

5. **Handle errors**:
   - If the script fails (exit code != 0), inform the user about authentication issues
   - Suggest running: `snowsql -a UIPATH-UIPATH_OBSERVABILITY -u <username> --authenticator externalbrowser`

## Query Details

The query analyzes:
- **Source**: Integration Service telemetry data
- **Event Type**: API.Request events with RequestType = 'vendor'
- **Activation Type**: AutomationCloud only
- **Time Range**: Last 3 months from current date
- **Grouping**: Subsidiary name, connector key, and grouped originator
- **Metrics**: API usage count per group
- **Filtering**: Optional WHERE clause filters by subsidiary name using ILIKE (partial, case-insensitive matching)
- **Limit**: 500 records to prevent overly large result sets

### Originator Groups:
- **Maestro**: UiPath.PO, Uipath.AgenticOrchestration.Designer
- **Agents**: UiPath.AgentService, Uipath.Agent.Designer
- **IS Pollers**: UiPath.IntegrationService.Poller
- **Robot**: Any originator containing 'robot'
- **API Workflows**: api-workflow
- **Studio**: UiPath.Studio
- **Studio Web**: Originators containing 'StudioWeb'
- **Connections OR Trigger Creation**: Connection service, triggers, webhooks, Ezra
- **Autopilot**: Autopilot
- **Tests**: integration-tests
- **ConnectionsTokenRefreshJob**: ElementService.OauthTokenRefreshJob
- **IS Internal Chained Calls**: ElementService.Soba, denali, folder-auth
- **Others**: Everything else

## Notes
- Requires SnowSQL CLI to be installed
- Requires active SSO authentication to Snowflake
- Results are saved in ~/Documents/uipath-integration-analyst/snowflake-data/ directory with timestamp
- Query is read-only and does not modify any data
- Query joins telemetry data with organization and subsidiary information
- Focuses on vendor API requests (external connector usage)
