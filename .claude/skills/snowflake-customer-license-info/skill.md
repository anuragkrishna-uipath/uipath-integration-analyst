---
name: snowflake-customer-license-info
description: Pull customer/subsidiary license consumption and ARR data from Snowflake
user-invocable: true
argument-hint: "[subsidiary_name]"
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
---

# Snowflake Customer License Information Skill

Query Snowflake to retrieve license consumption and ARR data for a specific customer subsidiary.

## Configuration
- **Snowflake Account**: Configured in .env file (SNOWFLAKE_ACCOUNT)
- **Snowflake User**: Configured in .env file (SNOWFLAKE_USER)
- **Project Directory**: Configured in .env file (PROJECT_DIR)
- **Authentication**: SSO via SnowSQL CLI
- **Database**: prod_customer360
- **Schema**: customerprofile
- **Table**: CustomerSubsidiaryLicenseProfile
- **Query Type**: Read-only (license consumption data)

## Instructions

When this skill is invoked:

1. **Get parameters**:
   - First argument (required): Subsidiary name (e.g., "PepsiCo, Inc", "Microsoft Corporation")
   - If subsidiary name not provided, ask the user using AskUserQuestion
   - Username is read from .env file (SNOWFLAKE_USER)

2. **Check cache first**:
   - Look for files in `${PROJECT_DIR}/snowflake-data/` matching pattern: `subsidiary_license_<subsidiary_normalized>_*.csv`
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
   bash ${PROJECT_DIR}/scripts/subsidiary-license-info.sh "<subsidiary_name>"
   ```
   Examples:
   ```bash
   bash ${PROJECT_DIR}/scripts/subsidiary-license-info.sh "PepsiCo, Inc"
   bash ${PROJECT_DIR}/scripts/subsidiary-license-info.sh "Microsoft Corporation"
   ```

   Note: The script reads SNOWFLAKE_USER from .env file automatically.

4. **Display results**:
   - The script will output a summary with total records found
   - The script saves detailed CSV results to `${PROJECT_DIR}/snowflake-data/subsidiary_license_<subsidiary_slug>_<timestamp>.csv`
   - After the script completes, read the CSV file and create a formatted table showing:
     - Subsidiary Name
     - **ARR Bucket** (from CUSTOMERARRBUCKET column)
     - **Region** (from CUSTOMERSALESREGION column)
     - **Account Owner** (from CUSTOMERACCOUNTOWNER column)
     - **CSM Name** (from CUSTOMERCSMNAME column)
     - Product/SKU information
     - License counts (Consumed, Allocated, Available)
     - License types and tiers
     - Subscription details
     - Any relevant license metrics

5. **Handle errors**:
   - If SNOWFLAKE_USER not configured: Inform user to set it in .env file
   - If the script fails (exit code != 0), inform the user about authentication issues
   - Suggest running: `snowsql -a ${SNOWFLAKE_ACCOUNT} -u ${SNOWFLAKE_USER} --authenticator externalbrowser`
   - If no results found, inform the user and suggest checking the subsidiary name spelling

## Data Source

**Snowflake Table**: `prod_customer360.customerprofile.CustomerSubsidiaryLicenseProfile`
- **Account**: UIPATH-UIPATH_OBSERVABILITY.snowflakecomputing.com
- **Database**: prod_customer360
- **Schema**: customerprofile
- **Table Structure**:
  - 63 columns including account metadata, license details, usage metrics (MAU/MEU)
  - Rows organized by: Month, Subsidiary, Product/Service
  - Contains historical license consumption data by month

## Query Details

The query retrieves all columns from CustomerSubsidiaryLicenseProfile for the specified subsidiary:
- **SQL File**: `sql/subsidiary_license_query.sql`
- **Query**: `SELECT * FROM prod_customer360.customerprofile.CustomerSubsidiaryLicenseProfile WHERE SUBSIDIARYNAME ILIKE '%<subsidiary_name>%'`
- **Parameter**: `{SUBSIDIARY_NAME}` - replaced by script with actual subsidiary name
- **Filter**: SUBSIDIARYNAME ILIKE (partial, case-insensitive matching)
- **Limit**: None (retrieves all matching records)
- **Scope**: All license consumption data for matching subsidiaries
- **Use Case**: Understanding customer license usage, allocation, and consumption patterns
- **Authentication**: SSO via `snowsql --authenticator externalbrowser`

## Direct Script Usage

If you need to run the script directly (bypassing the skill):

```bash
# Query customer license data (username from .env)
bash ${PROJECT_DIR}/scripts/subsidiary-license-info.sh "Customer Name"

