---
name: sf-cases
description: Pull Salesforce cases for the last X days, optionally filtered by customer name and product component
user-invocable: true
argument-hint: "[days] [customer_name] [product_filter]"
allowed-tools: Bash, Read, Write, Glob
---

# Salesforce Cases Skill

Pull support cases from Salesforce for a specified time period, with optional customer name and product component filtering.

## Configuration
- **Salesforce Org**: uipath (uipath.my.salesforce.com)
- **Authentication**: SSO via `sf org login web`
- **Default Days**: 7 days (if not specified)
- **Default Customer**: All customers (if not specified)
- **Default Product**: All products (if not specified)
- **Filter Fields**:
  - Deployment_Type_Product_Component__c LIKE '%product_filter%' (optional)
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
  - `Deployment_Type_Product_Component__c LIKE '%product_filter%'` (optional - only when product_filter provided)
  - `CreatedDate = LAST_N_DAYS:N` (configurable time range)
  - `Account.Name LIKE '%customer_name%'` (optional customer filter, partial matching)
- **Authentication**: SSO via Salesforce CLI v2 (`sf` command)

## Scope Boundary (CRITICAL)

**This skill does EXACTLY what is requested — nothing more, nothing less.**

- If the user provides filters (customer name, product component), query with EXACTLY those filters
- If 0 results are returned, report "No cases found" with the exact filters used and STOP
- **Do NOT** broaden the search by removing filters (e.g., do not drop the product filter to show "all cases" for the customer)
- **Do NOT** suggest or run alternative queries unless the user explicitly asks
- **Do NOT** add supplementary analysis beyond what the query returns
- The user chose specific filters for a reason — respect that intent

**Example**: If the user asks `/sf-cases 14 "Pepsico" "Integration Service"` and 0 results are found, the correct response is:
> No Salesforce cases found for Pepsico with product component "Integration Service" in the last 14 days.

And then STOP. Do not search for Pepsico cases without the Integration Service filter.

## Instructions

When this skill is invoked:

1. **Parse the arguments**:
   - First argument: number of days (default: 7 if not provided)
   - Second argument: customer name (optional, fetches all customers if not provided)
   - Third argument: product component filter (optional, fetches all products if not provided)
   - **If no arguments provided**: Show usage help with sample queries and STOP. Display:
     ```
     ## Salesforce Cases (`/sf-cases`)

     Pull support cases from Salesforce with optional customer and product filters.

     ### Options
     | Argument | Required | Description | Default |
     |----------|----------|-------------|---------|
     | days | No | Number of days to look back | 7 |
     | customer_name | No | Customer name (partial match) | All customers |
     | product_filter | No | Product component filter (partial match) | All products |

     ### Sample Queries
     /sf-cases                                        # Last 7 days, all customers, all products
     /sf-cases 14                                     # Last 14 days, all customers
     /sf-cases 30 "PepsiCo"                           # Last 30 days, PepsiCo only
     /sf-cases 7 "Microsoft" "Integration Service"    # Last 7 days, Microsoft, IS only
     /sf-cases 90 "Acme Corp" "Document Understanding" # Last 90 days, Acme, DU only

     ### Notes
     - Customer names use partial matching (e.g., "Pepsi" matches "PepsiCo, Inc")
     - Product filter uses partial matching (e.g., "Integration" matches "Integration Services")
     - Cache: 24 hours per customer/product combination
     - Data source: Salesforce (uipath.my.salesforce.com)
     ```
   - Examples when arguments ARE provided:
     - `/sf-cases 14` → 14 days, all customers, all products
     - `/sf-cases 7 Microsoft` → 7 days, Microsoft only, all products
     - `/sf-cases 30 "Acme Corp" "Integration Service"` → 30 days, Acme Corp, Integration Service only

