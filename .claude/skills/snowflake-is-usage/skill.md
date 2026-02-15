---
name: snowflake-is-usage
description: Pull Integration Service API usage data from Snowflake for the last 3 months
user-invocable: true
argument-hint: "[customer_name]"
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
---

# Snowflake Integration Service Usage Skill

Query Snowflake to retrieve Integration Service API usage data grouped by subsidiary, connector key, and originator for the last 3 months. Supports customer-specific queries with intelligent caching.

## Configuration
- **Snowflake Account**: Configured in .env file (SNOWFLAKE_ACCOUNT)
- **Snowflake User**: Configured in .env file (SNOWFLAKE_USER)
- **Project Directory**: Configured in .env file (PROJECT_DIR)
- **Authentication**: SSO via SnowSQL CLI
- **Database**: PROD_ELEMENTSERVICE
- **Time Range**: Last 3 months
- **Query Type**: Read-only (API usage analytics)
- **Caching**: Customer-specific data is cached locally (7 days)

## Instructions

When this skill is invoked:

1. **Parse arguments**:
   - Optional argument: Customer name (e.g., `/snowflake-is-usage "PepsiCo, Inc"`)
   - If no argument provided: Query all customers
   - Username is read from .env file (SNOWFLAKE_USER)

2. **Check cache first** (if customer name provided):
   - Look for files in `${PROJECT_DIR}/snowflake-data/` matching pattern: `snowflake_is_usage_*<customer_normalized>*.csv`
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
   bash ${PROJECT_DIR}/snowflake-is-usage.sh "<customer_name>"
   ```
   Examples:
   ```bash
   # Query specific customer (checks cache first)
   bash ${PROJECT_DIR}/snowflake-is-usage.sh "PepsiCo, Inc"

   # Query all customers (no cache check, no customer filter)
   bash ${PROJECT_DIR}/snowflake-is-usage.sh
   ```

   Note: The script reads SNOWFLAKE_USER from .env file automatically.

4. **Display results**:
   - If using cached data, the script will display a summary from the cached file
   - If querying Snowflake, the script saves results to:
     - With customer: `${PROJECT_DIR}/snowflake-data/snowflake_is_usage_<timestamp>_<customer_normalized>.csv`
     - Without customer: `${PROJECT_DIR}/snowflake-data/snowflake_is_usage_<timestamp>.csv`
   - After the script completes, read the CSV file and create a formatted summary showing:
     - For customer-specific queries: Top connector keys by usage and breakdown by GroupedOriginator
     - For all customers: Top subsidiaries by API usage
     - Total API usage count

5. **Handle errors**:
   - If SNOWFLAKE_USER not configured: Inform user to set it in .env file
   - If the script fails (exit code != 0), inform the user about authentication issues
   - Suggest running: `snowsql -a ${SNOWFLAKE_ACCOUNT} -u ${SNOWFLAKE_USER} --authenticator externalbrowser`

## Data Source

**Snowflake Tables**:
- **Primary**: `PROD_ELEMENTSERVICE.APPINS.INTEGRATIONSERVICE_TELEMETRY_STANDARDIZED`
  - Contains Integration Service API telemetry events
  - Fields: eventname, originator, connectorkey, RequestType, Date, cloudorganizationid, activationtype
- **Joins**:
  - `prod_customer360.standard.cloudorganizationexclusivesubcodehistory` - Organization subscription mapping
  - `prod_customer360.constants.SubscriptionCodeAttributes` - Subscription metadata
  - `prod_customer360.standard.cloudorganizationtosubsidiarymap` - Org to subsidiary mapping
  - `prod_customer360.standard.SubsidiaryHistory` - Subsidiary names and details

## Query Details

The query analyzes:
- **SQL Files**:
  - With customer filter: `sql/is_usage_query_with_customer.sql`
  - All customers: `sql/is_usage_query_all.sql`
- **Parameter**: `{CUSTOMER_NAME}` - replaced by script with actual customer name (when filtering)
- **Account**: UIPATH-UIPATH_OBSERVABILITY.snowflakecomputing.com
- **Database**: PROD_ELEMENTSERVICE
- **Event Type**: API.Request events with RequestType = 'vendor'
- **Activation Type**: AutomationCloud only
- **Time Range**: Last 3 months from current date (`Date >= DATEADD(month, -3, CURRENT_DATE)`)
- **Grouping**: Subsidiary name, connector key, and grouped originator
- **Metrics**: API usage count per group
- **Filtering**: Optional WHERE clause filters by subsidiary name using ILIKE (partial, case-insensitive matching)
- **Limit**: 500 records (customer-specific query only) to prevent overly large result sets
- **Authentication**: SSO via `snowsql --authenticator externalbrowser`

## Direct Script Usage

If you need to run the script directly (bypassing the skill):

```bash
# Query specific customer (checks cache first, username from .env)
bash ${PROJECT_DIR}/snowflake-is-usage.sh "Customer Name"

# Query all customers (no cache check, no customer filter)
bash ${PROJECT_DIR}/snowflake-is-usage.sh

# Examples
bash ${PROJECT_DIR}/snowflake-is-usage.sh "PepsiCo, Inc"
bash ${PROJECT_DIR}/snowflake-is-usage.sh
```

**Prerequisites**:
- Set SNOWFLAKE_USER in .env file
- Set PROJECT_DIR in .env file (or script uses current directory)

**Script Output**:
- With customer: `${PROJECT_DIR}/snowflake-data/snowflake_is_usage_<timestamp>_<customer_normalized>.csv`
- Without customer: `${PROJECT_DIR}/snowflake-data/snowflake_is_usage_<timestamp>.csv`
- Console output: Total records, top connectors/subsidiaries, total API usage
- Cache summary: If using cached data, shows file path and age
- Exit code: 0 for success, 1 for errors (including missing SNOWFLAKE_USER)

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

## Data Parsing Patterns

### IS Usage CSV Format
- Skip first 2 lines (auth output from Snowflake SSO), header starts at line 3
- Columns: `"NAME","CONNECTORKEY","GROUPEDORIGINATOR","APIUSAGE"`
- Data rows contain quoted values separated by commas
- Example: `"T-Mobile.","uipath-snowflake-snowflake","Robot","1571029534"`

### Calculating Billable API Usage

**IS API Licensing Rules (CRITICAL):**
- **IS Poller calls do NOT count toward API licensing limits**
- **IS Internal Chained Calls do NOT count toward API licensing limits**
- Only non-poller originators are billable: Robot, Studio, Studio Web, Connections, Maestro, Agents, Autopilot, API Workflows, Tests, ConnectionsTokenRefreshJob, Others

**Billable Calculation:**
```
Billable API Calls = Total API Calls - IS Pollers - IS Internal Chained Calls
```

**Capacity Utilization:**
```
Capacity Utilization = Billable API Calls / Licensed API Capacity
```

**Important Notes:**
- High IS Poller usage (>90%) is an **efficiency concern**, NOT a licensing issue
- When assessing API overages, only compare billable (non-poller) calls against licensed capacity
- Licensed API capacity comes from license data (PRODUCTORSERVICENAME = 'API Calls')

## Notes
- **Configuration**: Requires SNOWFLAKE_USER and PROJECT_DIR to be set in .env file
- Requires SnowSQL CLI to be installed
- Requires active SSO authentication to Snowflake
- Results are saved in ${PROJECT_DIR}/snowflake-data/ directory with timestamp
- Query is read-only and does not modify any data
- Query joins telemetry data with organization and subsidiary information
- Focuses on vendor API requests (external connector usage)
- Cache files older than 7 days or with no data rows trigger fresh queries automatically
