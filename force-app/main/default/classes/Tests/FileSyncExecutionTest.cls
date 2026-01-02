/**
 * Test class for FileSyncExecution components.
 * Validates the execution orchestration logic including batch job scheduling and mode handling.
 *
 * @author Mritesh Adak
 * @since 1.0
 */
@isTest
private class FileSyncExecutionTest {
    @testSetup
    static void setup() {
        // Create parent record
        Account a = new Account(Name = 'ExecutionTestAcc');
        insert a;

        // Create an Attachment to be processed
        insert new Attachment(
            Name = 'test.pdf', 
            Body = Blob.valueOf('data'), 
            ParentId = a.Id
        );

        // Create a Unified File record that will be orphaned (simulating a deletion)
        // We use a dummy ID that won't exist in the system
        insert new Unified_File__c(
            FileTitle__c = 'OrphanedFile',
            SourceId__c = '00P000000000001', 
            SourceType__c = 'ATTACHMENT',
            IsDeleted__c = false
        );
    }

    @isTest
    static void testOrchestratorDeltaMode() {
        Test.startTest();
        // Delta mode should launch CV and Attachment batches, but NOT Reconciliation
        SyncOrchestrator.initiate(SyncMode.DELTA, 60);
        Test.stopTest();
        
        List<AsyncApexJob> jobs = [SELECT ApexClass.Name FROM AsyncApexJob WHERE JobType = 'BatchApex'];
        
        Boolean foundReconcile = false;
        for(AsyncApexJob job : jobs) {
            if(job.ApexClass.Name == 'BatchReconcileDeleted') foundReconcile = true;
        }

        Assert.isFalse(foundReconcile, 'Reconciliation batch should NOT run in DELTA mode');
    }

    @isTest
    static void testOrchestratorFullMode() {
        Test.startTest();
        // Full mode must launch the reconciliation batch
        SyncOrchestrator.initiate(SyncMode.FULL, null);
        Test.stopTest();
        
        List<AsyncApexJob> jobs = [SELECT ApexClass.Name FROM AsyncApexJob WHERE JobType = 'BatchApex'];
        
        Boolean foundReconcile = false;
        for(AsyncApexJob job : jobs) {
            if(job.ApexClass.Name == 'BatchReconcileDeleted') foundReconcile = true;
        }

        Assert.isTrue(foundReconcile, 'Reconciliation batch MUST be enqueued in FULL mode');
    }

    @isTest
    static void testAttachmentBatchExecution() {
        BatchExtractAttachments batch = new BatchExtractAttachments(SyncMode.FULL, null);
        
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Unified_File__c WHERE SourceType__c = 'ATTACHMENT' AND FileTitle__c = 'test.pdf'];
        Assert.areEqual(1, count, 'Batch should have processed the new attachment');
    }

    @isTest
    static void testReconcileDeletedLogic() {
        // This test specifically triggers the batch logic to ensure it marks orphans
        Test.startTest();
        Database.executeBatch(new BatchReconcileDeleted());
        Test.stopTest();

        Unified_File__c orphaned = [SELECT IsDeleted__c FROM Unified_File__c WHERE FileTitle__c = 'OrphanedFile' LIMIT 1];
        Assert.isTrue(orphaned.IsDeleted__c, 'Orphaned unified record should be marked as deleted');
    }
}
