---
name: snowflake-usage
description: Query Snowflake usage data by module (Integration Service, etc.) — extensible via snowflake-modules.conf
user-invocable: true
argument-hint: "[module] [customer_name]"
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
---

# Snowflake Usage Query Skill

Query Snowflake for product usage data. Supports multiple modules defined in `snowflake-modules.conf`. Each module has its own SQL queries, caching policy, and output format.

## Configuration
- **Snowflake Account**: Configured in .env file (SNOWFLAKE_ACCOUNT)
- **Snowflake User**: Configured in .env file (SNOWFLAKE_USER)
- **Project Directory**: Configured in .env file (PROJECT_DIR)
- **Authentication**: SSO via SnowSQL CLI
- **Module Config**: `${PROJECT_DIR}/snowflake-modules.conf`

## Scope Boundary (CRITICAL)

**This skill does EXACTLY what is requested — nothing more, nothing less.**

- Query usage data for the exact module and customer name provided
- If 0 results are returned, report "No data found" with the exact filters used and STOP
- **Do NOT** broaden the search by removing the customer filter or switching modules
- **Do NOT** suggest or run alternative queries unless the user explicitly asks
- **Do NOT** add supplementary analysis beyond what the query returns

## Instructions

When this skill is invoked:

1. **Parse arguments**:
   - First argument (required): Module name or alias (e.g., `integration-service` or `is`)
   - Second argument (optional): Customer name (e.g., `"PepsiCo, Inc"`)
   - If no arguments provided: Show available modules and usage help, then STOP
   - If module not recognized: Show error with available modules, then STOP

2. **Check cache** (if customer name provided):
   - Look for files in `${PROJECT_DIR}/snowflake-data/` matching the module's cache pattern
   - Cache TTL is module-specific (defined in `snowflake-modules.conf`)
   - Validate cached file has data rows beyond header
   - If valid cache exists: Display results from cache, STOP
   - Otherwise: Proceed to query

3. **Execute the script**:
   ```bash
   bash ${PROJECT_DIR}/scripts/snowflake-usage.sh <module> "<customer_name>"
   ```
   Examples:
   ```bash
   bash ${PROJECT_DIR}/scripts/snowflake-usage.sh integration-service "PepsiCo, Inc"
   bash ${PROJECT_DIR}/scripts/snowflake-usage.sh is "PepsiCo, Inc"
   bash ${PROJECT_DIR}/scripts/snowflake-usage.sh is
   bash ${PROJECT_DIR}/scripts/snowflake-usage.sh   # Show help
   ```

4. **Clean up stale cache files** (after successful fresh pull):
   - After the script succeeds (exit code 0), identify the newly created CSV file (the one just written by the script)
   - Find all older files in `${PROJECT_DIR}/snowflake-data/` matching the same module and customer pattern: `snowflake_<module_id>_*[_<customer_normalized>].csv`
   - Delete all matching files EXCEPT the newly created one
   - Display: "🗑️ Cleaned up N stale cache file(s)"
   - If no older files exist, skip silently (no message needed)

5. **Display results**:
   - Script saves CSV to `${PROJECT_DIR}/snowflake-data/snowflake_<module_id>_<timestamp>[_<customer>].csv`
   - After script completes, read the CSV and create a formatted summary
   - For module-specific interpretation, refer to the Module-Specific Notes section below

6. **Handle errors**:
   - If SNOWFLAKE_USER not configured: Inform user to set it in .env file
   - If script fails: Suggest running `snowsql -a ${SNOWFLAKE_ACCOUNT} -u ${SNOWFLAKE_USER} --authenticator externalbrowser`
   - Do NOT delete any existing cache files on error (keep stale data as fallback)

## Available Modules

Modules are defined in `${PROJECT_DIR}/snowflake-modules.conf`. Run the script with no arguments to see current modules.

### Adding a New Module

To add a new module, a PM needs to:

1. **Write 2 SQL files** in `${PROJECT_DIR}/sql/`:
   - `<name>_query_with_customer.sql` — with `{CUSTOMER_NAME}` placeholder for customer filtering
   - `<name>_query_all.sql` — without customer filter
2. **Add 1 line** to `snowflake-modules.conf`:
   ```
   module-id,alias|Display Name|One-line description|cache_days|sql_with_customer.sql|sql_all.sql
   ```
3. **Done** — the module is immediately available via `/snowflake-usage <module-id>`

## Module-Specific Notes

### integration-service (alias: is)

**Database**: PROD_ELEMENTSERVICE
**Time Range**: Last 3 months
**SQL Files**: `is_usage_query_with_customer.sql`, `is_usage_query_all.sql`
**Cache**: 7 days
**Output Columns**: NAME, CONNECTORKEY, GROUPEDORIGINATOR, APIUSAGE

#### Originator Groups
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

#### IS API Licensing Rules (CRITICAL)
- **IS Poller calls do NOT count toward API licensing limits**
- **IS Internal Chained Calls do NOT count toward API licensing limits**
- Only non-poller originators are billable: Robot, Studio, Studio Web, Connections, Maestro, Agents, Autopilot, API Workflows, Tests, ConnectionsTokenRefreshJob, Others

**Billable Calculation:**
```
Billable API Calls = Total API Calls - IS Pollers - IS Internal Chained Calls
Capacity Utilization = Billable API Calls / Licensed API Capacity
```

**Important**: High IS Poller usage (>90%) is an efficiency concern, NOT a licensing issue.

## Data Parsing Patterns

### CSV Format (Snowflake output)
- **Fresh queries**: Header on line 1, data from line 2
- **Cached files (from SSO)**: Skip first 2 lines (auth output), header at line 3, data from line 4
- Values are comma-separated and may be quoted
- Last column is typically the numeric metric (e.g., APIUSAGE)

### Parsing Best Practices
- Use Python's `csv` module for large files
- Strip quotes from values before numeric operations
- Sort by metric column descending to identify top items
- Group by relevant dimensions for summary

## Example Usage

```bash
# Show available modules
/snowflake-usage

# Integration Service queries
/snowflake-usage integration-service "PepsiCo, Inc"
/snowflake-usage is "PepsiCo, Inc"
/snowflake-usage is                    # All customers
```

## Notes
- **Configuration**: Requires SNOWFLAKE_USER and PROJECT_DIR in .env file
- Requires SnowSQL CLI installed
- Requires active SSO authentication to Snowflake
- Results saved in `${PROJECT_DIR}/snowflake-data/` with timestamp
- All queries are read-only
- Module config at `${PROJECT_DIR}/snowflake-modules.conf` — edit to add new modules
- Cache files with no data rows trigger fresh queries automatically
- Stale cache files are automatically deleted after a successful fresh pull (only the latest file is kept)
