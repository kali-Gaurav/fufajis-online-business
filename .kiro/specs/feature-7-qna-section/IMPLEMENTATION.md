# Feature 7: Product Question & Answer (Q&A) Section

## Overview
Implementation of a comprehensive Q&A system allowing customers to ask product questions and shop owners to answer them directly on the product detail page.

## Current State Analysis

### Existing Components
- ✅ `lib/models/qna_model.dart` - Basic data model
- ✅ `lib/widgets/qna_section.dart` - Basic UI implementation

### Gaps Identified
1. **Integration Gap**: QnaSection not integrated into ProductDetailScreen
2. **Feature Gaps**:
   - No shop owner answer functionality
   - No notification system for new questions
   - No helpful votes/reactions
   - No search/filter capabilities
   - No admin moderation
   - No email notifications
   - No real-time updates
   - No question status tracking
   - No user reputation system

## Implementation Plan

### Phase 1: Data Model Enhancement
1. Add helpful votes count
2. Add question status (pending, answered, resolved)
3. Add shop owner response timestamp
4. Add user badges/reputation
5. Add moderation flags

### Phase 2: Service Layer
1. Create `QnaService` with CRUD operations
2. Implement real-time subscriptions
3. Add notification triggers
4. Implement email notifications

### Phase 3: UI Enhancement
1. Improve QnaSection widget design
2. Add shop owner answer interface
3. Add helpful vote buttons
4. Add search/filter functionality
5. Add question status indicators

### Phase 4: Integration
1. Integrate QnaSection into ProductDetailScreen
2. Add notification system
3. Add admin moderation interface

## Technical Implementation

### Enhanced Data Model
```dart
class QnaModel {
  // Existing fields...
  final int helpfulVotes;
  final int unhelpfulVotes;
  final String status; // pending, answered, resolved
  final String? shopOwnerId;
  final String? shopOwnerName;
  final int helpfulVoteCount;
  final List<String> voters; // user IDs who voted
  final bool isFlagged;
  final String? flagReason;
  final int reportCount;
}
```

### Service Layer
```dart
class QnaService {
  Future<void> askQuestion(QnaModel qna);
  Future<void> answerQuestion(String questionId, String answer, String shopOwnerId);
  Future<void> voteHelpful(String questionId, String userId);
  Stream<List<QnaModel>> getQuestions(String productId);
  Future<void> flagQuestion(String questionId, String reason);
}
```

### UI Components
1. **QuestionCard**: Display individual question with answer
2. **AnswerForm**: Shop owner answer input
3. **VoteButton**: Helpful/unhelpful voting
4. **QnaList**: Filterable list of Q&A
5. **NotificationBadge**: New question indicator

## Firestore Structure
```
products/{productId}
  └── qna/{questionId}
        ├── question: string
        ├── answer: string
        ├── customerId: string
        ├── customerName: string
        ├── shopOwnerId: string
        ├── shopOwnerName: string
        ├── helpfulVotes: number
        ├── unhelpfulVotes: number
        ├── voters: array
        ├── status: string
        ├── createdAt: timestamp
        ├── answeredAt: timestamp
        ├── isFlagged: boolean
        └── flagReason: string
```

## Implementation Tasks

### Task 1: Enhance QnaModel
- [ ] Add new fields to data model
- [ ] Update fromMap/toMap methods
- [ ] Add validation logic

### Task 2: Create QnaService
- [ ] Implement CRUD operations
- [ ] Add real-time subscriptions
- [ ] Implement voting logic
- [ ] Add notification triggers

### Task 3: Enhance QnaSection UI
- [ ] Improve visual design
- [ ] Add shop owner answer interface
- [ ] Add voting functionality
- [ ] Add search/filter

### Task 4: Integrate into ProductDetailScreen
- [ ] Add QnaSection to product detail
- [ ] Add notification badge
- [ ] Add scroll-to-Q&A button

### Task 5: Add Notification System
- [ ] FCM notifications for new questions
- [ ] Email notifications for shop owners
- [ ] In-app notification center

### Task 6: Add Admin Moderation
- [ ] Flag inappropriate questions
- [ ] Hide/delete questions
- [ ] Audit log

## Success Criteria
1. Customers can ask questions on any product
2. Shop owners receive notifications and can answer
3. Other customers can vote if answers are helpful
4. Questions are sorted by helpfulness
5. Moderation system prevents abuse
6. Real-time updates work smoothly

## Testing Plan
1. Unit tests for QnaService
2. Widget tests for QnaSection
3. Integration tests for full Q&A flow
4. Performance tests for real-time updates
5. Security tests for access control

## Rollout Strategy
1. Deploy to staging environment
2. Enable for 10% of users
3. Monitor metrics (questions asked, answers given, engagement)
4. Gradually increase rollout
5. Full deployment after validation