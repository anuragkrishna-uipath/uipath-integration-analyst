---
name: snowflake-is-usage
description: Pull Integration Service API usage data from Snowflake for the last 3 months
user-invocable: true
argument-hint: "[username]"
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# Snowflake Integration Service Usage Skill

Query Snowflake to retrieve Integration Service API usage data grouped by subsidiary, connector key, and originator for the last 3 months.

## Configuration
- **Snowflake Account**: UIPATH-UIPATH_OBSERVABILITY.snowflakecomputing.com
- **Authentication**: SSO via SnowSQL CLI
- **Database**: PROD_ELEMENTSERVICE
- **Time Range**: Last 3 months
- **Query Type**: Read-only (API usage analytics)

## Instructions

When this skill is invoked, execute the bash script at `~/Documents/pm-assistant/snowflake-is-usage.sh`:

1. **Get username**:
   - If an argument is provided (e.g., `/snowflake-is-usage your.email@company.com`), use that as the username
   - If no argument is provided, check if SNOWFLAKE_USER environment variable is set
   - If neither is available, ask the user for their UiPath email address using AskUserQuestion

2. **Execute the script**:
   ```bash
   bash ~/Documents/pm-assistant/snowflake-is-usage.sh <username>
   ```
   Example:
   ```bash
   bash ~/Documents/pm-assistant/snowflake-is-usage.sh your.email@company.com
   ```

3. **Display results**:
   - The script will output a summary with total records and top subsidiaries
   - The script saves detailed CSV results to `~/Documents/pm-assistant/snowflake-data/snowflake_is_usage_<timestamp>.csv`
   - After the script completes, read the CSV file and create a formatted summary showing:
     - Top 10 subsidiaries by API usage
     - Breakdown by GroupedOriginator (Maestro, Agents, IS Pollers, Robot, etc.)
     - Top connector keys by usage
     - Total API usage count

4. **Handle errors**:
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
- Results are saved in ~/Documents/pm-assistant/snowflake-data/ directory with timestamp
- Query is read-only and does not modify any data
- Query joins telemetry data with organization and subsidiary information
- Focuses on vendor API requests (external connector usage)
