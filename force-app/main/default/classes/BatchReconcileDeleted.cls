/**
 * @description Batch job to reconcile deleted files by marking Unified_File__c records
 *              where source records no longer exist in Salesforce
 * @author Mritesh Adak
 * @date 2025
 */
public with sharing class BatchReconcileDeleted implements Database.Batchable<SObject>, Database.Stateful {
    
    private Integer totalReconciled = 0;
    private Integer totalErrors = 0;
    private String sampleError;
    private Unified_Sync_Log__c logRecord;
    
    // Cached source IDs to avoid repeated queries
    private Set<Id> existingContentDocumentIds;
    private Set<Id> existingAttachmentIds;
    private Boolean idsLoaded = false;
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        this.logRecord = UnifiedSyncLogService.startLog(
            'BatchReconcileDeleted',
            'RECONCILIATION'
        );
        
        // Query all Unified_File__c records that are currently marked as not deleted
        String query = 'SELECT Id, SourceType__c, SourceId__c, IsDeleted__c ' +
                      'FROM Unified_File__c ' +
                      'WHERE IsDeleted__c = false';
        
        System.debug('BatchReconcileDeleted query: ' + query);
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext bc, List<Unified_File__c> records) {
        try {
            // Load all source IDs once (first batch only)
            if (!idsLoaded) {
                loadExistingSourceIds();
                idsLoaded = true;
            }
            
            List<Unified_File__c> toUpdate = new List<Unified_File__c>();
            
            for (Unified_File__c uf : records) {
                Boolean sourceExists = checkSourceExists(uf);
                
                if (!sourceExists) {
                    uf.IsDeleted__c = true;
                    toUpdate.add(uf);
                }
            }
            
            if (!toUpdate.isEmpty()) {
                List<Database.SaveResult> results = Database.update(
                    toUpdate,
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
                
                totalReconciled += successCount;
                totalErrors += errorCount;
            }
            
        } catch (Exception e) {
            totalErrors += records.size();
            if (sampleError == null) {
                sampleError = e.getMessage() + '\n' + e.getStackTraceString();
            }
            System.debug(LoggingLevel.ERROR, 'Error in BatchReconcileDeleted: ' + e.getMessage());
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        UnifiedSyncLogService.completeLog(
            logRecord,
            totalReconciled,
            totalErrors,
            sampleError
        );
        
        System.debug('BatchReconcileDeleted completed: ' + totalReconciled + 
                    ' records marked as deleted, ' + totalErrors + ' errors');
    }
    
    /**
     * @description Loads all existing source IDs into memory for efficient lookup
     * This runs once at the start to avoid repeated queries
     */
    private void loadExistingSourceIds() {
        try {
            // Load all ContentDocument IDs
            existingContentDocumentIds = new Set<Id>();
            for (ContentDocument cd : [SELECT Id FROM ContentDocument]) {
                existingContentDocumentIds.add(cd.Id);
            }
            
            System.debug('Loaded ' + existingContentDocumentIds.size() + ' ContentDocument IDs');
            
            // Load all Attachment IDs
            existingAttachmentIds = new Set<Id>();
            for (Attachment att : [SELECT Id FROM Attachment]) {
                existingAttachmentIds.add(att.Id);
            }
            
            System.debug('Loaded ' + existingAttachmentIds.size() + ' Attachment IDs');
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error loading source IDs: ' + e.getMessage());
            // Initialize empty sets to prevent null pointer exceptions
            if (existingContentDocumentIds == null) {
                existingContentDocumentIds = new Set<Id>();
            }
            if (existingAttachmentIds == null) {
                existingAttachmentIds = new Set<Id>();
            }
        }
    }
    
    /**
     * @description Checks if the source record still exists in Salesforce
     * @param uf The Unified_File__c record to check
     * @return Boolean True if source exists, false if deleted
     */
    private Boolean checkSourceExists(Unified_File__c uf) {
        if (String.isBlank(uf.SourceId__c)) {
            return false;
        }
        
        try {
            Id sourceId = Id.valueOf(uf.SourceId__c);
            
            if (uf.SourceType__c == 'CONTENT_DOCUMENT' || uf.SourceType__c == 'CONTENT_NOTE') {
                return existingContentDocumentIds.contains(sourceId);
            } else if (uf.SourceType__c == 'ATTACHMENT') {
                return existingAttachmentIds.contains(sourceId);
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Invalid source ID format: ' + uf.SourceId__c);
            return false;
        }
        
        return false;
    }
}