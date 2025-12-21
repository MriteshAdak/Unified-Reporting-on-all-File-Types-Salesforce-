/**
 * @description Batch job to extract and process ContentVersions (including ContentNotes)
 * @author Master's Student - SDLC Demonstration
 * @date 2025
 */
public with sharing class BatchExtractContentVersions implements Database.Batchable<SObject>, Database.Stateful {
    
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
    public BatchExtractContentVersions(SyncMode mode, Integer lookbackMinutes) {
        this.mode = mode;
        this.lookbackMinutes = lookbackMinutes;
    }
    
    /**
     * @description Start method - builds query
     * @param bc Batch context
     * @return Database.QueryLocator Query locator for ContentVersions
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        this.logRecord = UnifiedSyncLogService.startLog(
            'BatchExtractContentVersions',
            mode.name()
        );
        
        String query = 'SELECT Id, ContentDocumentId, Title, FileExtension, FileType, ' +
                      'ContentSize, CreatedDate, CreatedById, LastModifiedDate, ' +
                      'LastModifiedById, IsLatest, IsDeleted ' +
                      'FROM ContentVersion ' +
                      'WHERE IsLatest = true';
        
        if (mode == SyncMode.DELTA && lookbackMinutes != null) {
            Datetime lookbackTime = Datetime.now().addMinutes(-lookbackMinutes);
            query += ' AND LastModifiedDate >= :lookbackTime';
        }
        
        System.debug('BatchExtractContentVersions query: ' + query);
        return Database.getQueryLocator(query);
    }
    
    /**
     * @description Execute method - processes batches
     * @param bc Batch context
     * @param contentVersions List of ContentVersions to process
     */
    public void execute(Database.BatchableContext bc, List<ContentVersion> contentVersions) {
        try {
            // Step 1: Map ContentVersions to DTOs
            List<FileDTO> fileDtos = FileRecordMapper.fromContentVersions(contentVersions);
            
            // Step 2: Enrich with parent information
            Set<Id> documentIds = new Set<Id>();
            for (ContentVersion cv : contentVersions) {
                documentIds.add(cv.ContentDocumentId);
            }
            
            Map<Id, ParentInfo> parentMap = ParentSelectorService.selectPrimaryParentsForDocuments(documentIds);
            
            // Apply parent info to DTOs
            for (FileDTO dto : fileDtos) {
                ParentInfo parentInfo = parentMap.get(dto.sourceId);
                if (parentInfo != null && parentInfo.isValid()) {
                    dto.parentRecordId = parentInfo.parentRecordId;
                    dto.parentRecordType = parentInfo.parentRecordType;
                    dto.parentRecordName = parentInfo.parentRecordName;
                }
            }
            
            // Step 3: Upsert to Unified_File__c
            List<Database.SaveResult> results = UnifiedFileUpsertService.upsertUnifiedFiles(fileDtos);
            
            // Step 4: Track results
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
            
        } catch (Exception e) {
            totalErrors += contentVersions.size();
            if (sampleError == null) {
                sampleError = e.getMessage() + '\n' + e.getStackTraceString();
            }
            System.debug(LoggingLevel.ERROR, 'Error in BatchExtractContentVersions: ' + e.getMessage());
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
        
        System.debug('BatchExtractContentVersions completed: ' + totalProcessed + 
                    ' processed, ' + totalErrors + ' errors');
    }
}