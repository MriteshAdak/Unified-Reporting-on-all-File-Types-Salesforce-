/**
 * Test class for FileSyncService components.
 * Validates service layer functionality including unified file upsert and sync logging.
 *
 * @author Mritesh Adak
 * @since 1.0
 */
@isTest
private class FileSyncServiceTest {
    @isTest
    static void testUnifiedFileUpsert() {
        FileDTO dto = new FileDTO();
        dto.sourceType = SourceType.ATTACHMENT;
        dto.sourceId = Id.valueOf('00P000000000001AAA'); // ensure Id-typed sourceId
        dto.title = 'ServiceTest';
        // Ensure ownership derivation has a non-null user context
        dto.createdById = UserInfo.getUserId();
        dto.lastModifiedById = UserInfo.getUserId();
        
        Test.startTest();
        List<Database.UpsertResult> results = UnifiedFileUpsertService.upsertUnifiedFiles(new List<FileDTO>{dto});
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Upsert should return one result');
        Assert.isTrue(results[0].isSuccess(), 'Upsert should be successful');
    }

    @isTest
    static void testLoggingService() {
        Test.startTest();
        Unified_Sync_Log__c log = UnifiedSyncLogService.startLog('TestBatch', 'FULL');
        insert log;
        UnifiedSyncLogService.completeLog(log, 100, 0, null);
        Test.stopTest();

        Unified_Sync_Log__c result = [SELECT Status__c, RecordCount__c FROM Unified_Sync_Log__c WHERE Id = :log.Id];
        Assert.areEqual('SUCCESS', result.Status__c, 'Log status should be SUCCESS');
        Assert.areEqual(100, result.RecordCount__c, 'Record count should be updated');
    }
}
