/**
 * @description Scheduler for nightly full synchronization
 * @author Mritesh Adak
 * @date 2025
 */
public class NightlyFullScheduler implements Schedulable {
    
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
    
    private Unified_Sync_Config__mdt getDefaultConfig() {
        Unified_Sync_Config__mdt config = new Unified_Sync_Config__mdt();
        config.nightlyFullEnabled__c = true;
        return config;
    }
    
    public static String scheduleNightly(String jobName, Integer hour) {
        if (hour == null || hour < 0 || hour > 23) {
            hour = 2;
        }
        
        String cronExpression = '0 0 ' + hour + ' * * ?';
        
        NightlyFullScheduler scheduler = new NightlyFullScheduler();
        return System.schedule(jobName, cronExpression, scheduler);
    }
    
    public static String scheduleNightly(String jobName) {
        return scheduleNightly(jobName, 2);
    }
}