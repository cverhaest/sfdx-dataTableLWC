import { LightningElement, wire, api, track } from 'lwc';
import getUserTerritoriesList from '@salesforce/apex/UserTerritoriesController.getUserTerritoriesList';
import addUserTerritories from '@salesforce/apex/UserTerritoriesController.addUserTerritories';
import { updateRecord } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import ID_FIELD from '@salesforce/schema/Territory2.Id';
import NAME_FIELD from '@salesforce/schema/Territory2.Name';
import UserId from '@salesforce/user/Id';

// Emp API
// https://developer.salesforce.com/docs/component-library/bundle/lightning-emp-api/documentation
import { subscribe, unsubscribe, onError, setDebugFlag, isEmpEnabled } from 'lightning/empApi';


const COLS = [
    //{ label: 'Id', fieldName: 'TerritoryId', editable: false },
    { label: 'Territory Name', fieldName: 'TerritoryName', editable: false }
];

export default class UserTerritoriesDataTable_LWC extends LightningElement {
    @track error;
    @track columns = COLS;
    @api recordId;
    @api singleRowSelection;
    @track userTerritories = [{}];
    @track selectedRows = [{}];
    currentUserId = UserId;

    subscription = {};    
    channelName = '/event/Refresh_Event__e';


    /*@wire(getUserTerritoriesList)
    wiredGetUserTerritoriesList(result) {
        console.log('### UserTerritoriesDataTable_LWC - wiredGetUserTerritoriesList() - START');
        console.log('### UserTerritoriesDataTable_LWC - wiredGetUserTerritoriesList() - result:' + result);

        if(result){
            this.userTerritories = result;
            this.error = null;            
        }
        else if(error) {
            this.userTerritories = [];
            this.error = error;
        }
        
        console.log('### UserTerritoriesDataTable_LWC - wiredGetUserTerritoriesList() - END');
    }*/

    connectedCallback() {
        console.log('### UserTerritoriesDataTable_LWC - connectedCallback() - START : recordId:' + this.recordId);

        // Recover Current User Territories
        this.getUserTerritoriesListFct();
        this.handleSubscribe();
    }

    getUserTerritoriesListFct() {
        console.log('### UserTerritoriesDataTable_LWC - getUserTerritoriesListFct() - START : currentUserId:' + this.currentUserId + ' - recordId:' + this.recordId);

        if(this.recordId){
            // Recover Current User Territories
            getUserTerritoriesList({ AccountId : this.recordId})
            .then(result => {
                console.log('### UserTerritoriesDataTable_LWC - getUserTerritoriesListFct() - result:' + result);
                console.log('### UserTerritoriesDataTable_LWC - getUserTerritoriesListFct() - result.length:' + result.length);   
                
                this.userTerritories = result;  
            })
            .catch(error => {
                this.error = error;

                if (this.errors){
                    if (this.errors[0] && this.errors[0].message){
                        console.log(this.errors[0].message);
                    }
                }
                else{
                    console.log('Unknown error.');
                }
                resolve('KO');
            });
        }
    }    

    handleRowSelection = event => {
        this.selectedRows=event.detail.selectedRows;

        // DEBUG
        for (let i = 0; i < this.selectedRows.length; i++){
            console.log('### UserTerritoriesDataTable_LWC - handleRowSelection() - selectedRows[i]:' + this.selectedRows[i].TerritoryId + ' - ' + this.selectedRows[i].TerritoryName);
        }        
        
        console.log('### UserTerritoriesDataTable_LWC - handleRowSelection() - START : singleRowSelection:' + this.singleRowSelection);

        if(this.singleRowSelection){
            // Ensure Single Row Selection
            if(this.selectedRows.length>1)
            {
                var el = this.template.querySelector('lightning-datatable');
                this.selectedRows=el.selectedRows=el.selectedRows.slice(1);
                event.preventDefault();
                return;
            }
        }
    }  

