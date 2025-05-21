public with sharing class VendorContactController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getProjects() {
        List<Map<String, Object>> projectList = new List<Map<String, Object>>();
        
        // Query Project__c with related Supervisor and Client names
        for (Project__c proj : [
            SELECT Id, Name, Start_Date__c, End_Date__c, Budget__c, 
                Supervisor__r.Name, Client__r.Name
            FROM Project__c
            WHERE CreatedById = :UserInfo.getUserId()
            ORDER BY CreatedDate DESC
            LIMIT 100
        ]) {
            // Create a map to include all fields, including related names
            Map<String, Object> projectMap = new Map<String, Object>();
            projectMap.put('Id', proj.Id);
            projectMap.put('Name', proj.Name);
            projectMap.put('Start_Date__c', proj.Start_Date__c);
            projectMap.put('End_Date__c', proj.End_Date__c);
            projectMap.put('Budget__c', proj.Budget__c);
            projectMap.put('Supervisor__c', proj.Supervisor__r != null ? proj.Supervisor__r.Name : '');
            projectMap.put('Client__c', proj.Client__r != null ? proj.Client__r.Name : '');
            
            projectList.add(projectMap);
        }
        
        return projectList;
}
    // @AuraEnabled(cacheable=true)
    // public static List<String> getVendorCategories() {
    //     Set<String> categories = new Set<String>();
    //     for (Vendor__c v : [SELECT Vendor_Category__c FROM Vendor__c WHERE Vendor_Category__c != null]) {
    //         categories.add(v.Vendor_Category__c);
    //     }
    //     return new List<String>(categories);
    // }

    /**
     * @description Retrieves picklist values for a given field.
     * @param field The sObjectField for which picklist values are needed.
     * @return A list of picklist values.
     */
    public static List<String> getPicklistValues(Schema.sObjectField field) {
        List<String> picklistValues = new List<String>();
        Schema.DescribeFieldResult fieldResult = field.getDescribe();
        List<Schema.PicklistEntry> values = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry entry : values) {
            picklistValues.add(entry.getLabel());
        }
        return picklistValues;
    }
     /**
     * @description Retrieves Academic Year picklist values from the Professional_Development__c object.
     * @return List of academic year picklist values.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getVendorCategoryPicklistValues() {
        return getPicklistValues(Vendor__c.Vendor_Category__c);
    }

    @AuraEnabled(cacheable=true)
    public static List<Vendor__c> getVendorContacts(String category) {
        if (category == 'All') {
            return [
                SELECT Id, Name, Email__c, Vendor_Category__c
                FROM Vendor__c
            ];
        } else {
            return [
                SELECT Id, Name, Email__c, Vendor_Category__c
                FROM Vendor__c
                WHERE Vendor_Category__c = :category
            ];
        }
    }

   @AuraEnabled
public static void sendEmailToVendors(List<Id> vendorIds, Id projectId) {
    try {
        if (vendorIds == null || vendorIds.isEmpty()) {
            throw new AuraHandledException('No vendors selected.');
        }
        if (projectId == null) {
            throw new AuraHandledException('Project ID is missing.');
        }

        // Get project details including Supervisor__c and Lead__c (the lookups)
                Project__c proj = [
            SELECT Id, Name, Start_Date__c, End_Date__c, Budget__c, 
                Supervisor__r.Name, Client__r.Name
            FROM Project__c 
            WHERE Id = :projectId 
            LIMIT 1
        ];
        
        // Get Vendors with emails
        List<Vendor__c> vendors = [
            SELECT Name__c, Email__c 
            FROM Vendor__c 
            WHERE Id IN :vendorIds AND Email__c != NULL
        ];

        if (vendors.isEmpty()) {
            throw new AuraHandledException('None of the selected vendors have email addresses.');
        }

        // Get Email Template
        EmailTemplate template = [
            SELECT Id, HtmlValue, Subject 
            FROM EmailTemplate 
            WHERE DeveloperName = 'Project_Vendor_Email_Template' 
            LIMIT 1
        ];

        if (String.isBlank(template.Subject) || String.isBlank(template.HtmlValue)) {
            throw new AuraHandledException('Email subject or body is empty in the template.');
        }
        

        // Get Attachments related to Site_Visit_Report__c
        // List<Attachment> attachmentsList = new List<Attachment>();
        // if (opp.Supervisor_Name__c != null && opp.Lead_Name__c != null) {
        //     attachmentsList = [
        //         SELECT Id, Name, Body, ContentType 
        //         FROM Attachment 
        //         WHERE ParentId IN (
        //             SELECT Id 
        //             FROM Site_Visit_Report__c 
        //             WHERE Supervisor__c = :opp.Supervisor_Name__c 
        //               AND Lead__c = :opp.Lead_Name__c
        //         )
        //     ];
        // }

        // Email body and subject preparation
            String vendorHtml = template.HtmlValue
        .replace('{{{Project__c.Name}}}', proj.Name)
        .replace('{{{Project__c.Budget__c}}}', String.valueOf(proj.Budget__c))
        .replace('{{{Project__c.Start_Date__c}}}', proj.Start_Date__c != null ? proj.Start_Date__c.format() : '')
        .replace('{{{Project__c.End_Date__c}}}', proj.End_Date__c != null ? proj.End_Date__c.format() : '')
        .replace('{{{Project__c.Supervisor__c}}}', proj.Supervisor__r != null ? proj.Supervisor__r.Name : '')
        .replace('{{{Project__c.Client__c}}}', proj.Client__r != null ? proj.Client__r.Name : '');

        String vendorSubject = template.Subject
            .replace('{{{Project__c.Name}}}', proj.Name);

        // Loop through vendors and create emails
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Vendor__c vendor : vendors) {
                    List<ContentDocumentLink> docLinks = [
                SELECT ContentDocumentId 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :projectId
            ];

            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink link : docLinks) {
                docIds.add(link.ContentDocumentId);
            }

            List<ContentVersion> contentVersions = new List<ContentVersion>();
            if (!docIds.isEmpty()) {
                contentVersions = [
                    SELECT Id, Title, VersionData 
                    FROM ContentVersion 
                    WHERE ContentDocumentId IN :docIds
                ];
            }

        List<Messaging.EmailFileAttachment> emailAttachments = new List<Messaging.EmailFileAttachment>();

        for (ContentVersion version : contentVersions) {
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(version.Title);
        attachment.setBody(version.VersionData);
        emailAttachments.add(attachment);
    }
 

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ vendor.Email__c });
            mail.setSubject(vendorSubject);
            mail.setHtmlBody(vendorHtml);
            mail.setSaveAsActivity(true);
            mail.setFileAttachments(emailAttachments);

            // List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
            // for (Attachment att : attachmentsList) {
            //     Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            //     efa.setFileName(att.Name);
            //     efa.setBody(att.Body);
            //     efa.setContentType(att.ContentType);
            //     attachments.add(efa);
            // }

            // if (!attachments.isEmpty()) {
            //     mail.setFileAttachments(attachments);
            // }

            emails.add(mail);
        }

        if (emails.isEmpty()) {
            throw new AuraHandledException('No emails created.');
        }

        Messaging.SendEmailResult[] results = Messaging.sendEmail(emails, false);

        for (Messaging.SendEmailResult res : results) {
            if (!res.isSuccess()) {
                throw new AuraHandledException('Email failed to send: ' + res.getErrors()[0].getMessage());
            }
        }

    } catch (Exception ex) {
        throw new AuraHandledException('Error sending emails: ' + ex.getMessage());
    }
}

}