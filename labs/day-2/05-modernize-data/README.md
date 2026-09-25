# Lab 05: Database Modernization Bootcamp

## SQL Server to Azure SQL Database — Student Migration Challenges

**Scenario:** Migrate the eShop database from SQL Server on VM to Azure SQL Database by using Azure Database Migration Service (DMS).

Now that the application is upgraded and moved to Azure PaaS services, it is time to modernize and migrate the database. 

***Security rule:*** *Never expose passwords, storage keys, SAS tokens, or connection strings in screenshots or submissions. Do not enable public RDP or public Azure SQL access unless the instructor explicitly requires it.*

Learning objectives

Students will learn to:

* Gather information about a SQL server database
* Prepare and assess a SQL Server database for migration to Azure.
* Learn about diffenent authentication mechanisms in SQL server
* Learn about different types of backups and migration techniques
* Run an assessment of the source SQL Server database, analyze the report
* Create an Azure SQL Database resource as migration target.
* Configure private connectivity to the Azure SQL Database from both the Azure VM and also target PaaS services
* Create Azure Data Migration Service (DMS) and configure to run the "Self hosted Integration Runtime" on the Azure VM.
* Run DMS offline migration to Azure SQLDB
* Run and monitor an offline migration. Verify migrated data by query only.
* Create a SQL Managed Instance as another target for migration.
* Run DMS online migration to Azure SQL MI. Verify migration.
* Change the application connection string to point to SQL MI.
* Document differences between Azre SQLDB and Azire SQL MI and lessons learned. 

## Challenge 1 — Validate the source database

### Student tasks

1. Connect to the provided VM using the instructor-approved method.
2. Confirm that SQL Server services are running.
3. Determine the database credential the retail app is using.
4. Connect to the local SQL Server with SQL Server Management Studio (SSMS).
5. Record the SQL Server version,edition, database size, collation, disk file name and size of database files and "recovery model"
6. Also note down all the "page" names displayed when checking on database "properties" section.
6. Map the VM data drives to azure disks. Besides size what else is different between the two disks and why so ?
7. Verify that the VM has no unintended public exposure.
8. What are the different ways you can connect to this eshop database ?
9. (Research on this) What is a logical and phusical backup of SQL server ? What does
10. Run this query using SSMS 

```text
DBCC CHECKDB (N'eShop') ;
```

## Success criteria

* SSMS connects to the source instance.
* The student records the source version, edition etc.
* You can explain at least 4 different authentication mechanisms and show at least 2 ways to connnect
* You can explain recovery model and different backups.



## Challenge 2 — Pre-migration assessment of the source database 

## Student tasks

1. Using SSMS, right click on the server and choose "Migrate SQL Server"
2. <u>Do not Migrate or Upgrade the database</u>. Run a "Migration rediness assessment".
3. Investigate the report. Find out compatibility issues with different SQL targets

## Success criteria

* You learn different options of running SQL on Azure
* Understand the assessment report and the comptatibility issues.

## ~~Areas to examine~~   ( Only if time permits)

* Cross-database dependencies
* SQL Agent jobs
* Server-level objects and logins
* Windows authentication dependencies
* Unsupported data types or features
* CLR objects
* Three-part names
* Database mail and linked servers

## Challenge 3 — Create a database migration service for migration

## Student tasks

1. In the same region where you will deploy Azure SQL as a migration target, deploy Azure Data Migration Services (DMS)
2. After the DMS is installed, deploy and configure a self-hosted Integration Runtime on the source database server.
3. Verify that the "SHIR" shows as online on DMS in Azure portal. 
4. <u>Note (/u> ) only that the public IP of the SHIR nodes show up on DMS

## Success criteria

- DMS is employed with SHIR shown as online


## Challenge 4 — Offline Migraton to SQLDB

## Student tasks

1. Create an Azure SQL logical server

   a) Make sure it allows login using SQL authentication.  
   b) It uses the appropriate service tier/size  
   c) Configured to be accessible from the Lab VM using private endpoint.
   d) Create an empty database called "eshop"

2. Start a migraton to Azure SQL databaase using offline method. When it asks "is your SQL server instance tracked in azure ?" choose yes or no - based on the following

<u>Note</u> DMS needs to keep track of migration actions in a separagte SQL database. This is <b> not </b> your target database for migration.

Answer yes if it is either 

