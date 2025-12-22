/**
 * @description Wrapper class for parent record information
 * @author Mritesh Adak
 * @date 2025
 */
public class ParentInfo {
    public Id parentRecordId { get; set; }
    public String parentRecordType { get; set; }
    public String parentRecordName { get; set; }
    
    /**
     * @description Constructor with parameters
     * @param parentId The ID of the parent record
     * @param parentType The sObject type of the parent
     * @param parentName The name of the parent record
     */
    public ParentInfo(Id parentId, String parentType, String parentName) {
        this.parentRecordId = parentId;
        this.parentRecordType = parentType;
        this.parentRecordName = parentName;
    }
    
    /**
     * @description Checks if parent info is valid
     * @return Boolean True if parent ID is not null
     */
    public Boolean isValid() {
        return this.parentRecordId != null;
    }
}