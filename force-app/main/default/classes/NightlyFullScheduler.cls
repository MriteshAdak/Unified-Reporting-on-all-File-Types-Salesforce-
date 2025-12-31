/**
 * @description Scheduler for nightly full synchronization of files
 * @author Mritesh Adak
 * @date 2025
 * @since 1.0
 */
public class NightlyFullScheduler implements Schedulable {
    
    /**
     * @description Executes the scheduled job for nightly full synchronization
     * @param sc The schedulable context
     */
    public void execute(SchedulableContext sc) {
        System.debug('NightlyFullScheduler triggered at: ' + Datetime.now());
        
        try {
            Unified_Sync_Config__mdt config = getConfig();
            
            if (!config.nightlyFullEnabled__c) {
                System.debug('Nightly full sync is disabled in configuration');
                return;
            }
            
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
     * @description Gets the synchronization configuration
     * @return Unified_Sync_Config__mdt The configuration object
     */
    private Unified_Sync_Config__mdt getConfig() {
        try {
            return Unified_Sync_Config__mdt.getInstance('Default');
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Could not load CMDT config, using defaults');
            return getDefaultConfig();
        }
    }
    
    /**
     * @description Gets the default synchronization configuration
     * @return Unified_Sync_Config__mdt The default configuration object
     */
    private Unified_Sync_Config__mdt getDefaultConfig() {
        Unified_Sync_Config__mdt config = new Unified_Sync_Config__mdt();
        config.nightlyFullEnabled__c = true;
        return config;
    }
    
    /**
     * @description Schedules the nightly full sync job
     * @param jobName The name of the scheduled job
     * @param hour The hour to run the job (0-23)
     * @return String The job ID
     */
    public static String scheduleNightly(String jobName, Integer hour) {
        if (hour == null || hour < 0 || hour > 23) {
            hour = 2;
        }
        
        String cronExpression = '0 0 ' + hour + ' * * ?';
        
        NightlyFullScheduler scheduler = new NightlyFullScheduler();
        return System.schedule(jobName, cronExpression, scheduler);
    }
    
    /**
     * @description Schedules the nightly full sync job at default hour (2AM)
     * @param jobName The name of the scheduled job
     * @return String The job ID
     */
    public static String scheduleNightly(String jobName) {
        return scheduleNightly(jobName, 2);
    }
}
