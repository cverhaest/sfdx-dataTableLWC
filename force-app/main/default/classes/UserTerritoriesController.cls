public with sharing class UserTerritoriesController {

    //@AuraEnabled(cacheable=true)
    //Do not use "cacheable" in order to be able to refresh the data
    @AuraEnabled
    public static List<DataTableWrapper> getUserTerritoriesList(Id AccountId) {
        system.debug('### CVER - UserTerritoriesController - getUserTerritoriesList - START - AccountId:' + AccountId);

        List<UserTerritory2Association> lUserTerritories =  [
            SELECT Id, Territory2Id, Territory2.Name FROM UserTerritory2Association WHERE UserId = :UserInfo.getUserId() 
            AND Territory2Id NOT IN (SELECT Territory2Id FROM ObjectTerritory2Association WHERE ObjectId = :AccountId)
            LIMIT 10
        ];

        system.debug('### CVER - UserTerritoriesController - getUserTerritoriesList - lUserTerritories.size:' + lUserTerritories.size());

        List<DataTableWrapper> response = new List<DataTableWrapper>();

        for(UserTerritory2Association oUserTerritory:lUserTerritories){
            DataTableWrapper obj = new DataTableWrapper();
            obj.TerritoryId = oUserTerritory.Territory2Id;
            obj.TerritoryName = oUserTerritory.Territory2.Name;
            response.add(obj);
        }

        system.debug('### CVER - UserTerritoriesController - getUserTerritoriesList - response:' + response);

        return response;
    }

    @AuraEnabled
    public static void addUserTerritories(Id AccountId, List<Id> lTerritories) {
        system.debug('### CVER - UserTerritoriesController - addUserTerritoriesToAccount - START - AccountId:' + AccountId + ' - lTerritories.size():' + lTerritories.size());

        addUserTerritoriesAsync(AccountId, lTerritories);
    }    

    @future
    static void addUserTerritoriesAsync(Id AccountId, List<Id> lTerritories) {
        system.debug('### CVER - UserTerritoriesController - addUserTerritoriesAsync - START - AccountId:' + AccountId + ' - lTerritories.size():' + lTerritories.size());

        List<ObjectTerritory2Association> lObjectTerritoriesToInsert = new List<ObjectTerritory2Association>();
        
        if(!lTerritories.isEmpty()){
            for(Id oTerritory:lTerritories){
                system.debug('### CVER - UserTerritoriesController - addUserTerritoriesAsync - oTerritory:' + oTerritory);

                lObjectTerritoriesToInsert.add(
                    new ObjectTerritory2Association(
                        ObjectId = AccountId,
                        Territory2Id = oTerritory,
                        AssociationCause = 'Territory2Manual'
                    )
                );
            }

            if(!lObjectTerritoriesToInsert.isEmpty()){
                insert lObjectTerritoriesToInsert;

                // Refresh the component using Platform Events
                Refresh_Event__e oRefreshEvent = new Refresh_Event__e(RecordId__c = AccountId);
                Database.SaveResult oResult = EventBus.publish(oRefreshEvent);
 
                if (oResult.isSuccess()) {
                    System.debug('### CVER - UserTerritoriesController - Successfully published event.');
                } else {
                    for(Database.Error err:oResult.getErrors()) {
                        System.debug('### CVER - UserTerritoriesController -  Error returned: ' + err.getStatusCode() + ' - ' + err.getMessage());
                    }
                }    
            }
        }
    }    

    private class DataTableWrapper {
        @AuraEnabled
        public String TerritoryId {get;set;}        
        @AuraEnabled
        public String TerritoryName {get;set;}
    }
}