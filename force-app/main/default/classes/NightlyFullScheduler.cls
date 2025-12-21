/**
 * @description Scheduler for nightly full synchronization
 * @author Master's Student - SDLC Demonstration
 * @date 2025
 */
public class NightlyFullScheduler implements Schedulable {
    
    /**
     * @description Execute method called by the scheduler
     * @param sc Schedulable context
     */
    public void execute(SchedulableContext sc) {
        System.debug('NightlyFullScheduler triggered at: ' + Datetime.now());
        
        try {
            // Load configuration
            Unified_Sync_Config__mdt config = getConfig();
            
            // Check if nightly full is enabled
            if (!config.nightlyFullEnabled__c) {
                System.debug('Nightly full sync is disabled in configuration');
                return;
            }
            
            // Initiate orchestrator with FULL mode (no lookback needed)
            SyncOrchestrator.initiate(SyncMode.FULL, null);
            
            System.debug('NightlyFullScheduler initiated FULL sync');
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in NightlyFullScheduler: ' + e.getMessage());
            UnifiedSyncLogService.logFailure(
                'NightlyFullScheduler',
                'SCHEDULE_EXECUTION',
                e.getMessage()
            );
        }
    }
    
    /**
     * @description Gets configuration from CMDT
     * @return Unified_Sync_Config__mdt Configuration record
     */
    private Unified_Sync_Config__mdt getConfig() {
        try {
            return [
                SELECT nightlyFullEnabled__c
                FROM Unified_Sync_Config__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
        } catch (Exception e) {
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
        config.nightlyFullEnabled__c = true;
        return config;
    }
    
    /**
     * @description Schedules the job to run nightly
     * @param jobName Name for the scheduled job
     * @param hour Hour to run (0-23, default 2 for 2 AM)
     * @return String The scheduled job ID
     */
    public static String scheduleNightly(String jobName, Integer hour) {
        if (hour == null || hour < 0 || hour > 23) {
            hour = 2; // Default to 2 AM
        }
        
        // Schedule to run every day at specified hour
        // CRON expression: 0 0 2 * * ? (every day at 2 AM)
        String cronExpression = '0 0 ' + hour + ' * * ?';
        
        NightlyFullScheduler scheduler = new NightlyFullScheduler();
        return System.schedule(jobName, cronExpression, scheduler);
    }
    
    /**
     * @description Convenience method with default time (2 AM)
     * @param jobName Name for the scheduled job
     * @return String The scheduled job ID
     */
    public static String scheduleNightly(String jobName) {
        return scheduleNightly(jobName, 2);
    }
}