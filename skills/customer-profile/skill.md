---
name: customer-profile
description: Generate comprehensive customer profile with ARR, license consumption, usage data, support tickets, and action items
user-invocable: true
argument-hint: "[customer_name]"
allowed-tools: Bash, Read, Glob, Grep, Task, AskUserQuestion, Skill
---

# Customer Profile Skill

Generate a comprehensive customer profile combining ARR data, license consumption, Integration Service usage, support tickets, and actionable recommendations for Product Managers.

## Purpose

This skill provides a 360-degree view of a customer by aggregating:
- ARR and account information
- License consumption and utilization
- Integration Service API usage patterns
- Recent support ticket activity
- Data-driven action items for Product Managers

## Data Sources

1. **ARR Data**: `~/Documents/uipath-integration-analyst/arr/` folder (Excel/CSV files)
2. **License Consumption**: Snowflake CustomerSubsidiaryLicenseProfile
3. **IS Usage**: Snowflake Integration Service telemetry (last 3 months)
4. **Support Tickets**: Salesforce cases (last 6 months)

## Instructions

When this skill is invoked:

### 1. Get Customer Name
- If argument provided (e.g., `/customer-profile "PepsiCo, Inc"`), use that
- If not provided, ask user using AskUserQuestion
- Normalize name for searches (handle variations)

### 2. Data Collection Strategy

All data gathering is delegated to specialized skills that handle caching automatically:
- **ARR Data**: Read directly from `~/Documents/uipath-integration-analyst/arr/` (7-day cache)
- **License Data**: Handled by `/snowflake-customer-license-info` skill (uses cached if exists)
- **IS Usage Data**: Handled by `/snowflake-is-usage` skill (7-day cache)
- **Support Tickets**: Handled by `/sf-integration-cases` skill (24-hour cache)
- **Customer News**: Handled by `/customer-in-news` skill (real-time web search)

### 3. Gather ARR Data
- Search for ARR data in `~/Documents/uipath-integration-analyst/arr/` folder
- Look for most recent CSV file (check modification date)
- Search for customer name in the file using Grep
- Extract: ARR bucket, region, account owner, CSM, ticket count

### 4. Gather License Consumption Data
- Invoke the `/snowflake-customer-license-info` skill with customer name
- The skill will handle caching automatically (uses cached data if customer file exists)
- After skill completes, read the cached CSV file from `~/Documents/uipath-integration-analyst/snowflake-data/`
- Extract latest month data:
  - Total licenses by product type
  - Key products (Studio, StudioX, robots, DU units, AI units, API calls)
  - MAU/MEU numbers

### 5. Gather Integration Service Usage

**Invoke the skill:**
- Invoke the `/snowflake-is-usage` skill with customer name and username
- The skill will handle caching automatically (7-day cache, fetches if expired or customer not found)
- After skill completes, read the cached CSV file from `~/Documents/uipath-integration-analyst/snowflake-data/`

**Extract from data:**
- Total API calls
- Top originators (IS Pollers, Robot, etc.) with percentages
- Top connector keys by usage
- Identify primary integration pattern

**IMPORTANT - IS Licensing Rules:**
- **IS Poller calls do NOT count toward API licensing limits**
- Only non-poller calls (Robot, Studio, Connections, etc.) count toward licensed API capacity
- When assessing API overages, exclude IS Poller volume from licensed capacity calculations
- High poller usage (>90%) is an efficiency concern, NOT a licensing concern

### 6. Gather Support Tickets (Last 6 Months)
- Invoke the `/sf-integration-cases` skill with 180 days and customer name
- The skill will handle caching automatically (24-hour cache, fetches if expired or customer not found)
- After skill completes, read the cached JSON file from `~/Documents/uipath-integration-analyst/is-cases/`
- Extract:
  - Total tickets
  - Open vs closed tickets
  - Priority distribution
  - Common themes from ticket subjects

### 7. Research Customer Context (Always Required)

**Invoke the customer news skill:**
- Invoke the `/customer-in-news` skill with customer name using the Skill tool
- The skill will perform web search for recent news about the customer
- Look for: strategic initiatives, partnerships, digital transformation efforts, industry trends
- Incorporate findings into recommendations and action items

### 8. Format Output

Present data in a single consolidated table with insights after each section, followed by action items:

