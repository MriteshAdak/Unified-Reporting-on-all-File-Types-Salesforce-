/**
 * @description Service for upserting Unified_File__c records with idempotency
 * @author Mritesh Adak
 * @date 2025
 */
public with sharing class UnifiedFileUpsertService {
    
    /**
     * @description Upserts file DTOs to Unified_File__c with delta checking
     * @param fileDtos List of file DTOs to upsert
     * @return List<Database.UpsertResult> Results of the upsert operation
     */
    public static List<Database.UpsertResult> upsertUnifiedFiles(List<FileDTO> fileDtos) {
        if (fileDtos == null || fileDtos.isEmpty()) {
            return new List<Database.UpsertResult>();
        }
        
        Set<String> hashKeys = new Set<String>();
        for (FileDTO dto : fileDtos) {
            hashKeys.add(dto.getHashKey());
        }
        
        Map<String, Unified_File__c> existingRecordsMap = new Map<String, Unified_File__c>();
        try {
            List<Unified_File__c> existingRecords = [
                SELECT Id, HashKey__c, FileTitle__c, FileExtension__c, FileSizeKB__c,
                       LastModifiedDate__c, LastModifiedById__c, ParentRecordId__c,
                       ParentRecordType__c, Visibility__c, IsArchived__c, IsDeleted__c
                FROM Unified_File__c
                WHERE HashKey__c IN :hashKeys
                WITH SECURITY_ENFORCED
            ];
            
            for (Unified_File__c record : existingRecords) {
                existingRecordsMap.put(record.HashKey__c, record);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error querying existing records: ' + e.getMessage());
        }
        
        List<FileDTO> changedDtos = DeltaChecker.filterChangedRecords(fileDtos, existingRecordsMap);
        
        if (changedDtos.isEmpty()) {
            System.debug('No changes detected, skipping upsert');
            return new List<Database.UpsertResult>();
        }
        
        OwnershipPolicy policy = OwnershipService.getCurrentPolicy();
        
        List<Unified_File__c> recordsToUpsert = new List<Unified_File__c>();
        for (FileDTO dto : changedDtos) {
            Unified_File__c record = mapToUnifiedSObject(dto, policy);
            recordsToUpsert.add(record);
        }
        
        List<Database.UpsertResult> results = Database.upsert(
            recordsToUpsert, 
            Unified_File__c.HashKey__c,
            false,
            AccessLevel.USER_MODE
        );
        
        return results;
    }
    
    /**
     * @description Maps FileDTO to Unified_File__c SObject
     * @param dto The file DTO
     * @param policy Ownership policy
     * @return Unified_File__c The mapped SObject
     */
    private static Unified_File__c mapToUnifiedSObject(FileDTO dto, OwnershipPolicy policy) {
        Unified_File__c record = new Unified_File__c();
        
        record.HashKey__c = dto.getHashKey();
        record.SourceType__c = dto.sourceType.name();
        record.SourceId__c = String.valueOf(dto.sourceId);
        record.LatestVersionId__c = String.valueOf(dto.latestVersionId);
        record.FileTitle__c = truncateString(dto.title, 255);
        record.FileExtension__c = truncateString(dto.extension, 40);
        record.FileSizeKB__c = dto.sizeKb;
        record.CreatedDate__c = dto.createdDate;
        record.CreatedById__c = dto.createdById;
        record.LastModifiedDate__c = dto.lastModifiedDate;
        record.LastModifiedById__c = dto.lastModifiedById;
        
        record.OwnerId = OwnershipService.deriveOwnerId(dto, policy);
        
        record.ParentRecordId__c = String.valueOf(dto.parentRecordId);
        record.ParentRecordType__c = truncateString(dto.parentRecordType, 80);
        record.ParentRecordName__c = truncateString(dto.parentRecordName, 255);
        
        record.Visibility__c = dto.visibility;
        record.BU__c = dto.businessUnit;
        record.IsArchived__c = dto.isArchived;
        record.IsDeleted__c = dto.isDeleted;
        record.IsContentNote__c = dto.isContentNote;
        record.SnapshotDate__c = Date.today();
        
        return record;
    }
    
    /**
     * @description Truncates a string to specified length
     * @param value The string to truncate
     * @param maxLength Maximum length
     * @return String Truncated string
     */
    private static String truncateString(String value, Integer maxLength) {
        if (String.isBlank(value)) {
            return value;
        }
        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }
    
    /**
     * @description Analyzes upsert results and returns summary
     * @param results List of upsert results
     * @return Map<String, Integer> Summary with success/error counts
     */
    public static Map<String, Integer> analyzeSaveResults(List<Database.UpsertResult> results) {
        Integer successCount = 0;
        Integer errorCount = 0;
        
        for (Database.UpsertResult result : results) {
            if (result.isSuccess()) {
                successCount++;
            } else {
                errorCount++;
                for (Database.Error error : result.getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'Upsert error: ' + error.getMessage());
                }
            }
        }
        
        return new Map<String, Integer>{
            'success' => successCount,
            'errors' => errorCount
        };
    }
}