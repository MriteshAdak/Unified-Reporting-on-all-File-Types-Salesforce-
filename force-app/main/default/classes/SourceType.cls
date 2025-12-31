/**
 * @description Enumeration for file source types
 * @author Mritesh Adak
 * @date 2025
 * @since 1.0
 */
public enum SourceType {
    /**
     * @description File sourced from ContentDocument
     */
    CONTENT_DOCUMENT,
    /**
     * @description File sourced from Attachment
     */
    ATTACHMENT,
    /**
     * @description File sourced from ContentNote (special case of ContentDocument)
     */
    CONTENT_NOTE
}
