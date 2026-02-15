---
name: sf-integration-cases
description: Pull Salesforce Integration Service cases for the last X days, optionally filtered by customer name
user-invocable: true
argument-hint: "[days] [customer_name]"
allowed-tools: Bash, Read, Write, Glob
---

# Salesforce Integration Service Cases Skill

Pull Integration Service cases from Salesforce for a specified time period using Product Component filter, with optional customer name filtering.

## Configuration
- **Salesforce Org**: uipath (uipath.my.salesforce.com)
- **Authentication**: SSO via `sf org login web`
- **Default Days**: 7 days (if not specified)
- **Default Customer**: All customers (if not specified)
- **Filter Fields**:
  - Deployment_Type_Product_Component__c LIKE '%Integration Service%'
  - Account.Name LIKE '%customer_name%' (optional)

## Data Source

**Salesforce Object**: Case
- **Org**: uipath.my.salesforce.com
- **Target Org Alias**: uipath
- **Query Fields**:
  - Core: CaseNumber, Subject, Status, Priority, CreatedDate, Description
  - Related: Account.Name (customer name), Owner.Name (case owner)
  - Custom: Solution__c (resolution details), Deployment_Type_Product_Component__c (product filter)
- **Filter Logic**:
  - `Deployment_Type_Product_Component__c LIKE '%Integration Service%'` (catches "Integration Service", "Integration Services", etc.)
  - `CreatedDate = LAST_N_DAYS:N` (configurable time range)
  - `Account.Name LIKE '%customer_name%'` (optional customer filter, partial matching)
- **Authentication**: SSO via Salesforce CLI v2 (`sf` command)

## Instructions

When this skill is invoked:

1. **Parse the arguments**:
   - First argument: number of days (default: 7 if not provided)
   - Second argument: customer name (optional, fetches all customers if not provided)
   - Examples:
     - `/sf-integration-cases 14` → 14 days, all customers
     - `/sf-integration-cases 7 Microsoft` → 7 days, Microsoft only
     - `/sf-integration-cases 30 "Acme Corp"` → 30 days, Acme Corp only

2. **Check cache first** (if customer name provided):
   - Look for files in `${PROJECT_DIR}/is-cases/` matching pattern: `sf_integration_cases_*days_<customer_normalized>_*.json`
   - Normalize customer name: lowercase, replace spaces/commas/periods with underscores
   - Use `stat -f %m` (macOS) or `stat -c %Y` (Linux) to get modification timestamp
   - Calculate age: `current_time - file_mtime`
   - If cache file exists AND age < 24 hours (86400 seconds):
     - **Validate data exists**: Read JSON and check if `result.totalSize > 0` (has actual records)
     - If data validation passes:
       - Display: "✓ Using cached data from <file> (X hours old)"
       - Skip to step 4 (display results from cache)
     - If data validation fails (totalSize = 0 or no records):
       - Display: "⚠️ Cached file is empty, querying fresh data..."
       - Proceed to step 3
   - Otherwise, proceed to step 3

3. **Execute the script**:
   ```bash
   bash ${PROJECT_DIR}/scripts/sf-integration-cases.sh <days> <customer_name>
   ```
   Examples:
   ```bash
   bash ${PROJECT_DIR}/scripts/sf-integration-cases.sh 7
   bash ${PROJECT_DIR}/scripts/sf-integration-cases.sh 14 "Microsoft"
   bash ${PROJECT_DIR}/scripts/sf-integration-cases.sh 30 "Acme Corp"
   ```

4. **Display results**:
   - The script will output a summary with total cases, status breakdown, and high priority cases
   - The script saves detailed JSON results to:
     - All customers: `${PROJECT_DIR}/is-cases/sf_integration_cases_<days>days_<timestamp>.json`
     - Specific customer: `${PROJECT_DIR}/is-cases/sf_integration_cases_<days>days_<customer_slug>_<timestamp>.json`
   - After the script completes, read the JSON file and create a formatted table showing:
     - Case Number
     - Subject (truncated to 50 chars if needed)
     - Status
     - Priority
     - Created Date
     - Account/Customer Name
     - Owner Name
     - Solution (if available)
   - Highlight high/critical priority cases with ⚠️ marker

