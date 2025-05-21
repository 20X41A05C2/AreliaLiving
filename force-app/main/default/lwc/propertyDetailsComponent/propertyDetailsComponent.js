import { LightningElement, wire, track } from 'lwc';
import getPropertiesWithImages from '@salesforce/apex/PropertyController.getPropertiesWithImages';
import getContactList from '@salesforce/apex/PropertyController.getContactList';
import createInterestedContact from '@salesforce/apex/PropertyController.createInterestedContact';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PropertDetailscomponent extends LightningElement {
    @track properties = [];
    @track error;
    @track showModal = false;
    @track selectedPropertyId;
    @track selectedPropertyName;
    @track selectedContactId;
    @track contactOptions = [];

    @wire(getPropertiesWithImages)
    wiredProperties({ data, error }) {
        if (data) {
            this.properties = data;
        } else {
            this.error = error;
        }
    }

    @wire(getContactList)
    wiredContacts({ data, error }) {
        if (data) {
            this.contactOptions = data.map(c => ({
                label: c.Name,
                value: c.Id
            }));
        } else {
            console.error(error);
        }
    }

    openModal(event) {
        this.selectedPropertyId = event.target.dataset.id;
        this.selectedPropertyName = event.target.dataset.name;
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
        this.selectedContactId = null;
    }

    handleContactChange(event) {
        this.selectedContactId = event.detail.value;
    }

    async saveContact() {
        if (!this.selectedContactId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'Please select a contact.',
                    variant: 'error'
                })
            );
            return;
        }

        try {
            await createInterestedContact({
                propertyId: this.selectedPropertyId,
                contactId: this.selectedContactId
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Contact added successfully!',
                    variant: 'success'
                })
            );
            this.closeModal();
        } catch (err) {
            console.error(err);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to create Interested Contact',
                    variant: 'error'
                })
            );
        }
    }
}