/**
 * @description Batch job to extract and process ContentVersions
 * @author Mritesh Adak
 * @date 2025
 */
public with sharing class BatchExtractContentVersions implements Database.Batchable<SObject>, Database.Stateful {
    
    private SyncMode mode;
    private Integer lookbackMinutes;
    private Integer totalProcessed = 0;
    private Integer totalErrors = 0;
    private String sampleError;
    private Unified_Sync_Log__c logRecord;
    
    public BatchExtractContentVersions(SyncMode mode, Integer lookbackMinutes) {
        this.mode = mode;
        this.lookbackMinutes = lookbackMinutes;
    }
    
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
    
    public void execute(Database.BatchableContext bc, List<ContentVersion> contentVersions) {
        try {
            List<FileDTO> fileDtos = FileRecordMapper.fromContentVersions(contentVersions);
            
            Set<Id> documentIds = new Set<Id>();
            for (ContentVersion cv : contentVersions) {
                documentIds.add(cv.ContentDocumentId);
            }
            
            Map<Id, ParentInfo> parentMap = ParentSelectorService.selectPrimaryParentsForDocuments(documentIds);
            
            for (FileDTO dto : fileDtos) {
                ParentInfo parentInfo = parentMap.get(dto.sourceId);
                if (parentInfo != null && parentInfo.isValid()) {
                    dto.parentRecordId = parentInfo.parentRecordId;
                    dto.parentRecordType = parentInfo.parentRecordType;
                    dto.parentRecordName = parentInfo.parentRecordName;
                }
            }
            
            List<Database.UpsertResult> results = UnifiedFileUpsertService.upsertUnifiedFiles(fileDtos);
            
            Map<String, Integer> summary = UnifiedFileUpsertService.analyzeSaveResults(results);
            totalProcessed += summary.get('success');
            totalErrors += summary.get('errors');
            
            if (sampleError == null) {
                for (Database.UpsertResult result : results) {
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