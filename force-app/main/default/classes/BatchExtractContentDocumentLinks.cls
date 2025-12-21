/**
 * @description Batch job to update parent information from ContentDocumentLinks
 * @author Master's Student - SDLC Demonstration
 * @date 2025
 */
public with sharing class BatchExtractContentDocumentLinks implements Database.Batchable<SObject>, Database.Stateful {
    
    private SyncMode mode;
    private Integer lookbackMinutes;
    private Integer totalProcessed = 0;
    private Integer totalErrors = 0;
    private String sampleError;
    private Unified_Sync_Log__c logRecord;
    
    /**
     * @description Constructor
     * @param mode Sync mode (FULL or DELTA)
     * @param lookbackMinutes Lookback period for DELTA mode
     */
    public BatchExtractContentDocumentLinks(SyncMode mode, Integer lookbackMinutes) {
        this.mode = mode;
        this.lookbackMinutes = lookbackMinutes;
    }
    
    /**
     * @description Start method - builds query
     * Note: ContentDocumentLink only has CreatedDate and SystemModstamp, not LastModifiedDate
     * @param bc Batch context
     * @return Database.QueryLocator Query locator for ContentDocumentLinks
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        this.logRecord = UnifiedSyncLogService.startLog(
            'BatchExtractContentDocumentLinks',
            mode.name()
        );
        
        String query = 'SELECT ContentDocumentId, LinkedEntityId, ' +
                      'CreatedDate, SystemModstamp ' +
                      'FROM ContentDocumentLink';
        
        if (mode == SyncMode.DELTA && lookbackMinutes != null) {
            Datetime lookbackTime = Datetime.now().addMinutes(-lookbackMinutes);
            // Use SystemModstamp for delta since LastModifiedDate doesn't exist
            query += ' WHERE SystemModstamp >= :lookbackTime';
        }
        
        System.debug('BatchExtractContentDocumentLinks query: ' + query);
        return Database.getQueryLocator(query);
    }
    
    /**
     * @description Execute method - processes batches
     * @param bc Batch context
     * @param links List of ContentDocumentLinks to process
     */
    public void execute(Database.BatchableContext bc, List<ContentDocumentLink> links) {
        try {
            // Group links by ContentDocumentId
            Map<Id, List<ContentDocumentLink>> documentToLinksMap = 
                new Map<Id, List<ContentDocumentLink>>();
            
            for (ContentDocumentLink link : links) {
                if (!documentToLinksMap.containsKey(link.ContentDocumentId)) {
                    documentToLinksMap.put(link.ContentDocumentId, new List<ContentDocumentLink>());
                }
                documentToLinksMap.get(link.ContentDocumentId).add(link);
            }
            
            // Select primary parents
            Map<Id, ParentInfo> parentMap = new Map<Id, ParentInfo>();
            for (Id documentId : documentToLinksMap.keySet()) {
                ParentInfo parent = ParentSelectorService.selectPrimaryParent(
                    documentToLinksMap.get(documentId)
                );
                parentMap.put(documentId, parent);
            }
            
            // Query existing Unified_File__c records for these documents
            Set<String> hashKeys = new Set<String>();
            for (Id documentId : parentMap.keySet()) {
                String hashKey = IdempotencyUtil.makeHashKey('CONTENT_DOCUMENT', documentId);
                hashKeys.add(hashKey);
            }
            
            Map<String, Unified_File__c> existingRecordsMap = new Map<String, Unified_File__c>();
            List<Unified_File__c> existingRecords = [
                SELECT Id, HashKey__c, ParentRecordId__c, ParentRecordType__c, ParentRecordName__c
                FROM Unified_File__c
                WHERE HashKey__c IN :hashKeys
                WITH SECURITY_ENFORCED
            ];
            
            for (Unified_File__c record : existingRecords) {
                existingRecordsMap.put(record.HashKey__c, record);
            }
            
            // Update parent information
            List<Unified_File__c> recordsToUpdate = new List<Unified_File__c>();
            
            for (Id documentId : parentMap.keySet()) {
                String hashKey = IdempotencyUtil.makeHashKey('CONTENT_DOCUMENT', documentId);
                Unified_File__c existingRecord = existingRecordsMap.get(hashKey);
                
                if (existingRecord != null) {
                    ParentInfo newParent = parentMap.get(documentId);
                    
                    // Check if parent has changed
                    Boolean parentChanged = false;
                    if (newParent.isValid()) {
                        parentChanged = (existingRecord.ParentRecordId__c != String.valueOf(newParent.parentRecordId));
                    }
                    
                    if (parentChanged) {
                        existingRecord.ParentRecordId__c = String.valueOf(newParent.parentRecordId);
                        existingRecord.ParentRecordType__c = newParent.parentRecordType;
                        existingRecord.ParentRecordName__c = newParent.parentRecordName;
                        recordsToUpdate.add(existingRecord);
                    }
                }
            }
            
            // Perform update
            if (!recordsToUpdate.isEmpty()) {
                List<Database.SaveResult> results = Database.update(
                    recordsToUpdate,
                    false,
                    AccessLevel.USER_MODE
                );
                
                Map<String, Integer> summary = UnifiedFileUpsertService.analyzeSaveResults(results);
                totalProcessed += summary.get('success');
                totalErrors += summary.get('errors');
                
                // Capture first error
                if (sampleError == null) {
                    for (Database.SaveResult result : results) {
                        if (!result.isSuccess()) {
                            sampleError = result.getErrors()[0].getMessage();
                            break;
                        }
                    }
                }
            }
            
        } catch (Exception e) {
            totalErrors += links.size();
            if (sampleError == null) {
                sampleError = e.getMessage() + '\n' + e.getStackTraceString();
            }
            System.debug(LoggingLevel.ERROR, 'Error in BatchExtractContentDocumentLinks: ' + e.getMessage());
        }
    }
    
    /**
     * @description Finish method - logs results
     * @param bc Batch context
     */
    public void finish(Database.BatchableContext bc) {
        UnifiedSyncLogService.completeLog(
            logRecord,
            totalProcessed,
            totalErrors,
            sampleError
        );
        
        System.debug('BatchExtractContentDocumentLinks completed: ' + totalProcessed + 
                    ' processed, ' + totalErrors + ' errors');
    }
}