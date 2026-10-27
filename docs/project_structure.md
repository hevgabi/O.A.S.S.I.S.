# OASSIS Flutter Project Structure

This is a starting structure for the confirmed OASSIS scope. The Dart files
listed below are placeholders unless implementation is added by the team.

- `lib/main.dart`: app entry point; currently runs the Flutter starter screen.
- `lib/app_routes.dart`: navigation between screens.
- `lib/theme/`: shared colors and app styles.
- `lib/screens/`: entry, visitor chat, student chat, and admin screens.
- `lib/models/`: data used by the app for chat, accounts, and admin review.
- `lib/services/`: client-side access to authentication, chat, and admin data.
- `lib/widgets/`: shared chat and feedback UI components.
- `test/`: Flutter tests.
- `pubspec.yaml`: project settings, dependencies, and declared assets.

The backend, database, authentication method, AI provider, and target platforms
remain to be decided. These placeholders do not implement those choices or the
server-side processing. Add or revise files as the team develops the app.



# OASISS Project Documentation

## 1. Project Overview

OASISS (Online AI Student Information Support System) is a prototype designed to help students, parents, and guardians access school-related information through a chatbot interface. The system includes visitor and student chat interfaces, an entry screen, and administrative features for managing school information and inquiries.

## 2. Development Progress

### 2.1 Project Setup and Integration

The Flutter project has been initialized and shared among the team members. Responsibilities have been assigned, and the initial navigation structure has been planned. Integration of the individual screens into a unified application remains in progress.

### 2.2 Entry and Visitor Chat

The entry screen has been developed with a welcome message, login fields, and visitor access. The visitor chat interface includes a chat header, message input, send button, and sample conversations related to campus inquiries.

### 2.3 Student Chat

The student chat interface has been developed with sample student messages and chatbot responses. Feedback controls, including thumbs-up and thumbs-down buttons, have also been added. Connecting the student chat screen to the shared application navigation remains pending.

### 2.4 Administrative Screens

The administrative interface includes a knowledge base screen with sample entries and controls for managing information. It also includes screens for viewing unanswered inquiries and interaction logs, along with navigation between the administrative sections.

### 2.5 System Documentation

System documentation is currently being prepared. The remaining work includes defining the project scope, documenting functional and non-functional requirements, reviewing system diagrams, preparing the work plan, and compiling the development progress report.

## 3. Current System Status

The initial interfaces for the entry screen, visitor chat, student chat, and administrative functions have been developed. The next stage focuses on integrating these components, verifying navigation, and testing the functionality of the combined application.

Some displayed conversations and administrative records use sample data. Their behavior and the completeness of the implemented features must be verified through testing.

## 4. Next Development Steps

1. Complete the system requirements and project documentation.
2. Integrate the individual screens into the main Flutter application.
3. Verify navigation between the entry, chat, and administrative screens.
4. Conduct functional testing of the implemented features.
5. Document test results and resolve confirmed defects.
6. Update the documentation to reflect the final implemented system.

## 5. Documentation Record

**Prepared by:** Naval  
**Last Updated:** October 28, 2026  
**Project:** OASISS
