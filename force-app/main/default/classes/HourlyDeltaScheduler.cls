/**
 * @description Scheduler for hourly delta synchronization
 * @author Master's Student - SDLC Demonstration
 * @date 2025
 */
public class HourlyDeltaScheduler implements Schedulable {
    
    /**
     * @description Execute method called by the scheduler
     * @param sc Schedulable context
     */
    public void execute(SchedulableContext sc) {
        System.debug('HourlyDeltaScheduler triggered at: ' + Datetime.now());
        
        try {
            // Load configuration
            Unified_Sync_Config__mdt config = getConfig();
            
            // Check if hourly delta is enabled
            if (!config.hourlyDeltaEnabled__c) {
                System.debug('Hourly delta sync is disabled in configuration');
                return;
            }
            
            // Get lookback minutes from config
            Integer lookbackMinutes = Integer.valueOf(config.hourlyDeltaLookbackMins__c);
            
            // Initiate orchestrator
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
     * @description Gets configuration from CMDT
     * @return Unified_Sync_Config__mdt Configuration record
     */
    private Unified_Sync_Config__mdt getConfig() {
        try {
            return [
                SELECT hourlyDeltaEnabled__c, hourlyDeltaLookbackMins__c
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
        config.hourlyDeltaEnabled__c = true;
        config.hourlyDeltaLookbackMins__c = 70;
        return config;
    }
    
    /**
     * @description Schedules the job to run hourly
     * @param jobName Name for the scheduled job
     * @return String The scheduled job ID
     */
    public static String scheduleHourly(String jobName) {
        // Schedule to run every hour
        // CRON expression: 0 0 * * * ? (every hour at minute 0)
        String cronExpression = '0 0 * * * ?';
        
        HourlyDeltaScheduler scheduler = new HourlyDeltaScheduler();
        return System.schedule(jobName, cronExpression, scheduler);
    }
}