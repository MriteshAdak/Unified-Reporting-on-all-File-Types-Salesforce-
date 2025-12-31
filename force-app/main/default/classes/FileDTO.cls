/**
 * @description Data Transfer Object for file information across the sync pipeline
 * @author Mritesh Adak
 * @date 2025
 * @since 1.0
 */
public class FileDTO {
    public SourceType sourceType { get; set; }
    public Id sourceId { get; set; }
    public Id latestVersionId { get; set; }
    public String title { get; set; }
    public String extension { get; set; }
    public Integer sizeKb { get; set; }
    public Datetime createdDate { get; set; }
    public Id createdById { get; set; }
    public Datetime lastModifiedDate { get; set; }
    public Id lastModifiedById { get; set; }
    public Id parentRecordId { get; set; }
    public String parentRecordType { get; set; }
    public String parentRecordName { get; set; }
    public String visibility { get; set; }
    public String businessUnit { get; set; }
    public Boolean isArchived { get; set; }
    public Boolean isDeleted { get; set; }
    public Boolean isContentNote { get; set; }
    
    /**
     * @description Default constructor for FileDTO
     */
    public FileDTO() {
        this.isArchived = false;
        this.isDeleted = false;
        this.isContentNote = false;
    }
    
    /**
     * @description Generates a hash key for idempotency
     * @return String Hash key combining source type and ID
     */
    public String getHashKey() {
        return IdempotencyUtil.makeHashKey(this.sourceType.name(), this.sourceId);
    }
}
