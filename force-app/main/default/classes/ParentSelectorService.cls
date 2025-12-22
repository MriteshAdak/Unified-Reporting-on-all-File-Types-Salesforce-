/**
 * @description Service to select primary parent from ContentDocumentLinks
 * Rule: Filter out User parents, choose first non-User link
 * @author Mritesh Adak
 * @date 2025
 */
public with sharing class ParentSelectorService {
    
    /**
     * @description Selects the primary parent from a list of ContentDocumentLinks
     * @param links List of ContentDocumentLinks for a document
     * @return ParentInfo The selected primary parent information
     */
    public static ParentInfo selectPrimaryParent(List<ContentDocumentLink> links) {
        if (links == null || links.isEmpty()) {
            return new ParentInfo(null, null, null);
        }
        
        // Step 1: Filter out User parents if other sObjects exist
        List<ContentDocumentLink> nonUserLinks = new List<ContentDocumentLink>();
        List<ContentDocumentLink> userLinks = new List<ContentDocumentLink>();
        
        for (ContentDocumentLink link : links) {
            if (link.LinkedEntityId != null) {
                String entityType = link.LinkedEntityId.getSObjectType().getDescribe().getName();
                if (entityType == 'User') {
                    userLinks.add(link);
                } else {
                    nonUserLinks.add(link);
                }
            }
        }
        
        // Step 2: Choose which list to use
        List<ContentDocumentLink> candidateLinks = nonUserLinks.isEmpty() ? userLinks : nonUserLinks;
        
        if (candidateLinks.isEmpty()) {
            return new ParentInfo(null, null, null);
        }
        
        // Step 3: Select the first link (deterministic approach)
        ContentDocumentLink selectedLink = candidateLinks[0];
        
        return extractParentInfo(selectedLink);
    }
    
    /**
     * @description Extracts parent information from a ContentDocumentLink
     * @param link The selected ContentDocumentLink
     * @return ParentInfo Parent information object
     */
    private static ParentInfo extractParentInfo(ContentDocumentLink link) {
        if (link == null || link.LinkedEntityId == null) {
            return new ParentInfo(null, null, null);
        }
        
        Id parentId = link.LinkedEntityId;
        String parentType = parentId.getSObjectType().getDescribe().getName();
        String parentName = null;
        
        // Attempt to get parent name if available
        try {
            String query = 'SELECT Name FROM ' + parentType + ' WHERE Id = :parentId LIMIT 1';
            SObject parentRecord = Database.query(query);
            parentName = (String)parentRecord.get('Name');
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Could not retrieve name for ' + parentType + ': ' + e.getMessage());
        }
        
        return new ParentInfo(parentId, parentType, parentName);
    }
    
    /**
     * @description Bulk method to select parents for multiple documents
     * @param contentDocumentIds Set of ContentDocument IDs
     * @return Map<Id, ParentInfo> Map of document ID to parent info
     */
    public static Map<Id, ParentInfo> selectPrimaryParentsForDocuments(Set<Id> contentDocumentIds) {
        Map<Id, ParentInfo> documentToParentMap = new Map<Id, ParentInfo>();
        
        if (contentDocumentIds.isEmpty()) {
            return documentToParentMap;
        }
        
        // Query all links for these documents
        List<ContentDocumentLink> allLinks = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :contentDocumentIds
            WITH SECURITY_ENFORCED
        ];
        
        // Group links by ContentDocumentId
        Map<Id, List<ContentDocumentLink>> documentToLinksMap = new Map<Id, List<ContentDocumentLink>>();
        
        for (ContentDocumentLink link : allLinks) {
            if (!documentToLinksMap.containsKey(link.ContentDocumentId)) {
                documentToLinksMap.put(link.ContentDocumentId, new List<ContentDocumentLink>());
            }
            documentToLinksMap.get(link.ContentDocumentId).add(link);
        }
        
        // Select parent for each document
        for (Id documentId : documentToLinksMap.keySet()) {
            ParentInfo parent = selectPrimaryParent(documentToLinksMap.get(documentId));
            documentToParentMap.put(documentId, parent);
        }
        
        return documentToParentMap;
    }
}