2. **Check cache first** (if customer name provided):
   - Look for files in `${PROJECT_DIR}/sf-cases/` matching pattern: `sf_cases_*days_[<product_normalized>_]<customer_normalized>_*.json`
   - Normalize customer name: lowercase, replace spaces/commas/periods with underscores
   - Normalize product filter: lowercase, replace spaces with underscores
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
   bash ${PROJECT_DIR}/scripts/sf-cases.sh <days> <customer_name> <product_filter>
   ```
   Examples:
   ```bash
   bash ${PROJECT_DIR}/scripts/sf-cases.sh 7
   bash ${PROJECT_DIR}/scripts/sf-cases.sh 14 "Microsoft"
   bash ${PROJECT_DIR}/scripts/sf-cases.sh 30 "Acme Corp" "Integration Service"
   ```

4. **Clean up stale cache files** (after successful fresh pull):
   - After the script succeeds (exit code 0), identify the newly created JSON file (the one just written by the script)
   - Find all older files in `${PROJECT_DIR}/sf-cases/` matching the same pattern: `sf_cases_*days_[<product_normalized>_]<customer_normalized>_*.json`
   - Delete all matching files EXCEPT the newly created one
   - Display: "🗑️ Cleaned up N stale cache file(s)"
   - If no older files exist, skip silently (no message needed)

5. **Display results**:
   - The script will output a summary with total cases, status breakdown, and high priority cases
   - The script saves detailed JSON results to:
     - `${PROJECT_DIR}/sf-cases/sf_cases_<days>days_[<product_slug>_][<customer_slug>_]<timestamp>.json`
   - After the script completes, read the JSON file and create a formatted table showing:
     - Case Number
     - Subject (truncated to 50 chars if needed)
     - Status
     - Priority
     - Created Date
     - Account/Customer Name
     - Owner Name
     - Product Component
     - Solution (if available)
   - Highlight high/critical priority cases with ⚠️ marker
   - If no product filter was specified, group cases by Deployment_Type_Product_Component__c for overview

6. **Handle errors**:
   - If the script fails (exit code != 0), inform the user about authentication issues
   - Suggest running: `sf org login web --instance-url https://uipath.my.salesforce.com --alias uipath`
   - Do NOT delete any existing cache files on error (keep stale data as fallback)

## Direct Script Usage

If you need to run the script directly (bypassing the skill):

```bash
# Query all cases (all customers, all products)
bash ${PROJECT_DIR}/scripts/sf-cases.sh <days>

# Query cases for specific customer (all products)
bash ${PROJECT_DIR}/scripts/sf-cases.sh <days> "Customer Name"

# Query cases for specific customer and product
bash ${PROJECT_DIR}/scripts/sf-cases.sh <days> "Customer Name" "Product Filter"

# Examples
bash ${PROJECT_DIR}/scripts/sf-cases.sh 7                                         # Last 7 days, all
bash ${PROJECT_DIR}/scripts/sf-cases.sh 14 "Microsoft"                            # Last 14 days, Microsoft, all products
bash ${PROJECT_DIR}/scripts/sf-cases.sh 180 "Acme Corp" "Integration Service"     # Last 180 days, Acme Corp, IS only
```

**Script Output**:
- `${PROJECT_DIR}/sf-cases/sf_cases_<days>days_[<product_slug>_][<customer_slug>_]<timestamp>.json`
- Console output: Total cases, status breakdown, priority distribution, high-priority case details
- Exit code: 0 for success, 1 for errors

## Example Usage

```bash
# Time-based queries (all customers, all products)
/sf-cases              # Last 7 days, all customers, all products (default)
/sf-cases 14           # Last 14 days, all customers, all products
/sf-cases 30           # Last 30 days, all customers, all products

# Customer-specific queries (all products)
/sf-cases 7 Microsoft         # Last 7 days, Microsoft only, all products
/sf-cases 14 "Acme Corp"      # Last 14 days, Acme Corp only, all products

# Customer and product-specific queries
/sf-cases 7 Microsoft "Integration Service"      # Last 7 days, Microsoft, IS only
/sf-cases 30 "Acme Corp" "Integration Service"   # Last 30 days, Acme Corp, IS only
/sf-cases 14 Google "Document Understanding"     # Last 14 days, Google, DU only
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
- `Deployment_Type_Product_Component__c`: Product component (useful for grouping when no product filter)

### Parsing Best Practices
- Use Python's `json` module to parse the file
- Check `result.totalSize` before accessing `result.records`
- Handle null values for optional fields like `Solution__c`
- Format dates from ISO format to readable format
- When no product filter is used, group results by `Deployment_Type_Product_Component__c`

## Notes
- Requires Salesforce CLI (sf) to be installed
- Requires active authentication to uipath.my.salesforce.com via SSO
- Results are saved in ${PROJECT_DIR}/sf-cases/ directory with timestamp
- Customer name filtering uses partial matching (LIKE '%customer_name%')
- Product filter uses partial matching (LIKE '%product_filter%')
- Customer names with spaces should be quoted (e.g., "Acme Corp")
- When product_filter is omitted, ALL cases are returned regardless of product component
- When product_filter is provided (e.g., "Integration Service"), only matching cases are returned
- Fetches the Solution__c field to capture case resolutions
- Fetches Account.Name to display customer information
- Cache files older than 24 hours or with no records trigger fresh queries automatically
- Stale cache files are automatically deleted after a successful fresh pull (only the latest file is kept)
