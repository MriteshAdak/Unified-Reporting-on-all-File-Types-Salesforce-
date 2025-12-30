/**
 * @description Service class to detect changes between FileDTO and existing Unified_File__c records
 * @author Mritesh Adak
 * @date 2025
 */
public with sharing class DeltaChecker {
    
    // Constants mirroring field truncation limits used in UnifiedFileUpsertService.mapToUnifiedSObject
    private static final Integer MAX_TITLE = 255;
    private static final Integer MAX_EXT = 40;
    private static final Integer MAX_PARENT_TYPE = 80;
    private static final Integer MAX_PARENT_NAME = 255;
    
    /**
     * @description Determines if a FileDTO has changes compared to existing record (normalized compare)
     * @param fileDto The new file data
     * @param existingRecord The existing Unified_File__c record
     * @return Boolean True if changes detected, false otherwise
     */
    public static Boolean hasChanged(FileDTO fileDto, Unified_File__c existingRecord) {
        if (existingRecord == null) {
            return true;
        }
        // Normalize strings (trim + truncation parity) and case where appropriate
        String dtoTitle = normAndTruncate(fileDto.title, MAX_TITLE, false);
        String recTitle = norm(existingRecord.FileTitle__c, false);
        
        String dtoExt = toLower(normAndTruncate(fileDto.extension, MAX_EXT, true));
        String recExt = toLower(norm(existingRecord.FileExtension__c, true));
        
        String dtoParentType = normAndTruncate(fileDto.parentRecordType, MAX_PARENT_TYPE, false);
        String recParentType = norm(existingRecord.ParentRecordType__c, false);
        
        String dtoParentName = normAndTruncate(fileDto.parentRecordName, MAX_PARENT_NAME, false);
        String recParentName = norm(existingRecord.ParentRecordName__c, false);
        
        String dtoVisibility = toLower(norm(fileDto.visibility, true));
        String recVisibility = toLower(norm(existingRecord.Visibility__c, true));
        
        String dtoBU = norm(fileDto.businessUnit, false);
        String recBU = norm(existingRecord.BU__c, false);
        
        String dtoSourceType = fileDto.sourceType == null ? null : String.valueOf(fileDto.sourceType.name());
        String recSourceType = existingRecord.SourceType__c;
        
        String dtoSourceId = fileDto.sourceId == null ? null : String.valueOf(fileDto.sourceId);
        String recSourceId = existingRecord.SourceId__c;
        
        String dtoLatestVer = fileDto.latestVersionId == null ? null : String.valueOf(fileDto.latestVersionId);
        String recLatestVer = existingRecord.LatestVersionId__c;
        
        // Primitive/Date/Datetime compares
        if (diff(dtoTitle, recTitle)) return true;
        if (diff(dtoExt, recExt)) return true;
        if (diff(fileDto.sizeKb, existingRecord.FileSizeKB__c)) return true;
        if (diff(fileDto.createdDate, existingRecord.CreatedDate__c)) return true;
        if (diff(fileDto.createdById, existingRecord.CreatedById__c)) return true;
        if (diff(fileDto.lastModifiedDate, existingRecord.LastModifiedDate__c)) return true;
        if (diff(fileDto.lastModifiedById, existingRecord.LastModifiedById__c)) return true;
        
        if (diff(fileDto.parentRecordId == null ? null : String.valueOf(fileDto.parentRecordId), existingRecord.ParentRecordId__c)) return true;
        if (diff(dtoParentType, recParentType)) return true;
        if (diff(dtoParentName, recParentName)) return true;
        
        if (diff(dtoVisibility, recVisibility)) return true;
        if (diff(fileDto.isArchived, existingRecord.IsArchived__c)) return true;
        if (diff(fileDto.isDeleted, existingRecord.IsDeleted__c)) return true;
        if (diff(fileDto.isContentNote, existingRecord.IsContentNote__c)) return true;
        
        if (diff(dtoBU, recBU)) return true;
        
        // Defensive checks
        if (diff(dtoSourceType, recSourceType)) return true;
        if (diff(dtoSourceId, recSourceId)) return true;
        
        // Critical: latest version change must trigger update
        if (diff(dtoLatestVer, recLatestVer)) return true;
        
        return false;
    }
    
    // Null-safe, trimmed string
    private static String norm(String s, Boolean toEmptyIfNull) {
        if (s == null) return toEmptyIfNull ? '' : null;
        String t = s.trim();
        return toEmptyIfNull && t == null ? '' : t;
    }
    
    // Null-safe, trimmed, truncated to length
    private static String normAndTruncate(String s, Integer maxLen, Boolean toEmptyIfNull) {
        String t = norm(s, toEmptyIfNull);
        if (t == null) return null;
        return t.length() > maxLen ? t.substring(0, maxLen) : t;
    }
    
    private static String toLower(String s) {
        return s == null ? null : s.toLowerCase();
    }
    
    /**
     * @description Compares two values for difference (null-safe)
     */
    private static Boolean diff(Object oldValue, Object newValue) {
        if (oldValue == null && newValue == null) return false;
        if (oldValue == null || newValue == null) return true;
        return oldValue != newValue;
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
        if (fileDtos == null || fileDtos.isEmpty()) return changedRecords;
        
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
