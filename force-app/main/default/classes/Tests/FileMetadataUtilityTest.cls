/**
 * Test class for FileMetadataUtility components.
 * Validates utility methods for idempotency hash generation and parent information validation.
 *
 * @author Mritesh Adak
 * @since 1.0
 */
@isTest
private class FileMetadataUtilityTest {
    @isTest
    static void testIdempotencyHashGeneration() {
        Id mockId = Id.valueOf('001000000000001AAA');
        Test.startTest();
        String hash1 = IdempotencyUtil.makeHashKey('ATTACHMENT', mockId);
        String hash2 = IdempotencyUtil.makeHashKey('ATTACHMENT', mockId);
        String simpleKey = IdempotencyUtil.makeSimpleHashKey('ATTACHMENT', mockId);
        // Different id should produce different hash
        String differentHash = IdempotencyUtil.makeHashKey('ATTACHMENT', Id.valueOf('001000000000002AAA'));
        Test.stopTest();

        Assert.areEqual(64, hash1.length(), 'Hash should be SHA-256 hex string');
        Assert.areEqual(hash1, hash2, 'Hash generation must be consistent');
        Assert.isTrue(simpleKey.contains('ATTACHMENT'), 'Simple key should contain prefix');
        Assert.isTrue(hash1 != differentHash, 'Different IDs must yield different hashes');
    }

    @isTest
    static void testParentInfoValidation() {
        ParentInfo info = new ParentInfo('001000000000001AAA', 'Account', 'Test');
        Assert.isTrue(info.isValid(), 'Info with ID should be valid');
        
        ParentInfo invalid = new ParentInfo(null, null, null);
        Assert.isFalse(invalid.isValid(), 'Info without ID should be invalid');
    }
}
