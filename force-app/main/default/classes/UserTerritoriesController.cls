public with sharing class UserTerritoriesController {

    // *********************************************************************
    // getUserTerritoriesList() method - Recover territories assigned to a
    // User.
    // *********************************************************************
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

    // *********************************************************************
    // addUserTerritories() method - Check and assign selected territories
    // to an Account record.
    // *********************************************************************
    @AuraEnabled
    public static boolean addUserTerritories(Id AccountId, List<Id> lTerritories, boolean checkRules) {
        system.debug('### CVER - UserTerritoriesController - addUserTerritoriesToAccount - START - AccountId:' + AccountId + ' - lTerritories.size():' + lTerritories.size());

        Boolean bResponse = true;
        
        // Check Rules (just for demo purpose)
        if(checkRules){
            bResponse = checkTerritories(AccountId, lTerritories);
        }

        if(bResponse){
            // Synchronous mode
            addUserTerritoriesSync(AccountId, lTerritories);
            // Asynchronous mode
            //addUserTerritoriesAsync(AccountId, lTerritories);
            return true;
        }
        else{
            return false;
        }
    }    

    // *********************************************************************
    // checkTerritories() method - Check that selected territories respect
    // related territory assigment rules.
    // *********************************************************************
    // JUST AS AN EXAMPLE HERE, SHOULD BE BASED ON RuleTerritory2Association, ObjectTerritory2AssignmentRule, ObjectTerritory2AssignmentRuleItem objects
    // https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_erd_territory2.htm
    static boolean checkTerritories(Id AccountId, List<Id> lTerritories) {
        system.debug('### CVER - UserTerritoriesController - checkTerritories - START - AccountId:' + AccountId + ' - lTerritories.size():' + lTerritories.size());

        boolean bResponse = false;

        if(!lTerritories.isEmpty()){
            // Recover Territory Name
            list<Territory2> lTerritory2 = [SELECT DeveloperName FROM Territory2 WHERE Id IN :lTerritories];
            
            for(Territory2 oTerritory2:lTerritory2){
                system.debug('### CVER - UserTerritoriesController - checkTerritories - oTerritory2.DeveloperName:' + oTerritory2.DeveloperName);

                String sCountry = oTerritory2.DeveloperName.split('_')[0];
                String sActivity = oTerritory2.DeveloperName.split('_')[1];

                system.debug('### CVER - UserTerritoriesController - checkTerritories - sCountry:' + sCountry + ' - sActivity:' + sActivity);

                // Should be bulkified
                for(Account oAccount:[SELECT Id FROM ACCOUNT WHERE Id = :AccountId AND BillingCountry = :sCountry AND Activity__c includes (:sActivity)]){
                    bResponse = true;    
                }
            }
        }
        
        system.debug('### CVER - UserTerritoriesController - checkTerritories - bResponse:' + bResponse);

        return bResponse;
    }     

    // *********************************************************************
    // addUserTerritoriesSync() method - Assign selected territories to and
    // Account record in a synchronous mode.
    // *********************************************************************
    static void addUserTerritoriesSync(Id AccountId, List<Id> lTerritories) {
        system.debug('### CVER - UserTerritoriesController - addUserTerritoriesSync - START - AccountId:' + AccountId + ' - lTerritories.size():' + lTerritories.size());

        List<ObjectTerritory2Association> lObjectTerritoriesToInsert = new List<ObjectTerritory2Association>();
        
        if(!lTerritories.isEmpty()){
            for(Id oTerritory:lTerritories){
                system.debug('### CVER - UserTerritoriesController - addUserTerritoriesSync - oTerritory:' + oTerritory);

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
            }
        }
    }      

    // *********************************************************************
    // addUserTerritoriesAsync() method - Assign selected territories to and
    // Account record in an asynchronous mode.
    // *********************************************************************
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
                    System.debug('### CVER - UserTerritoriesController - addUserTerritoriesAsync - Successfully published event.');
                } else {
                    for(Database.Error err:oResult.getErrors()) {
                        System.debug('### CVER - UserTerritoriesController -  addUserTerritoriesAsync - Error returned: ' + err.getStatusCode() + ' - ' + err.getMessage());
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