public without sharing class ContactController {

    @AuraEnabled(cacheable=true)
    public static List<DataTableWrapper> getContactList() {
        List<Contact> lContacts =  [
            SELECT Id, FirstName, LastName, Title, Phone, Email
            FROM Contact
            WITH SECURITY_ENFORCED
            LIMIT 10
        ];

        List<DataTableWrapper> response = new List<DataTableWrapper>();

        for(Contact oContact:lContacts){
            DataTableWrapper obj = new DataTableWrapper();
            obj.Id = oContact.Id;
            obj.FirstName = oContact.FirstName;
            obj.LastName = oContact.LastName;
            obj.LastNameLink = '/' + oContact.Id;
            obj.Title = oContact.Title;
            obj.Phone = oContact.Phone;
            obj.Email = oContact.Email;
            response.add(obj);
        }

        return response;
    }

    private class DataTableWrapper {
        @AuraEnabled
        public Id Id {get;set;}
        @AuraEnabled
        public String FirstName {get;set;}
        @AuraEnabled
        public String LastName {get;set;}
        @AuraEnabled
        public String LastNameLink {get;set;}
        @AuraEnabled
        public String Title {get;set;}
        @AuraEnabled
        public String Phone {get;set;}        
        @AuraEnabled
        public String Email {get;set;}
    }
}