5. **Handle errors**:
   - If the script fails (exit code != 0), inform the user about authentication issues
   - Suggest running: `sf org login web --instance-url https://uipath.my.salesforce.com --alias uipath`

## Direct Script Usage

If you need to run the script directly (bypassing the skill):

```bash
# Query cases with time range only (all customers)
bash ${PROJECT_DIR}/scripts/sf-integration-cases.sh <days>

# Query cases for specific customer
bash ${PROJECT_DIR}/scripts/sf-integration-cases.sh <days> "Customer Name"

# Examples
bash ${PROJECT_DIR}/scripts/sf-integration-cases.sh 7                    # Last 7 days, all customers
bash ${PROJECT_DIR}/scripts/sf-integration-cases.sh 14 "Microsoft"      # Last 14 days, Microsoft only
bash ${PROJECT_DIR}/scripts/sf-integration-cases.sh 180 "Acme Corp"     # Last 180 days, Acme Corp
```

**Script Output**:
- All customers: `${PROJECT_DIR}/is-cases/sf_integration_cases_<days>days_<timestamp>.json`
- Specific customer: `${PROJECT_DIR}/is-cases/sf_integration_cases_<days>days_<customer_slug>_<timestamp>.json`
- Console output: Total cases, status breakdown, priority distribution, high-priority case details
- Exit code: 0 for success, 1 for errors

## Example Usage

```bash
# Time-based queries (all customers)
/sf-integration-cases              # Last 7 days, all customers (default)
/sf-integration-cases 14           # Last 14 days, all customers
/sf-integration-cases 1            # Last 1 day, all customers
/sf-integration-cases 30           # Last 30 days, all customers

# Customer-specific queries
/sf-integration-cases 7 Microsoft         # Last 7 days, Microsoft only
/sf-integration-cases 14 "Acme Corp"      # Last 14 days, Acme Corp only
/sf-integration-cases 30 Google           # Last 30 days, Google only
/sf-integration-cases 1 Amazon            # Last 1 day, Amazon only
```

## Data Parsing Patterns

### Support Ticket JSON Format
- Structure:
  ```json
  {
    "status": 0,
    "result": {
      "records": [...],
      "totalSize": N,
      "done": true
    },
    "warnings": []
  }
  ```
- **Validation**: Check `result.totalSize > 0` to ensure data exists
- **Empty result**: `totalSize = 0` or `records = []` indicates no matching cases found

### Key Fields in Records
- `CaseNumber`: Unique case identifier
- `Subject`: Brief description of the issue
- `Status`: Current status (New, In Progress, Closed, etc.)
- `Priority`: Priority level (Low, Medium, High, Critical)
- `CreatedDate`: ISO timestamp when case was created
- `Account.Name`: Customer/company name
- `Owner.Name`: Case owner/assignee
- `Solution__c`: Resolution details (may be null for open cases)
- `Description`: Detailed problem description

### Parsing Best Practices
- Use Python's `json` module to parse the file
- Check `result.totalSize` before accessing `result.records`
- Handle null values for optional fields like `Solution__c`
- Format dates from ISO format to readable format

## Notes
- Requires Salesforce CLI (sf) to be installed
- Requires active authentication to uipath.my.salesforce.com via SSO
- Results are saved in ${PROJECT_DIR}/is-cases/ directory with timestamp
- Customer name filtering uses partial matching (LIKE '%customer_name%')
- Customer names with spaces should be quoted (e.g., "Acme Corp")
- Queries cases where Deployment_Type_Product_Component__c contains "Integration Service"
- The query uses LIKE '%Integration Service%' to catch variations like "Integration Services", "Integration Service", etc.
- Fetches the Solution__c field to capture case resolutions
- Fetches Account.Name to display customer information
- Cache files older than 24 hours or with no records trigger fresh queries automatically
