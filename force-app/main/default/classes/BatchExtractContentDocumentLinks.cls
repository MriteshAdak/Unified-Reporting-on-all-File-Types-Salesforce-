/**
 * @description Batch job to update parent information from ContentDocumentLinks
 * @author Mritesh Adak
 * @date 2025
 */
public with sharing class BatchExtractContentDocumentLinks implements Database.Batchable<SObject>, Database.Stateful {
    
    private SyncMode mode;
    private Integer lookbackMinutes;
    private Integer totalProcessed = 0;
    private Integer totalErrors = 0;
    private String sampleError;
    private Unified_Sync_Log__c logRecord;
    
    public BatchExtractContentDocumentLinks(SyncMode mode, Integer lookbackMinutes) {
        this.mode = mode;
        this.lookbackMinutes = lookbackMinutes;
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        this.logRecord = UnifiedSyncLogService.startLog(
            'BatchExtractContentDocumentLinks',
            mode.name()
        );
        
        Set<Id> contentDocumentIds = new Set<Id>();
        
        if (mode == SyncMode.DELTA && lookbackMinutes != null) {
            Datetime lookbackTime = Datetime.now().addMinutes(-lookbackMinutes);
            for (ContentVersion cv : [
                SELECT ContentDocumentId 
                FROM ContentVersion 
                WHERE LastModifiedDate >= :lookbackTime AND IsLatest = true
            ]) {
                contentDocumentIds.add(cv.ContentDocumentId);
            }
        } else {
            for (ContentVersion cv : [
                SELECT ContentDocumentId 
                FROM ContentVersion 
                WHERE IsLatest = true
            ]) {
                contentDocumentIds.add(cv.ContentDocumentId);
            }
        }
        
        // Query ContentDocumentLinks with required filter
        String query = 'SELECT ContentDocumentId, LinkedEntityId ' +
                      'FROM ContentDocumentLink ' +
                      'WHERE ContentDocumentId IN :contentDocumentIds';
        
        System.debug('BatchExtractContentDocumentLinks query: ' + query);
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext bc, List<ContentDocumentLink> links) {
        try {
            Map<Id, List<ContentDocumentLink>> documentToLinksMap = 
                new Map<Id, List<ContentDocumentLink>>();
            
            for (ContentDocumentLink link : links) {
                if (!documentToLinksMap.containsKey(link.ContentDocumentId)) {
                    documentToLinksMap.put(link.ContentDocumentId, new List<ContentDocumentLink>());
                }
                documentToLinksMap.get(link.ContentDocumentId).add(link);
            }
            
            Map<Id, ParentInfo> parentMap = new Map<Id, ParentInfo>();
            for (Id documentId : documentToLinksMap.keySet()) {
                ParentInfo parent = ParentSelectorService.selectPrimaryParent(
                    documentToLinksMap.get(documentId)
                );
                parentMap.put(documentId, parent);
            }
            
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
            
            List<Unified_File__c> recordsToUpdate = new List<Unified_File__c>();
            
            for (Id documentId : parentMap.keySet()) {
                String hashKey = IdempotencyUtil.makeHashKey('CONTENT_DOCUMENT', documentId);
                Unified_File__c existingRecord = existingRecordsMap.get(hashKey);
                
                if (existingRecord != null) {
                    ParentInfo newParent = parentMap.get(documentId);
                    
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
            
            if (!recordsToUpdate.isEmpty()) {
                List<Database.SaveResult> results = Database.update(
                    recordsToUpdate,
                    false,
                    AccessLevel.USER_MODE
                );
                
                Integer successCount = 0;
                Integer errorCount = 0;
                
                for (Database.SaveResult result : results) {
                    if (result.isSuccess()) {
                        successCount++;
                    } else {
                        errorCount++;
                        if (sampleError == null && !result.getErrors().isEmpty()) {
                            sampleError = result.getErrors()[0].getMessage();
                        }
                    }
                }
                
                totalProcessed += successCount;
                totalErrors += errorCount;
            }
            
        } catch (Exception e) {
            totalErrors += links.size();
            if (sampleError == null) {
                sampleError = e.getMessage() + '\n' + e.getStackTraceString();
            }
            System.debug(LoggingLevel.ERROR, 'Error in BatchExtractContentDocumentLinks: ' + e.getMessage());
        }
    }
    
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