/**
 * @description Batch job to extract and process Attachments for unified file synchronization
 * @author Mritesh Adak
 * @date 2025
 * @since 1.0
 */
public with sharing class BatchExtractAttachments implements Database.Batchable<SObject>, Database.Stateful {
    
    private SyncMode mode;
    private Integer lookbackMinutes;
    private Integer totalProcessed = 0;
    private Integer totalErrors = 0;
    private String sampleError;
    private Unified_Sync_Log__c logRecord;
    
    /**
     * @description Constructor for BatchExtractAttachments
     * @param mode The synchronization mode (FULL or DELTA)
     * @param lookbackMinutes The lookback window in minutes for delta sync
     */
    public BatchExtractAttachments(SyncMode mode, Integer lookbackMinutes) {
        this.mode = mode;
        this.lookbackMinutes = lookbackMinutes;
    }
    
    /**
     * @description Starts the batch job by preparing the query
     * @param bc The batchable context
     * @return Database.QueryLocator The query locator for Attachment records
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        this.logRecord = UnifiedSyncLogService.startLog(
            'BatchExtractAttachments',
            mode.name()
        );
        
        String query = 'SELECT Id, Name, BodyLength, ParentId, ' +
                      'CreatedDate, CreatedById, LastModifiedDate, ' +
                      'LastModifiedById, IsDeleted, OwnerId ' +
                      'FROM Attachment';
        
        if (mode == SyncMode.DELTA && lookbackMinutes != null) {
            Datetime lookbackTime = Datetime.now().addMinutes(-lookbackMinutes);
            query += ' WHERE LastModifiedDate >= :lookbackTime';
        }
        
        System.debug('BatchExtractAttachments query: ' + query);
        return Database.getQueryLocator(query);
    }
    
    /**
     * @description Processes a batch of Attachment records
     * @param bc The batchable context
     * @param attachments The list of Attachment records to process
     */
    public void execute(Database.BatchableContext bc, List<Attachment> attachments) {
        try {
            List<FileDTO> fileDtos = FileRecordMapper.fromAttachments(attachments);
            
            Set<Id> parentIds = new Set<Id>();
            Map<String, Set<Id>> parentTypeToIds = new Map<String, Set<Id>>();
            
            for (FileDTO dto : fileDtos) {
                if (dto.parentRecordId != null) {
                    String parentType = dto.parentRecordType;
                    if (!parentTypeToIds.containsKey(parentType)) {
                        parentTypeToIds.put(parentType, new Set<Id>());
                    }
                    parentTypeToIds.get(parentType).add(dto.parentRecordId);
                }
            }
            
            Map<Id, String> parentNamesMap = new Map<Id, String>();
            for (String parentType : parentTypeToIds.keySet()) {
                try {
                    String query = 'SELECT Id, Name FROM ' + parentType + 
                                 ' WHERE Id IN :parentTypeToIds.get(parentType)';
                    List<SObject> parents = Database.query(query);
                    for (SObject parent : parents) {
                        parentNamesMap.put(parent.Id, (String)parent.get('Name'));
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 'Could not query parent names for ' + 
                               parentType + ': ' + e.getMessage());
                }
            }
            
            for (FileDTO dto : fileDtos) {
                if (dto.parentRecordId != null && parentNamesMap.containsKey(dto.parentRecordId)) {
                    dto.parentRecordName = parentNamesMap.get(dto.parentRecordId);
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
            totalErrors += attachments.size();
            if (sampleError == null) {
                sampleError = e.getMessage() + '\n' + e.getStackTraceString();
            }
            System.debug(LoggingLevel.ERROR, 'Error in BatchExtractAttachments: ' + e.getMessage());
        }
    }
    
    /**
     * @description Completes the batch job
     * @param bc The batchable context
     */
    public void finish(Database.BatchableContext bc) {
        UnifiedSyncLogService.completeLog(
            logRecord,
            totalProcessed,
            totalErrors,
            sampleError
        );
        
        System.debug('BatchExtractAttachments completed: ' + totalProcessed + 
                    ' processed, ' + totalErrors + ' errors');
    }
}
