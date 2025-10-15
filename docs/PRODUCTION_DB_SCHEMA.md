# Production Database Schema

## Overview
This document outlines the optimized Firestore database structure for the BrainBlot app production environment.

## Collections Structure

### 1. Users Collection (`users`)
**Document ID**: Firebase Auth UID
```json
{
  "userId": "string",
  "email": "string", 
  "displayName": "string",
  "profileImageUrl": "string?",
  "createdAt": "timestamp",
  "lastActiveAt": "timestamp",
  "updatedAt": "timestamp",
  "preferences": {
    "theme": "system|light|dark",
    "notifications": "boolean",
    "soundEnabled": "boolean", 
    "language": "string",
    "timezone": "string"
  },
  "subscription": {
    "plan": "free|premium|pro",
    "status": "active|inactive|expired",
    "expiresAt": "timestamp?",
    "features": ["array of strings"]
  },
  "stats": {
    "totalSessions": "number",
    "totalDrillsCompleted": "number", 
    "totalProgramsCompleted": "number",
    "averageAccuracy": "number",
    "averageReactionTime": "number",
    "streakDays": "number",
    "lastSessionAt": "timestamp?"
  }
}
```

### 2. Programs Collection (`programs`)
**Document ID**: Auto-generated UUID
```json
{
  "id": "string",
  "name": "string",
  "category": "agility|soccer|basketball|tennis|general",
  "totalDays": "number",
  "level": "Beginner|Intermediate|Advanced",
  "createdAt": "timestamp",
  "createdBy": "string?", // null for system programs
  "days": [
    {
      "dayNumber": "number",
      "title": "string", 
      "description": "string",
      "drillId": "string?"
    }
  ]
}
```

### 3. Drills Collection (`drills`)
**Document ID**: Auto-generated UUID
```json
{
  "id": "string",
  "name": "string",
  "category": "string",
  "difficulty": "beginner|intermediate|advanced",
  "durationSec": "number",
  "restSec": "number", 
  "reps": "number",
  "stimulusTypes": ["array of strings"],
  "numberOfStimuli": "number",
  "zones": ["array of strings"],
  "colors": ["array of color values"],
  "isPreset": "boolean",
  "createdAt": "timestamp",
  "createdBy": "string?"
}
```

### 4. User Sessions Collection (`user_sessions/{userId}/sessions`)
**Document ID**: Auto-generated UUID
```json
{
  "id": "string",
  "userId": "string",
  "drillId": "string",
  "programId": "string?",
  "startedAt": "timestamp",
  "endedAt": "timestamp", 
  "accuracy": "number",
  "avgReactionMs": "number",
  "totalEvents": "number",
  "correctEvents": "number",
  "events": [
    {
      "stimulusIndex": "number",
      "stimulusTimeMs": "number",
      "stimulusLabel": "string",
      "reactionTimeMs": "number?",
      "correct": "boolean"
    }
  ]
}
```

### 5. Active Programs Collection (`active_programs`)
**Document ID**: User ID
```json
{
  "programId": "string",
  "userId": "string",
  "currentDay": "number",
  "startedAt": "timestamp",
  "lastAccessedAt": "timestamp"
}
```

### 6. Completed Programs Collection (`completed_programs/{userId}/programs`)
**Document ID**: Program ID
```json
{
  "programId": "string",
  "userId": "string", 
  "completedAt": "timestamp",
  "totalDays": "number",
  "averageAccuracy": "number",
  "averageReactionTime": "number"
}
```

## Security Rules

### Firestore Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Programs are readable by all, writable by authenticated users
    match /programs/{programId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
        (resource.data.createdBy == request.auth.uid || resource.data.createdBy == null);
    }
    
    // Drills are readable by all, writable by authenticated users  
    match /drills/{drillId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
        (resource.data.createdBy == request.auth.uid || resource.data.createdBy == null);
    }
    
    // User sessions - private to each user
    match /user_sessions/{userId}/sessions/{sessionId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Active programs - private to each user
    match /active_programs/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Completed programs - private to each user
    match /completed_programs/{userId}/programs/{programId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Indexes Required

### Composite Indexes
1. **Programs Collection**:
   - `category` (Ascending) + `createdAt` (Descending)
   - `level` (Ascending) + `createdAt` (Descending)
   - `createdBy` (Ascending) + `createdAt` (Descending)

2. **User Sessions Collection**:
   - `userId` (Ascending) + `startedAt` (Descending)
   - `drillId` (Ascending) + `startedAt` (Descending)
   - `programId` (Ascending) + `startedAt` (Descending)

3. **Completed Programs Collection**:
   - `userId` (Ascending) + `completedAt` (Descending)

## Performance Optimizations

### 1. Data Denormalization
- User statistics are stored directly in the user document for fast access
- Session summaries are cached in user stats to avoid expensive aggregations

### 2. Batch Operations
- All multi-document writes use Firestore batch operations
- Program creation includes both global and user-specific collections in a single batch

### 3. Offline Support
- Critical data is cached locally using Hive
- Firestore offline persistence is enabled
- Sync operations handle conflicts gracefully

### 4. Query Optimization
- Limit queries to necessary fields only
- Use pagination for large result sets
- Implement proper indexing for all query patterns

## Migration Strategy

### Phase 1: Schema Validation
- Validate all existing data against new schema
- Fix any data inconsistencies
- Remove test/dummy data

### Phase 2: Index Creation
- Create all required composite indexes
- Monitor query performance

### Phase 3: Security Rules Deployment
- Deploy production security rules
- Test with different user roles
- Monitor for access violations

### Phase 4: Cleanup
- Remove unused collections
- Archive old data if necessary
- Optimize storage costs

## Monitoring & Maintenance

### Key Metrics to Monitor
- Query performance and latency
- Storage usage and costs
- Security rule violations
- User session patterns
- Data consistency issues

### Regular Maintenance Tasks
- Review and optimize queries monthly
- Update indexes based on usage patterns
- Clean up orphaned data
- Monitor security rule effectiveness
- Backup critical user data
