/**
 * @description Service class to map source records to FileDTO
 * @author Mritesh Adak
 * @date 2025
 */
public with sharing class FileRecordMapper {
    
    /**
     * @description Maps ContentVersion to FileDTO
     * @param cv ContentVersion record
     * @return FileDTO Mapped file data
     */
    public static FileDTO fromContentVersion(ContentVersion cv) {
        FileDTO dto = new FileDTO();
        
        dto.sourceType = SourceType.CONTENT_DOCUMENT;
        dto.sourceId = cv.ContentDocumentId;
        dto.latestVersionId = cv.Id;
        dto.title = cv.Title;
        dto.extension = cv.FileExtension;
        dto.sizeKb = cv.ContentSize != null ? (Integer)(cv.ContentSize / 1024) : 0;
        dto.createdDate = cv.CreatedDate;
        dto.createdById = cv.CreatedById;
        dto.lastModifiedDate = cv.LastModifiedDate;
        dto.lastModifiedById = cv.LastModifiedById;
        dto.isArchived = cv.IsLatest == false;
        dto.isDeleted = cv.IsDeleted;
        
        dto.isContentNote = (cv.FileType == 'SNOTE');
        if (dto.isContentNote) {
            dto.sourceType = SourceType.CONTENT_NOTE;
        }
        
        return dto;
    }
    
    /**
     * @description Maps Attachment to FileDTO
     * @param att Attachment record
     * @return FileDTO Mapped file data
     */
    public static FileDTO fromAttachment(Attachment att) {
        FileDTO dto = new FileDTO();
        
        dto.sourceType = SourceType.ATTACHMENT;
        dto.sourceId = att.Id;
        dto.latestVersionId = att.Id;
        dto.title = att.Name;
        
        if (String.isNotBlank(att.Name) && att.Name.contains('.')) {
            dto.extension = att.Name.substringAfterLast('.');
        }
        
        dto.sizeKb = att.BodyLength != null ? (Integer)(att.BodyLength / 1024) : 0;
        dto.createdDate = att.CreatedDate;
        dto.createdById = att.CreatedById;
        dto.lastModifiedDate = att.LastModifiedDate;
        dto.lastModifiedById = att.LastModifiedById;
        dto.parentRecordId = att.ParentId;
        dto.isDeleted = att.IsDeleted;
        
        if (att.ParentId != null) {
            dto.parentRecordType = att.ParentId.getSObjectType().getDescribe().getName();
        }
        
        return dto;
    }
    
    /**
     * @description Maps ContentNote to FileDTO
     * @param cv ContentVersion record with FileType = 'SNOTE'
     * @return FileDTO Mapped file data
     */
    public static FileDTO fromContentNote(ContentVersion cv) {
        FileDTO dto = fromContentVersion(cv);
        dto.sourceType = SourceType.CONTENT_NOTE;
        dto.isContentNote = true;
        return dto;
    }
    
    /**
     * @description Bulk mapping for ContentVersions
     * @param contentVersions List of ContentVersion records
     * @return List<FileDTO> Mapped DTOs
     */
    public static List<FileDTO> fromContentVersions(List<ContentVersion> contentVersions) {
        List<FileDTO> dtos = new List<FileDTO>();
        
        for (ContentVersion cv : contentVersions) {
            try {
                dtos.add(fromContentVersion(cv));
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error mapping ContentVersion ' + cv.Id + ': ' + e.getMessage());
            }
        }
        
        return dtos;
    }
    
    /**
     * @description Bulk mapping for Attachments
     * @param attachments List of Attachment records
     * @return List<FileDTO> Mapped DTOs
     */
    public static List<FileDTO> fromAttachments(List<Attachment> attachments) {
        List<FileDTO> dtos = new List<FileDTO>();
        
        for (Attachment att : attachments) {
            try {
                dtos.add(fromAttachment(att));
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error mapping Attachment ' + att.Id + ': ' + e.getMessage());
            }
        }
        
        return dtos;
    }
}