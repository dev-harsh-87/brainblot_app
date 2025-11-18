# Deploy Firestore Security Rules

## Method 1: Using Firebase Console (Recommended)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Firestore Database** → **Rules**
4. Copy the contents of `firestore.rules` file
5. Paste it into the rules editor
6. Click **Publish**

## Method 2: Using Firebase CLI

1. Install Firebase CLI if not already installed:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Initialize Firebase in your project (if not done):
   ```bash
   firebase init firestore
   ```

4. Deploy the rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

## Method 3: Manual Copy-Paste

Copy this content and paste it directly in Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper function to check if user is admin
    function isAdmin() {
      return request.auth != null && 
             exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Allow full access to custom_stimuli collection for authenticated users
    match /custom_stimuli/{document} {
      allow read, write: if request.auth != null;
    }
    
    // Allow read/write access to users collection
    match /users/{userId} {
      allow read, write: if request.auth != null && 
                           (request.auth.uid == userId || isAdmin());
    }
    
    // Allow read access to subscription_plans for authenticated users
    match /subscription_plans/{document} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }
    
    // Allow access to drill categories for authenticated users
    match /drill_categories/{document} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }
    
    // Allow access to drills for authenticated users
    match /drills/{document} {
      allow read, write: if request.auth != null;
    }
    
    // Allow access to programs for authenticated users  
    match /programs/{document} {
      allow read, write: if request.auth != null;
    }
    
    // Temporary: Allow all access for development (REMOVE IN PRODUCTION)
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Important Notes:

- The current rules include a temporary "allow all" rule for development
- Remove the last rule (`match /{document=**}`) in production
- The rules allow authenticated users to access custom_stimuli collection
- Admin users have additional privileges for managing system data

## After Deployment:

1. Restart your Flutter app
2. The permission errors should be resolved
3. Test the stimulus management functionality