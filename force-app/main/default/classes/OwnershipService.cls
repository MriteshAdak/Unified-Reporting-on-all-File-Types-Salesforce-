/**
 * @description Service to derive OwnerId based on configurable policy
 * @author Mritesh Adak
 * @date 2025
 */
public with sharing class OwnershipService {
    
    /**
     * @description Derives OwnerId based on policy from CMDT
     * @param fileDto The file DTO
     * @param policy The ownership policy to apply
     * @return Id The derived owner ID
     */
    public static Id deriveOwnerId(FileDTO fileDto, OwnershipPolicy policy) {
        if (policy == OwnershipPolicy.LATEST_VERSION_MODIFIER) {
            return deriveFromLatestModifier(fileDto);
        } else if (policy == OwnershipPolicy.PARENT_OWNER) {
            return deriveFromParentOwner(fileDto);
        } else if (policy == OwnershipPolicy.ATTACHMENT_OWNER) {
            return deriveFromAttachmentOwner(fileDto);
        }
        
        return deriveFromLatestModifier(fileDto);
    }
    
    /**
     * @description Derives owner from latest modifier
     * @param fileDto The file DTO
     * @return Id Owner ID
     */
    private static Id deriveFromLatestModifier(FileDTO fileDto) {
        if (fileDto.lastModifiedById != null) {
            return fileDto.lastModifiedById;
        }
        return fileDto.createdById;
    }
    
    /**
     * @description Derives owner from parent record's owner
     * @param fileDto The file DTO
     * @return Id Owner ID
     */
    private static Id deriveFromParentOwner(FileDTO fileDto) {
        if (fileDto.parentRecordId == null) {
            return deriveFromLatestModifier(fileDto);
        }
        
        try {
            String parentType = fileDto.parentRecordType;
            if (String.isBlank(parentType)) {
                parentType = fileDto.parentRecordId.getSObjectType().getDescribe().getName();
            }
            
            String query = 'SELECT OwnerId FROM ' + parentType + ' WHERE Id = :fileDto.parentRecordId LIMIT 1';
            SObject parentRecord = Database.query(query);
            Id ownerId = (Id)parentRecord.get('OwnerId');
            
            return ownerId != null ? ownerId : deriveFromLatestModifier(fileDto);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Could not derive owner from parent: ' + e.getMessage());
            return deriveFromLatestModifier(fileDto);
        }
    }
    
    /**
     * @description Derives owner from Attachment's OwnerId field
     * @param fileDto The file DTO
     * @return Id Owner ID
     */
    private static Id deriveFromAttachmentOwner(FileDTO fileDto) {
        if (fileDto.sourceType == SourceType.ATTACHMENT && fileDto.sourceId != null) {
            try {
                Attachment att = [SELECT OwnerId FROM Attachment WHERE Id = :fileDto.sourceId LIMIT 1];
                return att.OwnerId != null ? att.OwnerId : deriveFromLatestModifier(fileDto);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Could not query Attachment owner: ' + e.getMessage());
            }
        }
        
        return deriveFromLatestModifier(fileDto);
    }
    
    /**
     * @description Gets the current ownership policy from Custom Metadata
     * @return OwnershipPolicy The configured policy
     */
    public static OwnershipPolicy getCurrentPolicy() {
        try {
            Unified_Sync_Config__mdt config = [
                SELECT ownershipPolicy__c 
                FROM Unified_Sync_Config__mdt 
                WHERE DeveloperName = 'Default' 
                LIMIT 1
            ];
            
            String policyValue = config.ownershipPolicy__c;
            
            if (policyValue == 'PARENT_OWNER') {
                return OwnershipPolicy.PARENT_OWNER;
            } else if (policyValue == 'ATTACHMENT_OWNER') {
                return OwnershipPolicy.ATTACHMENT_OWNER;
            }
            
            return OwnershipPolicy.LATEST_VERSION_MODIFIER;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Could not load ownership policy from CMDT: ' + e.getMessage());
            return OwnershipPolicy.LATEST_VERSION_MODIFIER;
        }
    }
    
    /**
     * @description Bulk method to derive owner IDs for multiple files
     * @param fileDtos List of file DTOs
     * @param policy The ownership policy
     * @return Map<String, Id> Map of hash key to owner ID
     */
    public static Map<String, Id> deriveOwnerIds(List<FileDTO> fileDtos, OwnershipPolicy policy) {
        Map<String, Id> ownerIdMap = new Map<String, Id>();
        
        for (FileDTO dto : fileDtos) {
            Id ownerId = deriveOwnerId(dto, policy);
            ownerIdMap.put(dto.getHashKey(), ownerId);
        }
        
        return ownerIdMap;
    }
}