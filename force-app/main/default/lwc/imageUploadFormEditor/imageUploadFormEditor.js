import { LightningElement, api } from 'lwc';
import USER_ID from '@salesforce/user/Id';


export default class ImageUploadFormEditor extends LightningElement {
    _value = {};

    @api
    get value() {
        return this._value;
    }
    set value(val) {
        this._value = val ? { ...val } : {};
    }

    @api myRecordId = USER_ID;

    formData = {
        fileName: '',
        documentIds: '',
        contentType: '',
        description: ''
    };

    selectedFileName = '';
    isFileSelected = false;

    get acceptedFormats() {
        return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.pdf'];
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles && uploadedFiles.length > 0) {
            this.selectedFileName = uploadedFiles.map(file => file.name).join(', ');
            this.isFileSelected = true;
            this.formData.fileName = uploadedFiles[0].name;
            this.formData.documentIds = uploadedFiles.map(file => file.documentId).join(',');

            this.dispatchValueChange();
        }
    }

    handleDescriptionChange(event) {
        this.formData.description = event.target.value;
        this.dispatchValueChange();
    }

    dispatchValueChange() {
        this.dispatchEvent(new CustomEvent('valuechange', {
            detail: { value: { ...this.formData } },
            bubbles: true,
            composed: true
        }));
    }

    dispatchAllCreated() {
        
    }
}
