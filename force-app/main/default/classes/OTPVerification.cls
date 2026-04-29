global class OTPVerification {
    global class OTPVerificationRequest {
        @InvocableVariable(label='Messaging Session ID'
            description='The ID of the current active messaging session. Always pass this.'
            required=true
        )
        public Id idMessagingSessionId;

        @InvocableVariable(label='OTP Entered by User'
            description='The OTP entered by the user for verification.'
            required=true
        )
        public String otpEntered;
    }

    global class OTPVerificationResponse {

        @InvocableVariable(label='+OTP Verification Result'
            description='The result of OTP verification: "OTP verified successfully", "OTP verification failed", or "Session not found".'
            required=true
        )
        public String verificationResult;

        public OTPVerificationResponse(String verificationResult) {
            this.verificationResult = verificationResult;
        }
    }

    @InvocableMethod(label='Verify OTP' description='Verifies the OTP entered by the user')
    global static List<OTPVerificationResponse> verifyOTP(List<OTPVerificationRequest> inputs) {

        // Collect all session IDs and map entered OTPs
        Map<Id, String> map_idToEnteredOTP = new Map<Id, String>();
        for (OTPVerificationRequest input : inputs) {
            map_idToEnteredOTP.put(input.idMessagingSessionId, input.otpEntered);
        }

        // Query and map results by Id
        Map<Id, MessagingSession> map_idToSession = new Map<Id, MessagingSession>(
            [SELECT Id, OTP__c FROM MessagingSession WHERE Id IN :map_idToEnteredOTP.keySet()]
        );

        List<OTPVerificationResponse> list_responses = new List<OTPVerificationResponse>();

        // Iterate inputs (preserves order) and look up results by Id
        for (OTPVerificationRequest input : inputs) {
            MessagingSession objSession = map_idToSession.get(input.idMessagingSessionId);
            String result = '';
            if (objSession == null) {
                result ='Session not found';
            } else if (input.otpEntered == objSession.OTP__c) {
                result = 'OTP verified successfully';
            } else {
                result = 'OTP verification failed';
            }

            list_responses.add(new OTPVerificationResponse(result));
        }

        return list_responses;
    }
}