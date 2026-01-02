@isTest
private class FileSyncCoreLogicTest {
    @testSetup
    static void setup() {
        Account acc = new Account(Name = 'Parent Acc');
        insert acc;
        
        ContentVersion cv = new ContentVersion(
            Title = 'LogicTest',
            PathOnClient = 'test.txt',
            VersionData = Blob.valueOf('Content'),
            IsMajorVersion = true
        );
        insert cv;
    }

    @isTest
    static void testFileRecordMapping() {
        ContentVersion cv = [SELECT Id, ContentDocumentId, Title, FileExtension, ContentSize, 
                                    CreatedDate, CreatedById, LastModifiedDate, LastModifiedById, 
                                    IsLatest, FileType, IsDeleted FROM ContentVersion LIMIT 1];
        
        Test.startTest();
        FileDTO dto = FileRecordMapper.fromContentVersion(cv);
        Test.stopTest();

        Assert.areEqual(cv.Title, dto.title, 'Title mapping failed');
        Assert.areEqual(SourceType.CONTENT_DOCUMENT, dto.sourceType, 'Source type should be CONTENT_DOCUMENT');
    }

    @isTest
    static void testDeltaChangeDetection() {
        FileDTO dto = new FileDTO();
        dto.title = 'Old Title';
        dto.sizeKb = 10;

        Unified_File__c existing = new Unified_File__c(
            FileTitle__c = 'Old Title',
            FileSizeKB__c = 10
        );

        Test.startTest();
        Boolean noChange = DeltaChecker.hasChanged(dto, existing);
        dto.title = 'New Title';
        Boolean hasChange = DeltaChecker.hasChanged(dto, existing);
        Test.stopTest();

        Assert.isFalse(noChange, 'Should detect no change');
        Assert.isTrue(hasChange, 'Should detect title change');
    }
}