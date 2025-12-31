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
            // Check for concurrent run
            if (isAnotherRunActive(mode)) {
                System.debug('Another ' + mode.name() + ' run is already active, skipping this execution.');
                return;
            }
            
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
            return Unified_Sync_Config__mdt.getInstance('Default');
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
    
    /**
     * @description Checks if another sync run of the same mode is already active
     * @param mode The sync mode to check
     * @return Boolean True if another run is active, false otherwise
     */
    private static Boolean isAnotherRunActive(SyncMode mode) {
        try {
            // Query for any currently running sync logs for the same mode
            List<Unified_Sync_Log__c> activeLogs = [
                SELECT Id FROM Unified_Sync_Log__c 
                WHERE Status__c = 'RUNNING' AND Stage__c = :mode.name() + '_LAUNCHED_PARALLEL'
                LIMIT 1
            ];
            
            return !activeLogs.isEmpty();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error checking for active runs: ' + e.getMessage());
            // When in doubt, prevent the run to avoid conflicts
            return true;
        }
    }
}
