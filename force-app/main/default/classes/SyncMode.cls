/**
 * @description Enumeration for synchronization modes
 * @author Mritesh Adak
 * @date 2025
 * @since 1.0
 */
public enum SyncMode {
    /**
     * @description Full synchronization - processes all files
     */
    FULL,
    /**
     * @description Delta synchronization - processes only recently modified files
     */
    DELTA
}
