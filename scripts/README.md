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

### `snowflake-usage.sh`
**Purpose**: Generic Snowflake usage query tool (extensible via `snowflake-modules.conf`)

**Usage**:
```bash
# Show available modules
./snowflake-usage.sh

# Query specific customer for a module
./snowflake-usage.sh integration-service "Customer Name"
./snowflake-usage.sh is "Customer Name"    # Short alias

# Query all customers
./snowflake-usage.sh integration-service
```

**Requirements**:
- SnowSQL CLI installed
- SNOWFLAKE_USER and PROJECT_DIR configured in ../.env
- Active SSO authentication to Snowflake

**SQL**: Module-specific SQL files in `../sql/` (configured in `snowflake-modules.conf`)

**Output**: `${PROJECT_DIR}/snowflake-data/snowflake_<module>_<timestamp>[_<customer_slug>].csv`

**Caching**: Per-module cache TTL (Integration Service: 7 days)

---

## Salesforce Scripts

### `sf-cases.sh`
**Purpose**: Query Salesforce for support cases with optional customer and product filters

**Usage**:
```bash
# Query all customers for last N days
./sf-cases.sh <days>

# Query specific customer
./sf-cases.sh <days> "Customer Name"

# Query specific customer and product
./sf-cases.sh <days> "Customer Name" "Integration Service"
```

**Requirements**:
- Salesforce CLI v2 (sf) installed
- SALESFORCE_ORG_ALIAS configured in ../.env
- Active SSO authentication to Salesforce

**Output**: `${PROJECT_DIR}/sf-cases/sf_cases_<days>days_[<product_slug>_][<customer_slug>_]<timestamp>.json`

**Caching**: Uses cached data if < 24 hours old and contains records

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
