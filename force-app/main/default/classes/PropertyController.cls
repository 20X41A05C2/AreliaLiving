public with sharing class PropertyController {

    @AuraEnabled(cacheable=true)
    public static List<PropertyWrapper> getPropertiesWithImages() {
        List<Properties__c> props = [
            SELECT Id, Name__c, Price__c,
                (SELECT ContentDocument.LatestPublishedVersionId
                 FROM ContentDocumentLinks
                 WHERE ContentDocument.FileType IN ('JPG', 'PNG')
                 LIMIT 1)
            FROM Properties__c
        ];

        List<PropertyWrapper> results = new List<PropertyWrapper>();
        for (Properties__c prop : props) {
            String imageUrl = null;
            if (!prop.ContentDocumentLinks.isEmpty()) {
                Id versionId = prop.ContentDocumentLinks[0].ContentDocument.LatestPublishedVersionId;
                imageUrl = '/sfc/servlet.shepherd/version/download/' + versionId;
            }

            results.add(new PropertyWrapper(prop.Id, prop.Name__c, prop.Price__c, imageUrl));
        }
        return results;
    }

    @AuraEnabled
    public static void createInterestedContact(Id propertyId, Id contactId) {
        if (propertyId == null || contactId == null) {
            throw new AuraHandledException('Property and Contact are required');
        }

        Interested_Contacts__c ic = new Interested_Contacts__c(
            Propery_LF__c = propertyId,
            Contact_LF__c = contactId
        );
        insert ic;
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact> getContactList() {
        return [SELECT Id, Name FROM Contact LIMIT 50];
    }

    public class PropertyWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal price;
        @AuraEnabled public String imageUrl;

        public PropertyWrapper(Id id, String name, Decimal price, String imageUrl) {
            this.id = id;
            this.name = name;
            this.price = price;
            this.imageUrl = imageUrl;
        }
    }
}