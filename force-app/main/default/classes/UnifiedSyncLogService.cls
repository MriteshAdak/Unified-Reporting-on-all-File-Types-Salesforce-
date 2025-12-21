/**
 * @description Service for logging synchronization operations
 * @author Master's Student - SDLC Demonstration
 * @date 2025
 */
public with sharing class UnifiedSyncLogService {
    
    /**
     * @description Logs a sync operation
     * @param batchName Name of the batch job
     * @param stage Stage of the sync process
     * @param recordCount Number of records processed
     * @param errorCount Number of errors encountered
     * @param sampleError Sample error message
     * @param status Status of the operation
     */
    public static void log(
        String batchName, 
        String stage,
        Integer recordCount, 
        Integer errorCount, 
        String sampleError,
        String status
    ) {
        try {
            Unified_Sync_Log__c logRecord = new Unified_Sync_Log__c(
                BatchName__c = batchName,
                Stage__c = stage,
                RecordCount__c = recordCount,
                ErrorCount__c = errorCount,
                SampleError__c = truncateError(sampleError),
                StartedAt__c = Datetime.now(),
                EndedAt__c = Datetime.now(),
                Status__c = status
            );
            
            Database.insert(logRecord, AccessLevel.USER_MODE);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to create sync log: ' + e.getMessage());
        }
    }
    
    /**
     * @description Creates a log record with start time
     * @param batchName Name of the batch
     * @param stage Stage of operation
     * @return Unified_Sync_Log__c The log record (not yet inserted)
     */
    public static Unified_Sync_Log__c startLog(String batchName, String stage) {
        return new Unified_Sync_Log__c(
            BatchName__c = batchName,
            Stage__c = stage,
            StartedAt__c = Datetime.now(),
            Status__c = 'RUNNING'
        );
    }
    
    /**
     * @description Completes and saves a log record
     * @param logRecord The log record to complete
     * @param recordCount Number of records processed
     * @param errorCount Number of errors
     * @param sampleError Sample error message
     */
    public static void completeLog(
        Unified_Sync_Log__c logRecord,
        Integer recordCount,
        Integer errorCount,
        String sampleError
    ) {
        if (logRecord == null) {
            return;
        }
        
        logRecord.EndedAt__c = Datetime.now();
        logRecord.RecordCount__c = recordCount;
        logRecord.ErrorCount__c = errorCount;
        logRecord.SampleError__c = truncateError(sampleError);
        
        // Determine status
        if (errorCount == 0) {
            logRecord.Status__c = 'SUCCESS';
        } else if (errorCount < recordCount) {
            logRecord.Status__c = 'PARTIAL';
        } else {
            logRecord.Status__c = 'FAILED';
        }
        
        try {
            Database.upsert(logRecord, AccessLevel.USER_MODE);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to save sync log: ' + e.getMessage());
        }
    }
    
    /**
     * @description Truncates error message to fit field length
     * @param error The error message
     * @return String Truncated error
     */
    private static String truncateError(String error) {
        if (String.isBlank(error)) {
            return null;
        }
        
        Integer maxLength = 32768; // Long Text Area field limit
        return error.length() > maxLength ? error.substring(0, maxLength) : error;
    }
    
    /**
     * @description Logs a simple success message
     * @param batchName Name of batch
     * @param stage Stage name
     * @param recordCount Number of records
     */
    public static void logSuccess(String batchName, String stage, Integer recordCount) {
        log(batchName, stage, recordCount, 0, null, 'SUCCESS');
    }
    
    /**
     * @description Logs a failure
     * @param batchName Name of batch
     * @param stage Stage name
     * @param errorMessage Error message
     */
    public static void logFailure(String batchName, String stage, String errorMessage) {
        log(batchName, stage, 0, 1, errorMessage, 'FAILED');
    }
}