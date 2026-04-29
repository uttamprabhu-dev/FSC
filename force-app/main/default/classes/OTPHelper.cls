global class OTPHelper {

    public static final String ORG_WIDE_EMAIL = 'uttam.prabhu@absyz.com';

    global class OTPRequest {
        public String phoneNumber;
        public String email;

        public OTPRequest(String phoneNumber, String email) {
            this.phoneNumber = phoneNumber;
            this.email = email;
        }
        public OTPRequest(String email) {
            this.email = email;
        }
    }

    global class OTPResponse {
        @InvocableVariable(label='OTP')
        public Integer otp;

        public OTPResponse(Integer otp) {
            this.otp = otp;
        }
    }

    global class OTPGeneratorRequest {
        @InvocableVariable(
            label='Messaging Session ID'
            description='The ID of the current active messaging session. Always pass this.'
            required=true
        )
        public Id idMessagingSessionId;

        @InvocableVariable(
            label='Phone Number'
            description='The mobile phone number provided by the user to send the OTP to.'
            required=true
        )
        public String phoneNumber; // ✅ FIXED: was Id, now String
    }

    global class OTPGeneratorResponse {

        @InvocableVariable(label='+OTP Verification Result'
            description='The result of OTP verification: "OTP verified successfully", "OTP verification failed", or "Session not found".'
            required=true
        )
        public String otpGenerationResult;

        public OTPGeneratorResponse(String otpGenerationResult) {
            this.otpGenerationResult = otpGenerationResult;
        }
    }

    @InvocableMethod(
        label='Send OTP'
        description='Sends a one-time password (OTP) to the user\'s registered email based on their phone number. Invoke this to initiate OTP verification when userIsOTPVerified is false or when the user requests an OTP.'
    )
    global static List<OTPGeneratorResponse> sendOTP(List<OTPGeneratorRequest> inputs) {
        try {
            Map<String, String> map_sessionToNumber = new Map<String, String>(); // ✅ FIXED
            Map<String, String> map_numberToOTP = new Map<String, String>();
            Map<String, String> map_emailToNumber = new Map<String, String>();

            for (OTPGeneratorRequest item : inputs) {
                map_sessionToNumber.put(item.idMessagingSessionId, item.phoneNumber);
            }
            System.debug('Session to Number Map: ' + map_sessionToNumber);

            List<Contact> list_contacts = [
                SELECT Id, Email, AccountId, Phone
                FROM Contact
                WHERE Phone IN :map_sessionToNumber.values()
            ];

            if (list_contacts.isEmpty()) {
                OTPGeneratorResponse otpGenerationResult = new OTPGeneratorResponse('OTP was not sent successfully'); 
                return new List<OTPGeneratorResponse>{ otpGenerationResult };
            }

            List<OTPRequest> list_otpRequestContactInfo = new List<OTPRequest>();
            for (Contact objContact : list_contacts) {
                list_otpRequestContactInfo.add(new OTPRequest(objContact.Email));
                map_emailToNumber.put(objContact.Email, objContact.Phone);
            }
            System.debug('Email to Number Map: ' + map_emailToNumber);

            List<OTPResponse> list_otpResponse = generateOTP(list_otpRequestContactInfo);
            List<EmailRequest> list_emailRequest = new List<EmailRequest>();

            for (Integer i = 0; i < list_otpResponse.size(); i++) {
                list_emailRequest.add(new EmailRequest(
                    list_otpRequestContactInfo[i].email,
                    String.valueOf(list_otpResponse[i].otp)
                ));
                String strPhoneNumber = map_emailToNumber.get(list_otpRequestContactInfo[i].email);
                map_numberToOTP.put(strPhoneNumber, String.valueOf(list_otpResponse[i].otp));
            }
            System.debug('Number to OTP Map: ' + map_numberToOTP);


            List<MessagingSession> list_messagingSessions = new List<MessagingSession>();
            for (String sessionId : map_sessionToNumber.keySet()) {
                MessagingSession objMessagingSession = new MessagingSession();
                objMessagingSession.Id = sessionId;
                objMessagingSession.OTP__c = map_numberToOTP.get(map_sessionToNumber.get(sessionId));
                list_messagingSessions.add(objMessagingSession);
            }

            update list_messagingSessions;
            sendOTPEmails(list_emailRequest);

            OTPGeneratorResponse otpGenerationResult = new OTPGeneratorResponse('OTP sent successfully'); 
            return new List<OTPGeneratorResponse>{ otpGenerationResult };

        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
        }
        OTPGeneratorResponse otpGenerationResult = new OTPGeneratorResponse('OTP was not sent successfully'); 
        return new List<OTPGeneratorResponse>{ otpGenerationResult };
    }

    global static List<OTPResponse> generateOTP(List<OTPRequest> requests) {
        List<OTPResponse> responses = new List<OTPResponse>();
        for (OTPRequest strPhoneNumber : requests) {
            Integer otp = (Integer)(Math.random() * 900000) + 100000;
            responses.add(new OTPResponse(otp));
        }
        
        return responses;
    }

    global class EmailRequest {
        public String email;
        public String otp;
        
        public EmailRequest(String email, String otp) {
            this.email = email;
            this.otp = otp;
        }
    }
    
    global static void sendOTPEmails(List<EmailRequest> requests) {
        // Fetch a verified org-wide email address
        List<OrgWideEmailAddress> owea = [
            SELECT Id FROM OrgWideEmailAddress 
            WHERE Address = :ORG_WIDE_EMAIL
            LIMIT 1
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (EmailRequest req : requests) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ req.email });
            mail.setSubject('Your OTP Code');
            mail.setPlainTextBody(
                'Your OTP is: ' + req.otp + 
                '\n\nThis code expires in 10 minutes. Do not share it with anyone.'
            );
            mail.setHtmlBody(
                '<html><body>' +
                '<h2>Your One-Time Password</h2>' +
                '<p>Use the OTP below to complete your verification:</p>' +
                '<h1 style="letter-spacing: 4px; color: #2c3e50;">' + req.otp + '</h1>' +
                '<p style="color: #888;">This code expires in <strong>10 minutes</strong>.' +
                ' Do not share it with anyone.</p>' +
                '</body></html>'
            );
            mail.setSaveAsActivity(false);

            // Set verified sender to avoid deliverability issues
            if (!owea.isEmpty()) {
                mail.setOrgWideEmailAddressId(owea[0].Id);
            }

            emails.add(mail);
        }

        if (!emails.isEmpty()) {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(emails);

            // Log any failures
            for (Messaging.SendEmailResult r : results) {
                if (!r.isSuccess()) {
                    for (Messaging.SendEmailError err : r.getErrors()) {
                        System.debug('Email send error: ' + err.getMessage());
                    }
                }
            }
        }
    }
}