```markdown
# Customer Profile: <Customer Name>

| Category | Metric | Value |
|----------|--------|-------|
| **Account** | Customer Name | <Name> |
| | Primary Use Case | <Derived from usage patterns> |
| | ARR Bucket | <Bucket> (e.g., $3M-5M) |
| | Region | <Region> |
| | Account Owner | <Name> |
| | CSM | <Name> |

**Account Insight:** <1-2 sentences about customer profile, maturity, deployment scale>

| **Licenses (Q)** | Studio | <qty> |
| | StudioX | <qty> |
| | Assistant | <qty> |
| | Robot Units | <qty> |
| | DU Units | <qty> |
| | AI Units | <qty> |
| | API Calls (licensed) | <qty> |

**License Insight:** <1-2 sentences about license mix, deployment strategy, key products>

| **IS Usage (3mo)** | Total API Calls | <qty> (e.g., 3.4B) |
| | Primary Originator | <Type> (<pct>%, e.g., IS Pollers 98.9%) |
| | Billable API Calls | <qty non-poller calls> |
| | Licensed API Capacity | <qty from license data> |
| | Integration Pattern | <Pattern> (e.g., Polling-based) |

**IS Usage Insight:** <1-2 sentences about usage patterns, optimization opportunities. IMPORTANT: Note that IS Poller calls don't count toward licensing - only assess overage for non-poller calls vs licensed capacity>

| **Support (6mo)** | Total Tickets | <count> |
| | Open Tickets | <count> |
| | Priority Distribution | <summary> (e.g., 11 Medium) |
| | Top Issue Theme | <theme> (<count> tickets) |

**Support Insight:** <1-2 sentences about support health, common issues, customer experience>

---

## Action Items

1. **<Category>**: <Specific action based on data>
   - *Data point*: <Supporting metric>
   - *Action*: <What to do>

2. **<Category>**: <Specific action based on data>
   - *Data point*: <Supporting metric>
   - *Action*: <What to do>

3. **<Category>**: <Specific action based on data>
   - *Data point*: <Supporting metric>
   - *Action*: <What to do>

---
*Profile generated: <Timestamp> | Data sources: ARR (<file_date>), Licenses (<file_date>), Tickets (<file_date>)*
```

**Formatting Guidelines:**
- Merge related metrics into single table with Category column
- Keep licenses concise - only show key products with quantities
- For IS Usage, focus on top 2 originators and overall pattern
- For Support, summarize themes rather than listing individual tickets
- Action items should be 3-5 items maximum, prioritized by impact

### 9. Generate Action Items

Action items should be derived from data patterns AND web search findings. Limit to 3-5 high-impact items:

**Data Pattern → Action Mapping:**

- **Excessive IS Poller usage (>90%)** → Recommend polling-to-webhook migration audit for efficiency (NOTE: Poller calls don't count toward licensing, so this is optimization-focused, not compliance)
- **Non-poller API usage exceeds licensed capacity** → Urgent capacity planning discussion / true-up (CRITICAL: Only count Robot, Studio, Connections, and other non-poller originators against licensed API capacity)
- **Multiple connector authentication tickets** → Proactive Azure AD/OAuth configuration review
- **Low license utilization (<30% MAU/MEU)** → Adoption program or downsell risk mitigation
- **Multiple open/high-priority tickets** → Schedule health check call and escalation review
- **High robot units with low runtime** → ROI optimization opportunity
- **Large StudioX deployment** → Citizen developer enablement and governance check
- **No recent support tickets + high usage** → Customer health signal - schedule QBR
- **Growing usage trend** → Upsell/expansion opportunity

Prioritize action items by:
1. Revenue impact (overages, downsell risk, upsell opportunities)
2. Alignment with customer's strategic initiatives (from web search)
3. Customer experience (open tickets, authentication issues)
4. Optimization opportunities (efficiency gains, cost reduction)

**Incorporate web search findings:**
- If customer is pursuing digital transformation → Recommend aligning automation roadmap with their strategic goals
- If customer in growth phase → Position expansion opportunities and scalability features
- If customer facing challenges → Proactive support and optimization recommendations

## Use Case Detection

Infer primary use case from usage patterns (KEEP IT GENERAL - avoid specific connector names):

- **Document Processing**: High DU Units consumption, document-related API activity
- **Email & Communication Automation**: High communication-related connector usage patterns
- **Data Integration & Synchronization**: High database and enterprise system integration activity
- **API Orchestration & Event-Driven Automation**: High IS Pollers activity, diverse connector portfolio
- **Development & Testing**: High Studio usage, test automation patterns
- **Attended Automation**: High Assistant licenses, moderate robot usage for desktop workflows
- **Hybrid Automation**: Balanced mix of attended and unattended robots with integration services

## Example Usage

```bash
/customer-profile "PepsiCo, Inc"
/customer-profile "Microsoft Corporation"
/customer-profile "Acme Corp"
```

## Error Handling

- If ARR data not found: Note "ARR data not available"
- If no Snowflake access: Use "Authentication required"
- If customer not found in any system: Provide partial profile with available data
- Always provide action items even with incomplete data

## Notes

- **Caching behavior**: Automatically uses cached data when available to reduce API calls
  - ARR data: Uses cached data if < 7 days old, fetches if older or not found
  - License data: Uses cached data if customer file exists (any age), fetches if customer not found
  - IS Usage data: Uses cached data if < 7 days old, fetches from Snowflake if older or customer not found
  - Support tickets: Uses cached data if < 24 hours old, fetches if older or customer not found
- **IS API Licensing (CRITICAL)**: IS Poller calls do NOT count toward licensed API capacity. Only non-poller originators (Robot, Studio, Connections, Studio Web, etc.) are billable. Always exclude poller volume when assessing API overages.
- **Web search (REQUIRED)**: Always perform web search to gather customer context and incorporate findings into recommendations
- Requires authentication to both Snowflake and Salesforce (only when fetching new data)
- Profile generation may take 2-5 minutes when parsing large license files locally
- Profile generation with fresh data fetch may take longer if API calls are required
- Action items should be specific, data-driven, aligned with customer strategy, and prioritized by revenue impact
