-- Query to retrieve license consumption data for a specific subsidiary
-- Uses partial, case-insensitive matching on SUBSIDIARYNAME
-- Parameter: {SUBSIDIARY_NAME} - will be replaced by script

SELECT *
FROM prod_customer360.customerprofile.CustomerSubsidiaryLicenseProfile
WHERE SUBSIDIARYNAME ILIKE '%{SUBSIDIARY_NAME}%';
