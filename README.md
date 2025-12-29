# Unified File Reporting on Salesforce

This Salesforce DX project is intended to provide unified reporting capability for all file types in Salesforce, starting with Content Documents (Files), Classic Attachments, and Content Notes for now. It enables users to run native Salesforce Reports and Dashboards across all file types using a denormalized, reportable custom object.

## Overview

The solution builds a unified view of files by synchronizing data from multiple Salesforce objects into a single `Unified_File__c` custom object. This allows for comprehensive and native reporting on file storage, ownership, and metadata without complex joins or custom development.

### Key Features

- **Unified Reporting**: Report on Files, Attachments, and Content Notes in a single view
- **Automated Synchronization**: Hourly delta updates and nightly full reconciliations
- **Configurable Ownership Policies**: Flexible rules for determining file ownership
- **Parent Linkage**: Tracks primary parent records for each file
- **Operational Monitoring**: Comprehensive logging and telemetry
- **Native Salesforce Tools**: Uses standard Reports, Dashboards, and Custom Report Types

### Supported File Types in Version 1

- **Content Documents** (Files): Including all versions and metadata
- **Classic Attachments**: Legacy attachment objects
- **Content Notes**: Salesforce Notes stored as Content Versions

## Architecture

### Data Model

- **`Unified_File__c`**: Main reporting object containing denormalized file metadata
- **`Unified_Sync_Log__c`**: Operational logs for sync processes
- **`Unified_Sync_Config__mdt`**: Configuration settings via Custom Metadata Types

### Processing Components

- **Schedulers**: `NightlyFullScheduler` and `HourlyDeltaScheduler`
- **Orchestrator**: Queueable class managing batch execution order
- **Batch Classes**:
  - `BatchExtractContentVersions`
  - `BatchExtractContentDocumentLinks`
  - `BatchExtractAttachments`
- **Services**:
  - `UnifiedFileUpsertService`
  - `FileRecordMapper`
  - `ParentSelectorService`
  - `OwnershipService`
  - `DeltaChecker`
  - `IdempotencyUtil`
  - `UnifiedSyncLogService`

## Prerequisites

- Access to a Salesforce org (Sandbox, Scratch Org, or Production)
- Integration User with appropriate permissions:
  - Read access on: ContentDocument, ContentVersion, ContentDocumentLink, ContentNote, Attachment
  - Create/Update access on: Unified_File__c, Unified_Sync_Log__c
  - Read/Create/Update on: Unified_Sync_Config__mdt
  - Permission Set: File_Reports_Integration_ User has the necessary permissions

## Installation

### Deploy as Unlocked Package (For Administrators)

Click on the [Install Package](https://login.salesforce.com/packaging/installPackage.apexp?p0=0HoWU0000001Bkb0AE) link and log into the target Org.

### Deploy as Unlocked Package (For Developers)

1. Clone this repository
2. Authenticate with your Salesforce org:
   ```bash
   sf org login web
   ```
3. Create a scratch org (optional):
   ```bash
   sf org create scratch --definition-file config/project-scratch-def.json --alias <Org Alias>
   ```
4. Deploy the package or Run the deployment script or Push source to your org:
   ```bash
   # Deploying the Package
   sf package install --package "Unified File Reporting on Salesforce" --org <Org Alias> --wait 10
   ```
   ```bash
   # Running Deployment Script
   bash scripts/deploy-scratch.sh
   ```
   ```bash
   # Push Source to Org
   sf project deploy start --source-dir force-app
   ```

## Configuration

### Custom Metadata Types

Configure the solution via `Unified_Sync_Config__mdt` (Defaults should already exist):

- `nightlyFullEnabled__c`: Enable/disable nightly full syncs
- `hourlyDeltaEnabled__c`: Enable/disable hourly delta syncs
- `hourlyDeltaLookbackMins__c`: Lookback window for delta processing
- `batchSizeContentVersion__c`: Batch size for Content Version processing
- `batchSizeAttachment__c`: Batch size for Attachment processing
- `batchSizeCDL__c`: Batch size for Content Document Link processing
- `maxUpsertPerTxn__c`: Maximum upserts per transaction
- `retryLimit__c`: Retry limit for failed operations
- `ownershipPolicy__c`: Ownership derivation policy (LATEST_VERSION_MODIFIER, PARENT_OWNER, ATTACHMENT_OWNER)

### Scheduling Jobs

1. Schedule the sync jobs in Setup > Scheduled Jobs:

- **Nightly Full Sync**: Run `NightlyFullScheduler` daily (e.g., 2 AM)
- **Hourly Delta Sync**: Run `HourlyDeltaScheduler` hourly

## Usage

### Running Reports

1. Navigate to Reports in Salesforce
2. Create a new report using the "Unified Files" Custom Report Type
3. Add filters and groupings as needed

### Sample Reports and Dashboard (comes with this package)

- Files by Owner
- Files by Parent Record Type
- Largest Files by Size
- Recently Modified Files
- Orphaned Files (no parent)
- Dashboard: Files Manager

## Testing

Run Apex tests:
```bash
sf apex run test --tests "BatchExtractContentVersionsTests,BatchExtractAttachmentsTests,..." --resultformat human --codecoverage
```

Key test scenarios:
- Full sync end-to-end processing
- Delta sync change detection
- Parent selection logic
- Ownership policy application
- Error handling and logging
- Idempotency verification

## Security and Access Control

- Apex classes use `with sharing`
- Database operations use `AccessLevel.USER_MODE`
- Field-level security enforced where applicable
- Ability to set Report folder permissions control access to reports and dashboards

## Performance and Scalability

- Batch processing with configurable sizes
- Delta processing for efficient incremental updates
- Query optimization with selective field retrieval
- External ID indexing on `HashKey__c`

### Monitoring Sync Jobs

Check `Unified_Sync_Log__c` records for:
- Batch execution status
- Record counts and error details
- Processing timestamps

### Common Issues

- **Lock Contention**: Adjust batch sizes or scheduling
- **Governor Limits**: Monitor heap usage and query selectivity
- **Missing Files**: Run full sync to reconcile deletions

## Support

For issues or questions, please refer to the documentation, engage in discussions or create an issue in this repository.
