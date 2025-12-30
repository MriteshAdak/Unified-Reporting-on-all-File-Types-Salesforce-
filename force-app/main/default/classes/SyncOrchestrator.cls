/**
 * @description Queueable orchestrator to chain batch jobs sequentially
 * @author Mritesh Adak
 * @date 2025
 */
public class SyncOrchestrator implements Queueable {
    
    private SyncMode mode;
    private Integer lookbackMinutes;
    
    public SyncOrchestrator(SyncMode mode, Integer lookbackMinutes) {
        this.mode = mode;
        this.lookbackMinutes = lookbackMinutes;
    }
    
    public void execute(QueueableContext context) {
        try {
            Unified_Sync_Config__mdt config = getConfig();
            
            // Start Flow A: ContentVersions (CV). CV.finish() will enqueue CDL.
            startContentVersions(config);
            
            // Start Flow B: Attachments in parallel.
            startAttachments(config);
            
            UnifiedSyncLogService.logSuccess(
                'SyncOrchestrator',
                mode.name() + '_LAUNCHED_PARALLEL',
                0
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in SyncOrchestrator: ' + e.getMessage());
            UnifiedSyncLogService.logFailure(
                'SyncOrchestrator',
                mode.name() + '_LAUNCH',
                e.getMessage()
            );
        }
    }
    
    private void startContentVersions(Unified_Sync_Config__mdt config) {
        Integer batchSize = Integer.valueOf(config.batchSizeContentVersion__c);
        Id batchId = Database.executeBatch(
            new BatchExtractContentVersions(mode, lookbackMinutes),
            batchSize
        );
        System.debug('Started BatchExtractContentVersions with Id: ' + batchId);
    }
    
    private void startAttachments(Unified_Sync_Config__mdt config) {
        Integer batchSize = Integer.valueOf(config.batchSizeAttachment__c);
        Id batchId = Database.executeBatch(
            new BatchExtractAttachments(mode, lookbackMinutes),
            batchSize
        );
        System.debug('Started BatchExtractAttachments with Id: ' + batchId);
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
        System.enqueueJob(new SyncOrchestrator(mode, lookbackMinutes));
    }
}
