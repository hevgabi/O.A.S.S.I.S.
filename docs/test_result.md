
# OASISS - QA Test Results

## 1. Testing Overview

**Project:** Online AI Student Information Support System (OASISS)  
**Tester:** Naval  
**Testing Phase:** Prototype Development  
**Date:** 2026-10-28

This document records the testing activities, observed behavior, and issues identified during the development of OASISS. Testing focuses on verifying the functionality of the entry screen, visitor chat, student chat, and administrative screens.

## 2. Test Results

| Test ID | Module | Test Scenario | Expected Result | Actual Result | Status |
|---|---|---|---|---|---|
| TC-001 | Entry Screen | Open the application | Entry screen displays correctly | Entry screen appeared correctly | Passed |
| TC-002 | Visitor Chat | Select Continue as Visitor | Visitor Chat opens | Visitor chat box appeared correctly | Passed |
| TC-003 | Visitor Chat | Send a message | Message appears in the conversation | The visitor chat displays a response, but its functionality is still incomplete. | In Progress |
| TC-004 | Student Chat | Open Student Chat | Chat interface and sample conversation display | The student chat interface displayed correctly, but responses were limited to admissions, schedules, and deadlines. Different messages received the same response. | Pass |
| TC-005 | Student Chat | Select a feedback button | Feedback selection behaves as intended | The thumbs-up and thumbs-down feedback buttons were clickable when selected. | Pass |
| TC-006 | Knowledge Base | Open the knowledge base screen | Knowledge base entries display | The knowledge base screen opened successfully, and the available entries were displayed correctly. No visible bugs were encountered during testing. | Pass |
| TC-007 | Knowledge Base | Add or edit an entry | Entry is updated as intended | The knowledge base allows users to add, edit, and remove sample data successfully. | Pass |
| TC-008 | Unanswered Inquiries | Open the inquiry screen | Inquiry records and details display | The unanswered inquiries screen displayed the necessary information for each inquiry correctly.  | Pass |
| TC-009 | Interaction Logs | Open the interaction logs | Interaction records display | The interaction logs displayed correctly, and clicking View Details opened a dialog showing the question, student information, contact details, and submission date. | Pass |
| TC-010 | Navigation | Navigate between integrated screens | The intended screens open correctly | Navigation between the different system screens worked correctly. All tested sections were accessible, and no navigation issues were encountered during testing. | Pass |

## 3. Observations

The OASISS prototype contains an entry screen, visitor chat, student chat, and administrative screens for managing the knowledge base, unanswered inquiries, and interaction logs. Testing showed that the available screens opened correctly and that navigation between the tested sections worked as intended.

The visitor chat displays responses, but its functionality remains incomplete. The student chat displays sample conversations; however, its responses are limited to admissions, schedules, and deadlines, with different messages sometimes receiving the same response. The feedback buttons were clickable, and the knowledge base successfully supported adding, editing, and removing sample data.

The unanswered inquiries screen displayed the necessary inquiry information correctly. The interaction logs also displayed properly, and selecting View Details opened a dialog containing the question, student information, contact details, and submission date. Further testing is needed to verify the completeness of the chat functionality and interaction log features.

## 4. Issues and Limitations

| Issue ID | Observation | Classification | Status |
|---|---|---|---|
| OBS-001 | Different questions in the student chat may receive the same response, and responses are limited to admissions, schedules, and deadlines. | Functional Limitation | In Progress |
| OBS-002 | The visitor chat displays responses, but its functionality is still incomplete. | Incomplete Functionality | In Progress |
| OBS-003 | The interaction logs display records and details correctly, but further testing is needed to verify complete functionality. | Pending Verification | In Progress |


## 5. Next Testing Activities

1. Continue testing the visitor chat to verify its message processing and response functionality.
2. Improve and test student chat responses to ensure that different questions receive appropriate answers.
3. Verify the functionality of the thumbs-up and thumbs-down feedback buttons.
4. Conduct additional testing of the knowledge base, including adding, editing, and removing entries.
5. Verify the information displayed in unanswered inquiries and interaction logs.
6. Test the View Details dialog and confirm that the displayed information is accurate.
7. Retest all screens and navigation features after any updates or corrections.
8. Update the test results and document any newly identified issues.

## 6. Conclusion

The initial testing showed that the entry screen, navigation, knowledge base, unanswered inquiries, and interaction logs worked properly. The student and visitor chat features still need improvement, especially in how they respond to different questions. Further testing will be conducted as development continues. The project is currently estimated to be 30% complete, with some features still being developed and tested.