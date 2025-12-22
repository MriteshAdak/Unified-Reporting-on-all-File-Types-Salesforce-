/**
 * @description Scheduler for hourly delta synchronization
 * @author Mritesh Adak
 * @date 2025
 */
public class HourlyDeltaScheduler implements Schedulable {
    
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
    
    private Unified_Sync_Config__mdt getDefaultConfig() {
        Unified_Sync_Config__mdt config = new Unified_Sync_Config__mdt();
        config.hourlyDeltaEnabled__c = true;
        config.hourlyDeltaLookbackMins__c = 70;
        return config;
    }
    
    public static String scheduleHourly(String jobName) {
        String cronExpression = '0 0 * * * ?';
        
        HourlyDeltaScheduler scheduler = new HourlyDeltaScheduler();
        return System.schedule(jobName, cronExpression, scheduler);
    }
}