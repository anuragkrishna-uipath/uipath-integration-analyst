# Data Extraction Scripts

This directory contains scripts for extracting data from Snowflake and Salesforce.

## Snowflake Scripts

### `subsidiary-license-info.sh`
**Purpose**: Query Snowflake for customer license consumption data

**Usage**:
```bash
./subsidiary-license-info.sh "Customer Name"
```

**Requirements**:
- SnowSQL CLI installed
- SNOWFLAKE_USER and PROJECT_DIR configured in ../.env
- Active SSO authentication to Snowflake

**SQL**: Uses `../sql/subsidiary_license_query.sql`

**Output**: `${PROJECT_DIR}/snowflake-data/subsidiary_license_<customer_slug>_<timestamp>.csv`

**Caching**: Uses cached data if customer-specific file exists (any age)

---

### `snowflake-is-usage.sh`
**Purpose**: Query Snowflake for Integration Service API usage data (last 3 months)

**Usage**:
```bash
# Query specific customer
./snowflake-is-usage.sh "Customer Name"

# Query all customers
./snowflake-is-usage.sh
```

**Requirements**:
- SnowSQL CLI installed
- SNOWFLAKE_USER and PROJECT_DIR configured in ../.env
- Active SSO authentication to Snowflake

**SQL**:
- With customer: `../sql/is_usage_query_with_customer.sql`
- All customers: `../sql/is_usage_query_all.sql`

**Output**:
- With customer: `${PROJECT_DIR}/snowflake-data/snowflake_is_usage_<timestamp>_<customer_slug>.csv`
- All customers: `${PROJECT_DIR}/snowflake-data/snowflake_is_usage_<timestamp>.csv`

**Caching**: Uses cached data if < 7 days old and contains data rows

---

## Salesforce Scripts

### `sf-integration-cases.sh`
**Purpose**: Query Salesforce for Integration Service support cases

**Usage**:
```bash
# Query all customers for last N days
./sf-integration-cases.sh <days>

# Query specific customer
./sf-integration-cases.sh <days> "Customer Name"
```

**Requirements**:
- Salesforce CLI v2 (sf) installed
- SALESFORCE_ORG_ALIAS configured in ../.env
- Active SSO authentication to Salesforce

**Output**:
- All customers: `${PROJECT_DIR}/is-cases/sf_integration_cases_<days>days_<timestamp>.json`
- Specific customer: `${PROJECT_DIR}/is-cases/sf_integration_cases_<days>days_<customer_slug>_<timestamp>.json`

**Caching**: Uses cached data if < 24 hours old and contains records

---

### `fetch_salesforce_cases.py`
**Purpose**: Python client for Salesforce case queries (alternative to sf CLI)

**Usage**:
```bash
python fetch_salesforce_cases.py
```

**Requirements**:
- Python 3.x
- simple-salesforce package
- Salesforce credentials in ../.env (username/password or OAuth)

**Note**: This is a fallback option if sf CLI is not available

---

## General Notes

- All scripts read configuration from `../.env` file in project root
- All scripts use `PROJECT_DIR` environment variable for output paths
- Scripts automatically create necessary output directories
- Scripts validate required environment variables and fail gracefully
- All scripts support SSO authentication (preferred method)
- SQL queries are maintained separately in `../sql/` directory

## Troubleshooting

**Snowflake authentication issues**:
```bash
snowsql -a ${SNOWFLAKE_ACCOUNT} -u ${SNOWFLAKE_USER} --authenticator externalbrowser
```

**Salesforce authentication issues**:
```bash
sf org login web --instance-url ${SALESFORCE_INSTANCE_URL} --alias ${SALESFORCE_ORG_ALIAS}
```

**SQL file not found**:
- Ensure SQL files are in `../sql/` directory relative to script location
- Check that symbolic links are not broken
- Verify file permissions allow reading
