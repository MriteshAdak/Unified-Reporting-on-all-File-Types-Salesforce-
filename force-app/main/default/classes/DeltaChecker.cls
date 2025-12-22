/**
 * @description Service class to detect changes between FileDTO and existing Unified_File__c records
 * @author Mritesh Adak
 * @date 2025
 */
public with sharing class DeltaChecker {
    
    /**
     * @description Determines if a FileDTO has changes compared to existing record
     * @param fileDto The new file data
     * @param existingRecord The existing Unified_File__c record
     * @return Boolean True if changes detected, false otherwise
     */
    public static Boolean hasChanged(FileDTO fileDto, Unified_File__c existingRecord) {
        if (existingRecord == null) {
            return true;
        }
        
        if (isDifferent(fileDto.title, existingRecord.FileTitle__c)) return true;
        if (isDifferent(fileDto.extension, existingRecord.FileExtension__c)) return true;
        if (isDifferent(fileDto.sizeKb, existingRecord.FileSizeKB__c)) return true;
        if (isDifferent(fileDto.lastModifiedDate, existingRecord.LastModifiedDate__c)) return true;
        if (isDifferent(fileDto.lastModifiedById, existingRecord.LastModifiedById__c)) return true;
        if (isDifferent(fileDto.parentRecordId, existingRecord.ParentRecordId__c)) return true;
        if (isDifferent(fileDto.parentRecordType, existingRecord.ParentRecordType__c)) return true;
        if (isDifferent(fileDto.visibility, existingRecord.Visibility__c)) return true;
        if (isDifferent(fileDto.isArchived, existingRecord.IsArchived__c)) return true;
        if (isDifferent(fileDto.isDeleted, existingRecord.IsDeleted__c)) return true;
        
        return false;
    }
    
    /**
     * @description Compares two objects for differences
     * @param newValue The new value
     * @param oldValue The existing value
     * @return Boolean True if different
     */
    private static Boolean isDifferent(Object newValue, Object oldValue) {
        if (newValue == null && oldValue == null) return false;
        if (newValue == null || oldValue == null) return true;
        return newValue != oldValue;
    }
    
    /**
     * @description Bulk method to filter only changed records
     * @param fileDtos List of file DTOs
     * @param existingRecordsMap Map of existing records by hash key
     * @return List<FileDTO> Only records with changes
     */
    public static List<FileDTO> filterChangedRecords(
        List<FileDTO> fileDtos, 
        Map<String, Unified_File__c> existingRecordsMap
    ) {
        List<FileDTO> changedRecords = new List<FileDTO>();
        
        for (FileDTO dto : fileDtos) {
            String hashKey = dto.getHashKey();
            Unified_File__c existingRecord = existingRecordsMap.get(hashKey);
            
            if (hasChanged(dto, existingRecord)) {
                changedRecords.add(dto);
            }
        }
        
        return changedRecords;
    }
}