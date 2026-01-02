@isTest
private class BatchReconcileDeletedTest {
    @testSetup
    static void setup() {
        // 1. Create a Parent Account
        Account acc = new Account(Name = 'Reconcile Test Acc');
        insert acc;

        // 2. Create an Attachment and its Unified record
        Attachment att = new Attachment(
            Name = 'ToKeep.pdf', 
            Body = Blob.valueOf('Test Content'), 
            ParentId = acc.Id
        );
        insert att;
        
        insert new Unified_File__c(
            FileTitle__c = 'ToKeep.pdf',
            SourceId__c = att.Id,
            SourceType__c = 'ATTACHMENT',
            IsDeleted__c = false
        );

        // 3. Create a ContentDocument and its Unified record
        ContentVersion cv = new ContentVersion(
            Title = 'ToDelete',
            PathOnClient = 'ToDelete.txt',
            VersionData = Blob.valueOf('Content'),
            IsMajorVersion = true
        );
        insert cv;
        
        Id cdId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        
        insert new Unified_File__c(
            FileTitle__c = 'ToDelete',
            SourceId__c = cdId,
            SourceType__c = 'CONTENT_DOCUMENT',
            IsDeleted__c = false
        );
    }

    @isTest
    static void testReconciliationOfDeletedSource() {
        // Delete the ContentDocument to simulate an orphaned Unified record
        ContentDocument cd = [SELECT Id FROM ContentDocument LIMIT 1];
        delete cd;

        Test.startTest();
        BatchReconcileDeleted batch = new BatchReconcileDeleted();
        Database.executeBatch(batch);
        Test.stopTest();

        // Verify "ToDelete" is now marked as deleted
        Unified_File__c deletedFile = [SELECT IsDeleted__c FROM Unified_File__c WHERE FileTitle__c = 'ToDelete' LIMIT 1];
        Assert.isTrue(deletedFile.IsDeleted__c, 'Unified record for deleted source should be marked as deleted');

        // Verify "ToKeep" remains active
        Unified_File__c activeFile = [SELECT IsDeleted__c FROM Unified_File__c WHERE FileTitle__c = 'ToKeep.pdf' LIMIT 1];
        Assert.isFalse(activeFile.IsDeleted__c, 'Unified record for existing source should remain active');
        
        // Verify Log Record creation and values
        List<Unified_Sync_Log__c> logs = [
            SELECT Status__c, RecordCount__c, Stage__c, BatchName__c, ErrorCount__c 
            FROM Unified_Sync_Log__c 
            WHERE BatchName__c = 'BatchReconcileDeleted' AND Stage__c = 'RECONCILIATION'
        ];
        Assert.isFalse(logs.isEmpty(), 'A sync log record should have been created');
        // Expect SUCCESS when errors are zero
        Boolean anySuccess = false;
        for (Unified_Sync_Log__c l : logs) {
            if (l.Status__c == 'SUCCESS') {
                anySuccess = true;
                break;
            }
        }
        Assert.isTrue(anySuccess, 'Reconciliation log should indicate SUCCESS when no errors occurred');
    }

    @isTest
    static void testInvalidSourceIdHandling() {
        // Create a record with a malformed Source ID
        insert new Unified_File__c(
            FileTitle__c = 'InvalidID',
            SourceId__c = 'INVALID_SFDC_ID',
            SourceType__c = 'ATTACHMENT',
            IsDeleted__c = false
        );

        Test.startTest();
        Database.executeBatch(new BatchReconcileDeleted());
        Test.stopTest();

        Unified_File__c invalidFile = [SELECT IsDeleted__c FROM Unified_File__c WHERE FileTitle__c = 'InvalidID' LIMIT 1];
        Assert.isTrue(invalidFile.IsDeleted__c, 'Records with invalid IDs should be caught and marked as deleted by the catch block');
    }
}
