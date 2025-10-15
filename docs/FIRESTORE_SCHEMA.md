# BrainBlot App - Professional Firestore Database Schema

## Overview
This document outlines the comprehensive, scalable, and professional Firebase Firestore database structure for the BrainBlot cognitive training application.

## Design Principles
- **Scalability**: Designed to handle millions of users and sessions
- **Security**: Proper access control with granular permissions
- **Performance**: Optimized for common query patterns
- **Data Integrity**: Strong validation rules and consistent data types
- **Privacy**: User data isolation and GDPR compliance ready

## Database Structure

### 1. Users Collection (`/users/{userId}`)
**Purpose**: Store user profiles, settings, and metadata
```javascript
{
  "userId": "string", // Firebase Auth UID
  "email": "string",
  "displayName": "string",
  "profileImageUrl": "string?",
  "createdAt": "timestamp",
  "lastActiveAt": "timestamp",
  "preferences": {
    "theme": "light|dark|system",
    "notifications": "boolean",
    "soundEnabled": "boolean",
    "language": "string",
    "timezone": "string"
  },
  "subscription": {
    "plan": "free|premium|pro",
    "status": "active|inactive|cancelled",
    "expiresAt": "timestamp?",
    "features": ["string"]
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

### 2. Drills Collection (`/drills/{drillId}`)
**Purpose**: Global repository of all available drills
```javascript
{
  "id": "string",
  "name": "string",
  "description": "string",
  "category": "soccer|basketball|tennis|hockey|general|agility",
  "difficulty": "beginner|intermediate|advanced",
  "tags": ["string"], // searchable tags
  "durationSec": "number",
  "restSec": "number",
  "reps": "number",
  "stimulusTypes": ["color|shape|arrow|number|audio"],
  "numberOfStimuli": "number",
  "zones": ["center|top|bottom|left|right|quadrants"],
  "colors": ["string"], // hex color codes
  "isPreset": "boolean", // system vs user-created
  "isPublic": "boolean", // visible to other users
  "createdBy": "string?", // userId or null for system drills
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "version": "number", // for drill versioning
  "metadata": {
    "instructions": "string",
    "tips": ["string"],
    "equipment": ["string"],
    "targetSkills": ["string"]
  },
  "analytics": {
    "totalPlays": "number",
    "averageRating": "number",
    "totalRatings": "number"
  }
}
```

### 3. Programs Collection (`/programs/{programId}`)
**Purpose**: Global repository of training programs
```javascript
{
  "id": "string",
  "name": "string",
  "description": "string",
  "category": "soccer|basketball|tennis|hockey|general|agility",
  "level": "beginner|intermediate|advanced",
  "totalDays": "number",
  "estimatedDuration": "number", // total minutes
  "tags": ["string"],
  "isPreset": "boolean",
  "isPublic": "boolean",
  "createdBy": "string?",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "version": "number",
  "days": [
    {
      "dayNumber": "number",
      "title": "string",
      "description": "string",
      "drillId": "string?",
      "customInstructions": "string?",
      "restDay": "boolean"
    }
  ],
  "metadata": {
    "objectives": ["string"],
    "prerequisites": ["string"],
    "targetAudience": "string"
  },
  "analytics": {
    "totalEnrollments": "number",
    "completionRate": "number",
    "averageRating": "number",
    "totalRatings": "number"
  }
}
```

### 4. User Active Programs (`/user_active_programs/{userId}`)
**Purpose**: Track user's currently active program
```javascript
{
  "programId": "string",
  "currentDay": "number",
  "startedAt": "timestamp",
  "lastActiveAt": "timestamp",
  "progress": {
    "completedDays": ["number"],
    "skippedDays": ["number"],
    "totalSessionsCompleted": "number"
  },
  "settings": {
    "dailyReminder": "boolean",
    "reminderTime": "string", // HH:MM format
    "autoAdvance": "boolean"
  }
}
```

### 5. User Sessions (`/user_sessions/{userId}/sessions/{sessionId}`)
**Purpose**: Store detailed session results and performance data
```javascript
{
  "id": "string",
  "drillId": "string",
  "programId": "string?", // if part of a program
  "programDay": "number?",
  "startedAt": "timestamp",
  "endedAt": "timestamp",
  "durationMs": "number",
  "events": [
    {
      "stimulusIndex": "number",
      "stimulusTimeMs": "number",
      "stimulusLabel": "string",
      "reactionTimeMs": "number?",
      "correct": "boolean",
      "position": {
        "x": "number",
        "y": "number"
      }
    }
  ],
  "results": {
    "totalStimuli": "number",
    "hits": "number",
    "misses": "number",
    "accuracy": "number", // 0-1
    "averageReactionTime": "number",
    "fastestReactionTime": "number",
    "slowestReactionTime": "number"
  },
  "metadata": {
    "deviceInfo": {
      "platform": "ios|android|web",
      "screenSize": "string",
      "deviceModel": "string?"
    },
    "environment": {
      "lighting": "bright|normal|dim",
      "noise": "quiet|normal|loud",
      "distractions": "none|minimal|moderate|high"
    }
  }
}
```

### 6. User Completed Programs (`/user_completed_programs/{userId}/programs/{programId}`)
**Purpose**: Track completed programs and achievements
```javascript
{
  "programId": "string",
  "completedAt": "timestamp",
  "startedAt": "timestamp",
  "totalDays": "number",
  "daysCompleted": "number",
  "daysSkipped": "number",
  "totalSessions": "number",
  "averageAccuracy": "number",
  "averageReactionTime": "number",
  "improvements": {
    "accuracyImprovement": "number", // percentage
    "reactionTimeImprovement": "number", // milliseconds
    "consistencyScore": "number"
  },
  "achievements": ["string"], // achievement IDs earned
  "rating": "number?", // 1-5 stars
  "feedback": "string?"
}
```

### 7. User Favorites (`/user_favorites/{userId}`)
**Purpose**: Store user's favorite drills and programs
```javascript
{
  "drills": ["string"], // array of drill IDs
  "programs": ["string"], // array of program IDs
  "updatedAt": "timestamp"
}
```

### 8. Leaderboards (`/leaderboards/{leaderboardId}`)
**Purpose**: Global and category-specific leaderboards
```javascript
{
  "id": "string",
  "type": "global|category|drill|program",
  "category": "string?",
  "drillId": "string?",
  "programId": "string?",
  "timeframe": "daily|weekly|monthly|allTime",
  "metric": "accuracy|reactionTime|consistency|sessions",
  "updatedAt": "timestamp",
  "entries": [
    {
      "userId": "string",
      "displayName": "string",
      "score": "number",
      "rank": "number",
      "sessionsCount": "number",
      "achievedAt": "timestamp"
    }
  ]
}
```

### 9. Analytics (`/analytics/{analyticsId}`)
**Purpose**: Aggregated analytics and insights
```javascript
{
  "id": "string",
  "type": "daily|weekly|monthly",
  "date": "timestamp",
  "metrics": {
    "totalUsers": "number",
    "activeUsers": "number",
    "newUsers": "number",
    "totalSessions": "number",
    "averageSessionDuration": "number",
    "popularDrills": [
      {
        "drillId": "string",
        "playCount": "number"
      }
    ],
    "popularPrograms": [
      {
        "programId": "string",
        "enrollmentCount": "number"
      }
    ]
  }
}
```

### 10. System Configuration (`/system/{configId}`)
**Purpose**: App configuration and feature flags
```javascript
{
  "id": "string",
  "version": "string",
  "features": {
    "leaderboards": "boolean",
    "socialSharing": "boolean",
    "premiumFeatures": "boolean",
    "analytics": "boolean"
  },
  "maintenance": {
    "scheduled": "boolean",
    "message": "string?",
    "startTime": "timestamp?",
    "endTime": "timestamp?"
  },
  "limits": {
    "maxDrillsPerUser": "number",
    "maxProgramsPerUser": "number",
    "maxSessionsPerDay": "number"
  }
}
```

## Indexing Strategy

### Composite Indexes
```javascript
// User sessions by date range
["userId", "startedAt"]

