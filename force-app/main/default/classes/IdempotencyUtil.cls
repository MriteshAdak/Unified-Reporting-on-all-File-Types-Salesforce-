/**
 * @description Utility class for generating idempotent hash keys for file synchronization
 * @author Mritesh Adak
 * @date 2025
 * @since 1.0
 */
public with sharing class IdempotencyUtil {
    
    /**
     * @description Generates a unique hash key for a file record using SHA-256
     * @param sourceType The source type of the file
     * @param sourceId The source ID of the file
     * @return String A unique hash key
     */
    public static String makeHashKey(String sourceType, Id sourceId) {
        if (String.isBlank(sourceType) || sourceId == null) {
            throw new IllegalArgumentException('Source type and ID cannot be null');
        }
        
        String keyInput = sourceType + String.valueOf(sourceId);
        Blob keyBlob = Blob.valueOf(keyInput);
        Blob hashBlob = Crypto.generateDigest('SHA-256', keyBlob);
        String hashKey = EncodingUtil.convertToHex(hashBlob);
        
        return hashKey.substring(0, Math.min(64, hashKey.length()));
    }
    
    /**
     * @description Alternative simpler hash key for backwards compatibility
     * @param sourceType The source type
     * @param sourceId The source ID
     * @return String Simple concatenated key
     */
    public static String makeSimpleHashKey(String sourceType, Id sourceId) {
        if (String.isBlank(sourceType) || sourceId == null) {
            throw new IllegalArgumentException('Source type and ID cannot be null');
        }
        
        return sourceType + '_' + String.valueOf(sourceId);
    }
}
