/**
 * @description Queueable orchestrator to chain batch jobs sequentially
 * @author Master's Student - SDLC Demonstration
 * @date 2025
 */
public class SyncOrchestrator implements Queueable {
    
    private SyncMode mode;
    private Integer lookbackMinutes;
    private Integer currentStage;
    
    /**
     * @description Constructor
     * @param mode Sync mode (FULL or DELTA)
     * @param lookbackMinutes Lookback period for DELTA mode
     */
    public SyncOrchestrator(SyncMode mode, Integer lookbackMinutes) {
        this.mode = mode;
        this.lookbackMinutes = lookbackMinutes;
        this.currentStage = 1;
    }
    
    /**
     * @description Private constructor for stage progression
     * @param mode Sync mode
     * @param lookbackMinutes Lookback period
     * @param currentStage Current stage number
     */
    private SyncOrchestrator(SyncMode mode, Integer lookbackMinutes, Integer currentStage) {
        this.mode = mode;
        this.lookbackMinutes = lookbackMinutes;
        this.currentStage = currentStage;
    }
    
    /**
     * @description Execute method - chains batch jobs
     * @param context Queueable context
     */
    public void execute(QueueableContext context) {
        try {
            // Load configuration
            Unified_Sync_Config__mdt config = getConfig();
            
            if (currentStage == 1) {
                // Stage 1: ContentVersions (includes ContentNotes)
                executeBatchStage1(config);
            } else if (currentStage == 2) {
                // Stage 2: ContentDocumentLinks (update parents)
                executeBatchStage2(config);
            } else if (currentStage == 3) {
                // Stage 3: Attachments
                executeBatchStage3(config);
            } else {
                // All stages complete
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
    
    /**
     * @description Executes Stage 1 - ContentVersions
     * @param config Configuration from CMDT
     */
    private void executeBatchStage1(Unified_Sync_Config__mdt config) {
        Integer batchSize = Integer.valueOf(config.batchSizeContentVersion__c);
        
        BatchExtractContentVersions batch = new BatchExtractContentVersions(
            mode,
            lookbackMinutes
        );
        
        Id batchId = Database.executeBatch(batch, batchSize);
        System.debug('Started BatchExtractContentVersions with Id: ' + batchId);
        
        // Chain next stage
        chainNextStage();
    }
    
    /**
     * @description Executes Stage 2 - ContentDocumentLinks
     * @param config Configuration from CMDT
     */
    private void executeBatchStage2(Unified_Sync_Config__mdt config) {
        Integer batchSize = Integer.valueOf(config.batchSizeCDL__c);
        
        BatchExtractContentDocumentLinks batch = new BatchExtractContentDocumentLinks(
            mode,
            lookbackMinutes
        );
        
        Id batchId = Database.executeBatch(batch, batchSize);
        System.debug('Started BatchExtractContentDocumentLinks with Id: ' + batchId);
        
        // Chain next stage
        chainNextStage();
    }
    
    /**
     * @description Executes Stage 3 - Attachments
     * @param config Configuration from CMDT
     */
    private void executeBatchStage3(Unified_Sync_Config__mdt config) {
        Integer batchSize = Integer.valueOf(config.batchSizeAttachment__c);
        
        BatchExtractAttachments batch = new BatchExtractAttachments(
            mode,
            lookbackMinutes
        );
        
        Id batchId = Database.executeBatch(batch, batchSize);
        System.debug('Started BatchExtractAttachments with Id: ' + batchId);
        
        // Chain next stage (final)
        chainNextStage();
    }
    
    /**
     * @description Chains the next stage as a queueable
     */
    private void chainNextStage() {
        // Note: In production, consider adding delays or monitoring batch completion
        // For simplicity, we're chaining immediately
        // Alternative: Use Batch finish() method to chain next batch
        
        SyncOrchestrator nextStage = new SyncOrchestrator(
            mode,
            lookbackMinutes,
            currentStage + 1
        );
        
        // Queue next stage with a slight delay to avoid contention
        if (currentStage < 3) {
            System.enqueueJob(nextStage);
        }
    }
    
    /**
     * @description Gets configuration from CMDT
     * @return Unified_Sync_Config__mdt Configuration record
     */
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
            // Return defaults if CMDT not found
            System.debug(LoggingLevel.WARN, 'Could not load CMDT config, using defaults');
            return getDefaultConfig();
        }
    }
    
    /**
     * @description Returns default configuration
     * @return Unified_Sync_Config__mdt Default config
     */
    private Unified_Sync_Config__mdt getDefaultConfig() {
        Unified_Sync_Config__mdt config = new Unified_Sync_Config__mdt();
        config.batchSizeContentVersion__c = 200;
        config.batchSizeAttachment__c = 200;
        config.batchSizeCDL__c = 200;
        config.hourlyDeltaLookbackMins__c = 70;
        return config;
    }
    
    /**
     * @description Static method to initiate sync
     * @param mode Sync mode
     * @param lookbackMinutes Lookback period
     */
    public static void initiate(SyncMode mode, Integer lookbackMinutes) {
        SyncOrchestrator orchestrator = new SyncOrchestrator(mode, lookbackMinutes);
        System.enqueueJob(orchestrator);
    }
}