# Examples
bash ${PROJECT_DIR}/scripts/subsidiary-license-info.sh "PepsiCo, Inc"
bash ${PROJECT_DIR}/scripts/subsidiary-license-info.sh "Microsoft Corporation"
```

**Prerequisites**:
- Set SNOWFLAKE_USER in .env file
- Set PROJECT_DIR in .env file (or script uses current directory)

**Script Output**:
- Saves to: `${PROJECT_DIR}/snowflake-data/subsidiary_license_<subsidiary_slug>_<timestamp>.csv`
- Console output: Total records found, column count
- Exit code: 0 for success, 1 for errors (including missing SNOWFLAKE_USER)

## Example Usage

```bash
/snowflake-customer-license-info "PepsiCo, Inc"              # Query PepsiCo license info
/snowflake-customer-license-info "Microsoft Corporation"     # Query Microsoft license info
/snowflake-customer-license-info "Acme Corp"                 # Query Acme Corp license info
```

## Data Parsing Patterns

### License CSV Format
- **Header location**: Skip first 2 lines (auth output from Snowflake SSO), CSV header starts at line 3
- **File size**: Files can be large (1-6MB, 2000-6000+ rows for large customers)
- **Key columns**:
  - `MONTH`: Date in YYYY-MM-DD format (e.g., "2026-01-31")
  - `PRODUCTORSERVICENAME`: Product name (e.g., "Studio", "Assistant", "API Calls")
  - `PRODUCTORSERVICEQUANTITY`: Numeric quantity/allocation
  - Additional columns: Account metadata, subsidiary info, usage metrics (MAU/MEU), etc.

### Parsing Best Practices
- Use Python's `csv` module for large files (avoid reading entire file into memory)
- Always filter to latest month: `max(row['MONTH'] for all rows)`
- Aggregate by product: Group by `PRODUCTORSERVICENAME` and sum `PRODUCTORSERVICEQUANTITY`
- Handle missing values: Some fields may be empty or null
- Sort results by quantity descending to identify top products

### Example Python Parsing
```python
import csv
from collections import defaultdict

with open(file_path, 'r') as f:
    # Skip auth lines
    next(f)
    next(f)

    reader = csv.DictReader(f)
    data = list(reader)

    # Get latest month
    latest_month = max(row['MONTH'] for row in data if row.get('MONTH'))

    # Filter and aggregate
    products = defaultdict(float)
    for row in data:
        if row['MONTH'] == latest_month:
            product = row['PRODUCTORSERVICENAME']
            qty = float(row['PRODUCTORSERVICEQUANTITY'] or 0)
            products[product] += qty
```

## Notes
- **Configuration**: Requires SNOWFLAKE_USER and PROJECT_DIR to be set in .env file
- Requires SnowSQL CLI to be installed
- Requires active SSO authentication to Snowflake
- Results are saved in ${PROJECT_DIR}/snowflake-data/ directory with timestamp
- Query is read-only and does not modify any data
- **Uses partial matching (ILIKE)**: Query matches any subsidiary name containing the search term (case-insensitive)
- Use quotes around subsidiary names with spaces or special characters
- For ambiguous names (e.g., "T-Mobile" matches "T-Mobile USA, Inc", "T-Mobile Polska"), results may include multiple subsidiaries
- No record limit - retrieves all matching records (large customers may return thousands of records)
- Cache files with no data rows trigger fresh queries automatically
