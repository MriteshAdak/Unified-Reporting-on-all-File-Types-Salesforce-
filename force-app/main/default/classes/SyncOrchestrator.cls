/**
 * @description Queueable orchestrator to chain batch jobs sequentially
 * @author Mritesh Adak
 * @date 2025
 */
public class SyncOrchestrator implements Queueable {
    
    private SyncMode mode;
    private Integer lookbackMinutes;
    private Integer currentStage;
    
    public SyncOrchestrator(SyncMode mode, Integer lookbackMinutes) {
        this.mode = mode;
        this.lookbackMinutes = lookbackMinutes;
        this.currentStage = 1;
    }
    
    private SyncOrchestrator(SyncMode mode, Integer lookbackMinutes, Integer currentStage) {
        this.mode = mode;
        this.lookbackMinutes = lookbackMinutes;
        this.currentStage = currentStage;
    }
    
    public void execute(QueueableContext context) {
        try {
            Unified_Sync_Config__mdt config = getConfig();
            
            if (currentStage == 1) {
                executeBatchStage1(config);
            } else if (currentStage == 2) {
                executeBatchStage2(config);
            } else if (currentStage == 3) {
                executeBatchStage3(config);
            } else {
                System.debug('SyncOrchestrator completed all stages for mode: ' + mode.name());
                UnifiedSyncLogService.logSuccess(
                    'SyncOrchestrator',
                    mode.name() + '_COMPLETE',
                    0
                );
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in SyncOrchestrator: ' + e.getMessage());
            UnifiedSyncLogService.logFailure(
                'SyncOrchestrator',
                mode.name() + '_STAGE_' + currentStage,
                e.getMessage()
            );
        }
    }
    
    private void executeBatchStage1(Unified_Sync_Config__mdt config) {
        Integer batchSize = Integer.valueOf(config.batchSizeContentVersion__c);
        
        BatchExtractContentVersions batch = new BatchExtractContentVersions(
            mode,
            lookbackMinutes
        );
        
        Id batchId = Database.executeBatch(batch, batchSize);
        System.debug('Started BatchExtractContentVersions with Id: ' + batchId);
        
        chainNextStage();
    }
    
    private void executeBatchStage2(Unified_Sync_Config__mdt config) {
        Integer batchSize = Integer.valueOf(config.batchSizeCDL__c);
        
        BatchExtractContentDocumentLinks batch = new BatchExtractContentDocumentLinks(
            mode,
            lookbackMinutes
        );
        
        Id batchId = Database.executeBatch(batch, batchSize);
        System.debug('Started BatchExtractContentDocumentLinks with Id: ' + batchId);
        
        chainNextStage();
    }
    
    private void executeBatchStage3(Unified_Sync_Config__mdt config) {
        Integer batchSize = Integer.valueOf(config.batchSizeAttachment__c);
        
        BatchExtractAttachments batch = new BatchExtractAttachments(
            mode,
            lookbackMinutes
        );
        
        Id batchId = Database.executeBatch(batch, batchSize);
        System.debug('Started BatchExtractAttachments with Id: ' + batchId);
        
        chainNextStage();
    }
    
    private void chainNextStage() {
        SyncOrchestrator nextStage = new SyncOrchestrator(
            mode,
            lookbackMinutes,
            currentStage + 1
        );
        
        if (currentStage < 3) {
            System.enqueueJob(nextStage);
        }
    }
    
    private Unified_Sync_Config__mdt getConfig() {
        try {
            return [
                SELECT batchSizeContentVersion__c, batchSizeAttachment__c, 
                       batchSizeCDL__c, hourlyDeltaLookbackMins__c
                FROM Unified_Sync_Config__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Could not load CMDT config, using defaults');
            return getDefaultConfig();
        }
    }
    
    private Unified_Sync_Config__mdt getDefaultConfig() {
        Unified_Sync_Config__mdt config = new Unified_Sync_Config__mdt();
        config.batchSizeContentVersion__c = 200;
        config.batchSizeAttachment__c = 200;
        config.batchSizeCDL__c = 200;
        config.hourlyDeltaLookbackMins__c = 70;
        return config;
    }
    
    public static void initiate(SyncMode mode, Integer lookbackMinutes) {
        SyncOrchestrator orchestrator = new SyncOrchestrator(mode, lookbackMinutes);
        System.enqueueJob(orchestrator);
    }
}