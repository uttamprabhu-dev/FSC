/**
 * UploadClaimImageAction - Agentforce Action
 * Receives base64 image data from the form editor, creates a ContentVersion,
 * and links it to the Claim record via ContentDocumentLink.
 */
@JsonAccess(serializable='always' deserializable='always')
public without sharing class UploadClaimImageAction {

    // ===== INPUT WRAPPER =====
    public class ImageUploadRequest {
        @InvocableVariable(label='Claim ID' description='The Claim record to attach the image to' required=true)
        public String claimId;

        @InvocableVariable(label='Image Details' description='Structured image upload input from the form')
        public ImageUploadInput imageDetails;
    }

    // ===== INPUT TYPE (Lightning Type form fields) =====
    public class ImageUploadInput {
        @InvocableVariable(label='File Name' description='Name of the uploaded file')
        public String fileName;

        @InvocableVariable(label='File Data' description='Base64 encoded file content')
        public String fileData;
        
        @InvocableVariable(label='Document IDs' description='Comma-separated ContentDocumentIds from lightning file upload')
        public String documentIds;

        @InvocableVariable(label='Content Type' description='MIME type of the file e.g. image/png')
        public String contentType;

        @InvocableVariable(label='Description' description='Optional description for the image')
        public String description;
    }

    // ===== OUTPUT WRAPPER =====
    public class ImageUploadResponse {
        @InvocableVariable public ImageUploadOutput imageUploadResult;
    }

    // ===== OUTPUT TYPE =====
    public class ImageUploadOutput {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String contentDocumentId;
        @InvocableVariable public String contentVersionId;
        @InvocableVariable public String fileName;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Upload Claim Image' description='Uploads an image and links it to a Claim record.' category='Warranty Claims')
    public static List<ImageUploadResponse> uploadImage(List<ImageUploadRequest> requests) {
        List<ImageUploadResponse> responses = new List<ImageUploadResponse>();
        for (ImageUploadRequest req : requests) {
            req.claimId = '0Mwak00000DQGMbCAP'; // --- HARDCODED FOR TESTING, REPLACE WITH req.claimId IN PRODUCTION ---
            ImageUploadResponse res = new ImageUploadResponse();
            res.imageUploadResult = processSingleUpload(req);
            responses.add(res);
        }
        return responses;
    }

    private static ImageUploadOutput processSingleUpload(ImageUploadRequest req) {
        ImageUploadOutput output = new ImageUploadOutput();

        try {
            // Validate inputs
            if (String.isBlank(req.claimId)) {
                output.success = false;
                output.message = 'Claim ID is required to upload an image.';
                return output;
            }

            ImageUploadInput input = req.imageDetails;
            if (input == null || (String.isBlank(input.fileData) && String.isBlank(input.documentIds))) {
                output.success = false;
                output.message = 'No file data or document IDs provided. Please select an image to upload.';
                return output;
            }

            // Parse Claim ID
            Id parsedClaimId;
            try {
                parsedClaimId = Id.valueOf(req.claimId.trim());
            } catch (Exception e) {
                output.success = false;
                output.message = 'Invalid Claim ID format: ' + req.claimId;
                return output;
            }

            // Determine if using documentIds or base64 fileData
            if (String.isNotBlank(input.documentIds)) {
                // lightning-file-upload approach: link existing files
                List<String> docIds = input.documentIds.split(',');
                List<ContentDocumentLink> cdlsToInsert = new List<ContentDocumentLink>();
                
                Set<Id> docIdSet = new Set<Id>();
                for(String dId : docIds) {
                    if(String.isNotBlank(dId)) {
                        docIdSet.add((Id)dId.trim());
                    }
                }
                
                // Query existing links to prevent duplicates
                Set<Id> existingDocIds = new Set<Id>();
                for (ContentDocumentLink existing : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :parsedClaimId AND ContentDocumentId IN :docIdSet]) {
                    existingDocIds.add(existing.ContentDocumentId);
                }

                for (Id docId : docIdSet) {
                    if (!existingDocIds.contains(docId)) {
                        ContentDocumentLink cdl = new ContentDocumentLink();
                        cdl.ContentDocumentId = docId;
                        cdl.LinkedEntityId = parsedClaimId;
                        cdl.ShareType = 'V'; 
                        cdl.Visibility = 'AllUsers';
                        cdlsToInsert.add(cdl);
                    }
                }
                
                if (!cdlsToInsert.isEmpty()) {
                    insert cdlsToInsert;
                }
                
                output.success = true;
                output.message = '✅ Successfully linked ' + docIdSet.size() + ' uploaded file(s) to the Claim!';
                
            } else {
                // Base 64 string approach
                // Determine file name
                String fileName = String.isNotBlank(input.fileName) ? input.fileName : 'ClaimImage_' + Datetime.now().format('yyyyMMdd_HHmmss') + '.png';

                // Create ContentVersion
                ContentVersion cv = new ContentVersion();
                cv.Title = fileName.substringBeforeLast('.');
                cv.PathOnClient = fileName;
                cv.VersionData = EncodingUtil.base64Decode(input.fileData);
                cv.Description = String.isNotBlank(input.description) ? input.description : 'Claim image uploaded via Agentforce';
                cv.Origin = 'C'; // Content origin

                insert cv;

                // Query back to get ContentDocumentId
                ContentVersion inserted = [SELECT Id, ContentDocumentId, Title, PathOnClient 
                                           FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

                // Create ContentDocumentLink to associate with Claim
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = inserted.ContentDocumentId;
                cdl.LinkedEntityId = parsedClaimId;
                cdl.ShareType = 'V'; // Viewer permission
                cdl.Visibility = 'AllUsers';

                insert cdl;

                // Build success output
                output.success = true;
                output.contentDocumentId = inserted.ContentDocumentId;
                output.contentVersionId = inserted.Id;
                output.fileName = fileName;
                output.message = '✅ Image "' + fileName + '" uploaded successfully and linked to the Claim!\n' +
                                 '• File: ' + fileName + '\n' +
                                 '• Document ID: ' + inserted.ContentDocumentId;
            }

        } catch (Exception e) {
            output.success = false;
            output.message = 'Error uploading image: ' + e.getMessage();
        }

        return output;
    }
}