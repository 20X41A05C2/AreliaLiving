import { LightningElement, track, wire } from 'lwc';
import getProjects from '@salesforce/apex/VendorContactController.getProjects';
//import getVendorCategories from '@salesforce/apex/VendorContactController.getVendorCategories';
import getVendorContacts from '@salesforce/apex/VendorContactController.getVendorContacts';
import sendEmailToVendors from '@salesforce/apex/VendorContactController.sendEmailToVendors';
import getVendorCategoryPicklistValues from '@salesforce/apex/VendorContactController.getVendorCategoryPicklistValues';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

const PAGE_SIZE = 5; // Number of vendors per page

export default class VendorContacts extends LightningElement {
    @track isStepOne = true;

    // Projects
    @track selectedProjectId = '';
    @track selectedProject = null;
    @track projectOptions = [];
    projectsMap = new Map();

    // Vendor categories & vendors
    @track selectedCategory = 'All';
    @track categoryOptions = [];
    allVendors = [];
    paginatedVendors = [];

    // Pagination state
    @track currentPage = 1;
    totalPages = 1;

    @track selectedVendorIds = [];

    columns = [
        { label: 'Name', fieldName: 'Name' },
        { label: 'Email', fieldName: 'Email__c' },
        { label: 'Category', fieldName: 'Vendor_Category__c' }
    ];

    connectedCallback() {
        this.loadProjects();
        //this.loadCategories();
    }
    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }


        async loadProjects() {
        try {
            const data = await getProjects();
            this.projectOptions = data.map(proj => ({
                label: proj.Name,
                value: proj.Id
            }));
            this.projectsMap = new Map(data.map(proj => [proj.Id, proj]));
        } catch (error) {
            console.error('Error loading Projects:', error);
        }
    }


    @wire(getVendorCategoryPicklistValues)
    wiredVendorCategoryPicklistValues({ error, data }) {
        if (data) {
            // Add "All" option and set it as unchecked by default
            this.categoryOptions = [
                { label: 'All', value: 'All' },
                ...data.map(item => ({ label: item, value: item }))
            ];
        } else if (error) {
            console.error('Error fetching Academic Year picklist values:', error);
        }
    }

    // async loadCategories() {
    //     try {
    //         const data = await getVendorCategories();
    //         this.categoryOptions = [{ label: 'All', value: 'All' }, ...data.map(c => ({ label: c, value: c }))];
    //     } catch (error) {
    //         console.error('Error loading categories:', error);
    //     }
    // }

    handleProjectChange(event) {
        this.selectedProjectId = event.detail.value;
        this.selectedProject = this.projectsMap.get(this.selectedProjectId);
    }

    get disableNext() {
        return !this.selectedProjectId;
    }

    goToStepTwo() {
        this.isStepOne = false;
        this.currentPage = 1;
        this.loadVendors(this.selectedCategory);
    }

    goToStepOne() {
        this.isStepOne = true;
        // Reset vendors & selections
        this.allVendors = [];
        this.paginatedVendors = [];
        this.selectedVendorIds = [];
        this.selectedCategory = 'All';
        this.currentPage = 1;
    }

    async loadVendors(category) {
        try {
            const data = await getVendorContacts({ category });
            this.allVendors = data;
            this.totalPages = Math.ceil(this.allVendors.length / PAGE_SIZE);
            this.currentPage = 1;
            this.updatePaginatedVendors();
            this.selectedVendorIds = [];
        } catch (error) {
            console.error('Error loading vendors:', error);
        }
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.detail.value;
        this.loadVendors(this.selectedCategory);
    }

    updatePaginatedVendors() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        const end = start + PAGE_SIZE;
        this.paginatedVendors = this.allVendors.slice(start, end);
    }

    handleRowSelection(event) {
        this.selectedVendorIds = event.detail.selectedRows.map(row => row.Id);
    }

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePaginatedVendors();
            this.selectedVendorIds = [];
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updatePaginatedVendors();
            this.selectedVendorIds = [];
        }
    }

    async handleSendEmail() {
        if (!this.selectedVendorIds.length) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'No Vendors Selected',
                message: 'Please select at least one vendor to send email.',
                variant: 'warning'
            }));
            return;
        }

        try {
            await sendEmailToVendors({
                vendorIds: this.selectedVendorIds,
                projectId: this.selectedProjectId
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Emails sent successfully!',
                variant: 'success'
            }));

            // Reset to first step and clear selections
            this.closeQuickAction();

        } catch (error) {
            console.error('Error sending email:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Failed to send emails.',
                variant: 'error'
            }));
        }
    }

    closeQuickAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}