a) an Azure VM registered with the SQL IaaS Agent Extension ( <u>"SqlIaasExtension"</u>) - in which case the VM 
appears as a "SQL Virtual machine" on azure

b) or it is on-premises /or on other clouds and has Azure.Arcdata extensions installed. 

If not so, then choose no and DMS will create a [tracking database](https://learn.microsoft.com/en-us/azure/dms/dms-overview#tracking-resource) to track progress of migration. Choose a resource group, region and name of the tracking database the rest will be done by DMS automatically 

3. Connect to the source database SQL server using SQL authentication.

4. Next, within the source SQL server, choose the database that we want to migrate for the application.
This is the same database the application connects to, as you found in challenge 1.

5. Connect to the target Azure SQL database you created above, using SQL login

6. Choose eshop as the target database

7. Select all the tabes to copy. Make sure "Migrate missing schema" is checked. 

8. Complete the migration.

  
## Success criteria

* SQL query into Azure SQLDB shows the same data in tables


### Extra Challenge 
* Going back to database backups - during offline DMS imigration - how was the backup done in this case - physical, logical or something else ? 
* If you were able to take a .bacpac backup then answer the following 
* Find out what the bacpac contains
* What kind of backup creates a .bacpac file ?
* Examine the .bacpac file by renaming it to .zip extension. Look into the model.xml file. 


## Challenge 5 — Online Migraton to SQL Managed Instance

## Student tasks

1. Use the SQL Managed Instance predeployed by the instructor. Do not create or
   reprovision the instance.

2. Sign in to Azure and run:

```powershell
.\assets\scripts\Enable-Lab04SqlMiPublicAccess.ps1 `
  -SubscriptionId '<subscription-id>'
```

3. Connect to the public endpoint reported by the script using SSMS and a
   Microsoft Entra authentication method. The endpoint uses TCP 3342.

4. If your public IP changes, rerun the script before reconnecting.

SQL authentication is intentionally disabled. The participant identity is the
configured Microsoft Entra administrator for the lab database.

## Challenge 6  — Enable private endpoint

## Student tasks

1. Create a private endpoint for the Azure SQL logical server. Go to Azure portal - -> Security --> Networking --> Private Access
2. Configure the private endpoint in the same region where you want to connect from.
3. One the azure portal, search for your private DNS zone just created for SQL Database. Under DNS Management ---> Virtual Network Links, 
add links to the Vnet where you want to connect to this SQL database from azure. 
4. Ensure net connectibity using private endpoint from your source something like 
```text
test-NetConnection <your-logical-server>.database.windows.net -Port 1434
```

privatelink.database.windows.net <b>"privatelink.database.windows.net"</b> 

1. Link the private DNS zone to the VNet.
2. Associate the private endpoint with a DNS zone group.
3. Confirm that the private endpoint connection is approved.

## Success criteria

* The Azure SQL server name resolves to a private IP from the VM.
* TCP 1433 is reachable from the VM.
* Public network access remains disabled.

Challenge 6 — Prove end-to-end target connectivity

## Student tasks

Test each layer independently from the source VM:

1. Resolve the Azure SQL server FQDN.
2. Test TCP port 1433.
3. Connect through SSMS using the normal server FQDN—not the private IP.
4. Run:

SELECT
 @@SERVERNAME AS ConnectedServer,
 DB\_NAME() AS ConnectedDatabase;

## Success criteria

Students demonstrate separate evidence for DNS, TCP connectivity, authentication, and database access.

## Reflection

Why does a successful port test not prove that authentication and database access will succeed?

Challenge 7 — Configure migration identities and permissions

## Student tasks

1. Create or identify the SQL login used by DMS for the source.
2. Grant the required source permissions, including access to metadata and data.
3. Create or identify the target migration login.
4. Grant the required Azure SQL roles and target database permissions.
5. Test both connections outside DMS.

## Minimum validation

* Source user can read the selected tables and definitions.
* Target user can create schema objects when schema migration is enabled.
* Target user can insert data into the target tables.

## Success criteria

DMS credentials work against both endpoints without granting unnecessary permanent privileges.

Challenge 8 — Create DMS and configure SHIR

## Student tasks

1. Register the required Azure resource provider if necessary.
2. Create or reuse an Azure Database Migration Service instance.
3. Configure a self-hosted integration runtime (SHIR).
4. Install SHIR on the provided VM or another instructor-approved host.
5. Register SHIR with the DMS authentication key.
6. Confirm that the SHIR node appears online.
7. Confirm that the installed version meets Microsoft’s current minimum requirement.
8. Test source and target connectivity from the migration workflow.

## Success criteria

* DMS is ready.
* SHIR is online and healthy.
* Source and target connection tests succeed.

Challenge 9 — Plan and start the offline migration

## Student tasks

1. Create a new SQL Server-to-Azure SQL Database offline migration.
2. Select source database eShop.
3. Map it to target database eShop.
4. Review the **Migrate Missing schema** option.
5. Select the required tables.
6. Document the expected downtime and validation plan.
7. Start the migration.

## Success criteria

Students can explain whether DMS will migrate schema, data, or both and understand that offline migration requires application downtime.

Challenge 10 — Diagnose schema migration error 2060

## Failure presented to students

Schema Migration for database 'eShop' failed in state
'MonitorSqlSchemaCopy'.

Could not load file or assembly
'System.Security.Principal.Windows, Version=5.0.0.0'.

Error code 2060 — SqlSchemaCopyFailed

## Student tasks

1. Identify the failed migration stage.
2. Determine whether the error proves a network failure.
3. Revalidate DNS and TCP 1433.
4. Inspect the SHIR service and version.
5. Review DMS migration details and logs.
6. Classify the likely fault domain:

* Source database
* Target database
* Network
* Authentication
* Schema-copy runtime

1. Explain why copying arbitrary DLLs or installing unsupported runtimes is unsafe.
2. Propose a supported alternative.

## Expected conclusion

The error occurred in the schema-copy runtime. Private connectivity should be tested independently, but the assembly-loading message does not by itself indicate a network or schema compatibility failure.

Challenge 11 — Generate and deploy the schema independently

## Student tasks

Using SSMS:

1. Right-click source database eShop.
2. Select **Tasks → Generate Scripts**.
3. Script the database objects required by the application.
4. Configure advanced options:

* **Types of data to script:** Schema only
* **Target engine:** Microsoft Azure SQL Database
* **Script database create:** False

1. Save the script as:

C:\LabFiles\eShop-schema.sql

1. Review the script for unsupported server-level or database-level statements.
2. Connect to the Azure SQL eShop database.
3. Ensure the SSMS database selector shows eShop.
4. Remove or correct unsupported USE statements.
5. Execute the script and document any remediation.

## Verification

SELECT COUNT(\*) AS TableCount
FROM sys.tables;

## Success criteria

* Required schemas and tables exist in Azure SQL.
* Deployment errors are resolved or documented.
* No source data has been copied by the schema-only script.

Challenge 12 — Rerun DMS as a data-only migration

## Student tasks

1. Create a new migration rather than reusing the failed run.
2. Map source eShop to the precreated target eShop.
3. Leave **Migrate Missing schema** unchecked.
4. Select all required tables.
5. Start the data migration.
6. Monitor table-level progress.
7. Record failed, skipped, and completed tables.

## Success criteria

* DMS bypasses the failed schema-copy path.
* Required table data is copied successfully.
* Every exception has an evidence-based disposition.

Challenge 13 — Reconcile source and target

## Student tasks

Compare:

* Schema and table counts
* Row counts for every migrated table
* Primary and foreign keys
* Indexes
* Views and stored procedures
* Representative business records
* Users and permissions

Example row-count inventory:

SELECT
 s.name AS SchemaName,
 t.name AS TableName,
 SUM(p.rows) AS RowCount
FROM sys.tables AS t
JOIN sys.schemas AS s
 ON s.schema\_id = t.schema\_id
JOIN sys.partitions AS p
 ON p.object\_id = t.object\_id
WHERE p.index\_id IN (0, 1)
GROUP BY s.name, t.name
ORDER BY s.name, t.name;

## Required reconciliation table

|  |  |  |  |  |  |
| --- | --- | --- | --- | --- | --- |
| **Schema** | **Table** | **Source rows** | **Target rows** | **Difference** | **Disposition** |
| Example | ExampleTable | 0 | 0 | 0 | Matched |

## Success criteria

Every selected table is reconciled. Differences are investigated rather than silently accepted.

Challenge 14 — Validate application readiness

## Student tasks

1. Identify the Lab 04 retail Container App and its system-assigned managed identity:

   ```powershell
   $containerApp = az containerapp list `
     --resource-group '<application-resource-group>' `
     --query '[0].{name:name, principalId:identity.principalId}' `
     --output json | ConvertFrom-Json
   ```

2. Connect to the Azure SQL `eShop` database as the configured Microsoft Entra administrator.
3. Create a contained user for the Container App identity. Use a unique alias and its object ID so the database principal does not depend on Entra display-name uniqueness:

   ```sql
   CREATE USER [caldova_retail_app] FROM EXTERNAL PROVIDER
     WITH OBJECT_ID = '<container-app-principal-id>';

   ALTER ROLE db_datareader ADD MEMBER [caldova_retail_app];
   ALTER ROLE db_datawriter ADD MEMBER [caldova_retail_app];
   ```

4. Do not grant `db_owner` or `db_ddladmin`; the runtime application reads and writes data but does not own schema deployment.
5. Prepare a passwordless application connection string using the Azure SQL FQDN:

   ```text
   Server=tcp:<server>.database.windows.net,1433;Initial Catalog=eShop;Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;
   ```

6. Confirm TLS encryption and managed-identity authentication.
7. Test representative application operations.
8. Identify features that require redesign after migration.
9. Document rollback criteria and a cutover plan.

## Success criteria

The Container App identity has only the required database roles, the connection string contains no password, and the student demonstrates that application readiness requires more than successful data copy.

Challenge 15 — Complete the security and operations review

## Student tasks

1. Confirm that Azure SQL public network access remains disabled.
2. Confirm that the VM has no unintended public exposure.
3. Remove temporary migration permissions where appropriate.
4. Rotate temporary credentials.
5. Remove expired SAS tokens and avoid persisted storage keys.
6. Decide which migration resources should be retained or deleted.
7. Estimate ongoing costs for Azure SQL, DMS, SHIR compute, storage, and private networking.
8. Define backup, monitoring, and recovery requirements for the target.

## Success criteria

Students submit a post-migration security and operational checklist.

Final student deliverable

Students must submit a migration report containing:

1. Executive summary
2. Provided source environment
3. Source assessment and compatibility findings
4. Target architecture
5. Private connectivity evidence
6. DMS and SHIR configuration
7. Initial migration result
8. Error 2060 investigation
9. Schema deployment workaround
10. Data migration result
11. Source-to-target reconciliation
12. Application-readiness findings
13. Security and operational review
14. Lessons learned and recommendations

Students must distinguish:

* **Observation:** What was measured or logged
* **Hypothesis:** A possible explanation
* **Conclusion:** What the evidence supports
* **Action:** What was changed
* **Result:** What happened afterward

Suggested class schedule

|  |  |  |
| --- | --- | --- |
| **Phase** | **Challenges** | **Suggested time** |
| Source preparation | 1–3 | 45–60 minutes |
| Target preparation | 4–7 | 60 minutes |
| DMS configuration | 8–9 | 45 minutes |
| Troubleshooting | 10–11 | 60 minutes |
| Data migration | 12 | 30–60 minutes |
| Validation and closeout | 13–15 | 60 minutes |

Student submission checklist

* [ ] Source database health and inventory
* [ ] Compatibility assessment
* [ ] Azure SQL target configuration
* [ ] Private endpoint and DNS validation
* [ ] Source and target permission tests
* [ ] DMS and SHIR readiness evidence
* [ ] Initial migration results
* [ ] Error 2060 analysis
* [ ] Schema deployment results
* [ ] Data-only migration results
* [ ] Source-to-target reconciliation
* [ ] Application-readiness test
* [ ] Security and operations review
* [ ] Final migration report

Instructor debrief questions

1. Why must compatibility assessment occur before migration?
2. What roles do Private Link and private DNS play?
3. Why should clients use the Azure SQL FQDN instead of its private IP?
4. What is the role of SHIR in an offline DMS migration?
5. How did you isolate error 2060 from network connectivity?
6. Why is independently deploying schema a valid migration strategy?
7. What evidence is required before declaring the migration successful?
8. What would change for a production migration with minimal downtime?
9. Which steps should be automated for repeatable delivery?

**Lab principle:** A migration is complete only after compatibility, connectivity, schema, data, application behavior, security, and operational readiness have all been validated with evidence.

---

[← Previous: Deploy the Azure Foundation](../../day-1/04-deploy-to-azure/README.md) | [Next: Deploy Code with GitHub Actions →](../06-deploy-code-with-github-actions/README.md)