    handleSave(e) {
        console.log('### UserTerritoriesDataTable_LWC - handleSave() - START');
        
        let territoryIds = [];
        
        // DEBUG
        for (let i = 0; i < this.selectedRows.length; i++){
            console.log('### UserTerritoriesDataTable_LWC - handleSave() - selectedRows[i]:' + this.selectedRows[i].TerritoryId + ' - ' + this.selectedRows[i].TerritoryName);
            
            territoryIds.push(this.selectedRows[i].TerritoryId);
        }

        if(territoryIds){
            // Add User Territories
            
            addUserTerritories({ AccountId : this.recordId, lTerritories : territoryIds})
            .then(result => {
                // Show success message
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'User Territory Assigned to this Account',
                        variant: 'success',
                    }),
                );
            })
            .catch(error => {
                this.error = error;

                if (this.errors){
                    if (this.errors[0] && this.errors[0].message){
                        console.log(this.errors[0].message);
                    }
                }
                else{
                    console.log('Unknown error.');
                }
                resolve('KO');
            });
        }
    }
    
    // Refresh Timeline using "Platform Events"
    // Each time a child record is added, updated or removed a process builder should
    // create an Event to refresh the timeline 
    // Client-side function that invokes the subscribe method on the
    // empApi component.
    // https://developer.salesforce.com/docs/component-library/bundle/lightning-emp-api/documentation
    handleSubscribe() {
        console.log('### UserTerritoriesDataTable_LWC - handleSubscribe - subscribeToRefreshEvent() - START');
        console.log('### UserTerritoriesDataTable_LWC - handleSubscribe - recordId:' + this.recordId);

        const messageCallback = (response) => {
            // response contains the payload of the new message received
            console.log('### UserTerritoriesDataTable_LWC - handleSubscribe - subscribeToRefreshEvent() - New message received: ' + JSON.stringify(response));

            var newRefreshEvent_RecordId = response.data.payload.RecordId__c;
            console.log('### UserTerritoriesDataTable_LWC - handleSubscribe - subscribeToRefreshEvent() - newRefreshEvent_RecordId: ' + newRefreshEvent_RecordId);

            // Refresh the component
            this.getUserTerritoriesListFct();

            // Refresh all the view instead of only the timeline as we also need to refresh rollup field "Child Records Last Modified Date"
            // No way currently to refresh the page except using an Aura wrapper. --> TO BE COMPLETED
        };

        // Invoke subscribe method of empApi. Pass reference to messageCallback
        subscribe(this.channelName, -1, messageCallback).then(response => {
            // Response contains the subscription information on successful subscribe call
            console.log('### UserTerritoriesDataTable_LWC - handleSubscribe - subscribeToRefreshEvent() - Successfully subscribed to : ' + JSON.stringify(response.channel));
            this.subscription = response;
        });

        console.log('### UserTerritoriesDataTable_LWC - handleSubscribe - subscribeToRefreshEvent() - END');
    }
    
    // Client-side function that invokes the unsubscribe method on the
    // empApi component.
    handleUnsubscribe() {
        console.log('### UserTerritoriesDataTable_LWC - handleUnsubscribe() - START');

        // Invoke unsubscribe method of empApi
        unsubscribe(this.subscription, response => {
            console.log('### UserTerritoriesDataTable_LWC - handleUnsubscribe() - response: ' + JSON.stringify(response));
            // Response is true for successful unsubscribe
        });

        console.log('### UserTerritoriesDataTable_LWC - handleUnsubscribe() - END');
    } 

    registerErrorListener() {
        console.log('### UserTerritoriesDataTable_LWC - registerErrorListener() - START');

        // Invoke onError empApi method
        onError(error => {
            console.log('### UserTerritoriesDataTable_LWC - registerErrorListener() - Received error from server: ' + JSON.stringify(error));
            // Error contains the server-side error
        });

        console.log('### UserTerritoriesDataTable_LWC - registerErrorListener() - END');
    }    
}