// Drills by category and difficulty
["category", "difficulty", "createdAt"]

// Programs by category and level
["category", "level", "createdAt"]

// Leaderboards by type and timeframe
["type", "timeframe", "updatedAt"]

// User sessions by drill and date
["userId", "drillId", "startedAt"]

// Popular content queries
["isPublic", "analytics.totalPlays", "createdAt"]
```

### Single Field Indexes
- `createdAt` (descending)
- `updatedAt` (descending)
- `startedAt` (descending)
- `category` (ascending)
- `difficulty` (ascending)
- `isPreset` (ascending)
- `isPublic` (ascending)

## Security Features

1. **User Data Isolation**: Each user can only access their own data
2. **Public Content**: Drills and programs can be public or private
3. **Admin Controls**: System data requires admin privileges
4. **Data Validation**: Strong validation rules for all writes
5. **Rate Limiting**: Built into Firestore security rules

## Performance Optimizations

1. **Pagination**: All list queries support pagination
2. **Caching**: Frequently accessed data is cached
3. **Denormalization**: Strategic data duplication for performance
4. **Batch Operations**: Multiple operations in single transactions
5. **Offline Support**: Local caching with Firestore offline persistence

## Data Migration Strategy

1. **Versioning**: All documents include version numbers
2. **Backward Compatibility**: Old versions supported during transitions
3. **Gradual Migration**: User data migrated on access
4. **Rollback Support**: Ability to revert changes if needed

## Monitoring and Analytics

1. **Performance Monitoring**: Query performance tracking
2. **Usage Analytics**: User behavior and feature usage
3. **Error Tracking**: Comprehensive error logging
4. **Cost Optimization**: Regular cost analysis and optimization

This schema provides a robust, scalable foundation for the BrainBlot application while maintaining flexibility for future enhancements.
