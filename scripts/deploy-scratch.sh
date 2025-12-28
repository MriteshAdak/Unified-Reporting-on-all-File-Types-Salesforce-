#!/usr/bin/env bash
set -euo pipefail

# Dependency-aware deployment to default scratch org using sf CLI
# Prereqs:
# - Salesforce CLI (sf) installed
# - Default org set (either via sf config set target-org or alias provided via --target-org)
#
# Usage:
#   bash scripts/deploy-scratch.sh            # deploy all stages and run tests
#   TARGET_ORG=<aliasOrUsername> bash scripts/deploy-scratch.sh
#
# Notes:
# - This script deploys in dependency-aware stages to improve failure isolation.
# - For a one-shot deploy, consider: sf project deploy start --source-dir force-app
# - For manifest-based: sf project deploy start --manifest manifest/package.xml

TARGET_ORG="${TARGET_ORG:-}"

run_sf() {
  if [[ -n "${TARGET_ORG}" ]]; then
    sf "$@" --target-org "${TARGET_ORG}"
  else
    sf "$@"
  fi
}

echo "Showing default/target org details..."
if [[ -n "${TARGET_ORG}" ]]; then
  echo "Using target org: ${TARGET_ORG}"
fi
run_sf org display --verbose || true

echo "Stage 1: Deploy custom objects and custom metadata type structures"
run_sf project deploy start --source-dir force-app/main/default/objects/Unified_File__c
run_sf project deploy start --source-dir force-app/main/default/objects/Unified_Sync_Log__c
run_sf project deploy start --source-dir force-app/main/default/objects/Unified_Sync_Config__mdt

echo "Stage 2: Deploy tabs (depends on objects)"
run_sf project deploy start --source-dir force-app/main/default/tabs

echo "Stage 3: Deploy foundational Apex (enums, DTOs, utils, services)"
run_sf project deploy start --source-dir force-app/main/default/classes/SourceType.cls
run_sf project deploy start --source-dir force-app/main/default/classes/SyncMode.cls
run_sf project deploy start --source-dir force-app/main/default/classes/IdempotencyUtil.cls
run_sf project deploy start --source-dir force-app/main/default/classes/FileDTO.cls
run_sf project deploy start --source-dir force-app/main/default/classes/ParentInfo.cls
run_sf project deploy start --source-dir force-app/main/default/classes/UnifiedSyncLogService.cls
run_sf project deploy start --source-dir force-app/main/default/classes/FileRecordMapper.cls
run_sf project deploy start --source-dir force-app/main/default/classes/ParentSelectorService.cls
run_sf project deploy start --source-dir force-app/main/default/classes/OwnershipPolicy.cls
run_sf project deploy start --source-dir force-app/main/default/classes/OwnershipService.cls
run_sf project deploy start --source-dir force-app/main/default/classes/DeltaChecker.cls
run_sf project deploy start --source-dir force-app/main/default/classes/UnifiedFileUpsertService.cls

echo "Stage 4: Deploy batches, orchestrator, schedulers (depend on services)"
run_sf project deploy start --source-dir force-app/main/default/classes/BatchExtractAttachments.cls
run_sf project deploy start --source-dir force-app/main/default/classes/BatchExtractContentVersions.cls
run_sf project deploy start --source-dir force-app/main/default/classes/BatchExtractContentDocumentLinks.cls
run_sf project deploy start --source-dir force-app/main/default/classes/SyncOrchestrator.cls
run_sf project deploy start --source-dir force-app/main/default/classes/HourlyDeltaScheduler.cls
run_sf project deploy start --source-dir force-app/main/default/classes/NightlyFullScheduler.cls

echo "Stage 5: Deploy permission sets (after classes so class-level access resolves)"
run_sf project deploy start --source-dir force-app/main/default/permissionsets

echo "Stage 6: Deploy tests"
run_sf project deploy start --source-dir force-app/main/default/classes/__tests__

echo "Stage 7: Run tests with coverage (wait up to 20 minutes)"
run_sf apex run test --result-format human --code-coverage --wait 20

echo "Deployment complete."
