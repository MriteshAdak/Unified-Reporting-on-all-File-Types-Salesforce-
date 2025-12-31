/**
 * @description Scheduler for hourly delta synchronization of files
 * @author Mritesh Adak
 * @date 2025
 * @since 1.0
 */
public class HourlyDeltaScheduler implements Schedulable {
    
    /**
     * @description Executes the scheduled job for hourly delta synchronization
     * @param sc The schedulable context
     */
    public void execute(SchedulableContext sc) {
        System.debug('HourlyDeltaScheduler triggered at: ' + Datetime.now());
        
        try {
            Unified_Sync_Config__mdt config = getConfig();
            
            if (!config.hourlyDeltaEnabled__c) {
                System.debug('Hourly delta sync is disabled in configuration');
                return;
            }
            
            Integer lookbackMinutes = Integer.valueOf(config.hourlyDeltaLookbackMins__c);
            
            SyncOrchestrator.initiate(SyncMode.DELTA, lookbackMinutes);
            
            System.debug('HourlyDeltaScheduler initiated DELTA sync with lookback: ' + 
                        lookbackMinutes + ' minutes');
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in HourlyDeltaScheduler: ' + e.getMessage());
            UnifiedSyncLogService.logFailure(
                'HourlyDeltaScheduler',
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
        config.hourlyDeltaEnabled__c = true;
        config.hourlyDeltaLookbackMins__c = 70;
        return config;
    }
    
    /**
     * @description Schedules the hourly delta sync job
     * @param jobName The name of the scheduled job
     * @return String The job ID
     */
    public static String scheduleHourly(String jobName) {
        String cronExpression = '0 0 * * * ?';
        
        HourlyDeltaScheduler scheduler = new HourlyDeltaScheduler();
        return System.schedule(jobName, cronExpression, scheduler);
    }
}
