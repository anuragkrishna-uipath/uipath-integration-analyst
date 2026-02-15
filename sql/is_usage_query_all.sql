-- Query to retrieve Integration Service API usage data for all customers
-- Time range: Last 3 months
-- No customer filter applied

SELECT
    s.name,
    its.connectorkey,
    CASE
        WHEN its.originator IN ('UiPath.PO', 'Uipath.AgenticOrchestration.Designer') THEN 'Maestro'
        WHEN its.originator IN ('UiPath.AgentService', 'Uipath.Agent.Designer') THEN 'Agents'
        WHEN its.originator = 'UiPath.IntegrationService.Poller' THEN 'IS Pollers'
        WHEN its.originator ILIKE '%robot%' THEN 'Robot'
        WHEN its.originator = 'api-workflow' THEN 'API Workflows'
        WHEN its.originator = 'UiPath.Studio' THEN 'Studio'
        WHEN its.originator ILIKE '%StudioWeb%' THEN 'Studio Web'
        WHEN its.originator IN ('UiPath.IntegrationService.ConnectionService', 'UiPath.IntegrationService.Triggers', 'UiPath.IntegrationService.Webhook', 'UiPath.Ezra') THEN 'Connections OR Trigger Creation'
        WHEN its.originator = 'Autopilot' THEN 'Autopilot'
        WHEN its.originator = 'integration-tests' THEN 'Tests'
        WHEN its.originator = 'ElementService.OauthTokenRefreshJob' THEN 'ConnectionsTokenRefreshJob'
        WHEN its.originator IN ('ElementService.Soba', 'denali', 'folder-auth') THEN 'IS Internal Chained Calls'
        ELSE 'Others'
    END AS GroupedOriginator,
    COUNT(*) AS APIUsage
FROM
    PROD_ELEMENTSERVICE.APPINS.INTEGRATIONSERVICE_TELEMETRY_STANDARDIZED AS its
    JOIN prod_customer360.standard.cloudorganizationexclusivesubcodehistory AS sch
        ON its.cloudorganizationid = sch.cloudorganizationid
        AND sch.Date = CURRENT_DATE() - 1
    JOIN prod_customer360.constants.SubscriptionCodeAttributes AS sca
        ON sch.subscriptioncode = sca.subscriptioncode
    JOIN prod_customer360.standard.cloudorganizationtosubsidiarymap AS cmap
        ON sch.cloudorganizationid = cmap.cloudorganizationid
    LEFT JOIN prod_customer360.standard.SubsidiaryHistory s
        ON s.Id = cmap.subsidiaryid
WHERE
    its.eventname = 'API.Request'
    AND its.RequestType = 'vendor'
    AND its.Date >= DATEADD(month, -3, CURRENT_DATE)
    AND its.activationtype = 'AutomationCloud'
GROUP BY 1, 2, 3
ORDER BY 4 DESC;
