# EduAI Platform - API Documentation

## Table of Contents
- [Overview](#overview)
- [Authentication](#authentication)
- [Base URLs](#base-urls)
- [Response Format](#response-format)
- [Error Handling](#error-handling)
- [Rate Limiting](#rate-limiting)
- [API Endpoints](#api-endpoints)
  - [Authentication](#authentication-endpoints)
  - [Users](#users-endpoints)
  - [Courses](#courses-endpoints)
  - [Enrollments](#enrollments-endpoints)
  - [AI Chat](#ai-chat-endpoints)
  - [Recommendations](#recommendations-endpoints)
  - [Admin](#admin-endpoints)
- [WebSockets](#websockets)
- [SDKs & Libraries](#sdks--libraries)
- [Examples](#examples)

---

## Overview

The EduAI Platform provides RESTful APIs for building educational applications with AI-powered features. The API supports multilingual operations (English/Mongolian) and includes role-based access control.

### Key Features
- **JWT Authentication** with refresh tokens
- **Role-Based Access Control** (student, instructor, admin, super_admin)
- **Multilingual Support** (English/Mongolian)
- **Real-time Communication** via WebSockets
- **AI-Powered Chat** and recommendations
- **File Upload** support
- **Pagination** and filtering
- **Rate Limiting** for protection

---

## Authentication

### JWT Token Structure

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "Bearer",
  "expires_in": 900,
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "role": "student",
    "tenant_id": "uuid"
  }
}
```

### Authorization Header

```http
Authorization: Bearer <access_token>
```

### Token Refresh

Access tokens expire in 15 minutes. Use the refresh token to obtain a new access token without re-authentication.

---

## Base URLs

| Environment | Base URL |
|-------------|----------|
| Development | `http://localhost:5000/api/v1` |
| Staging | `https://api-staging.eduai.com/api/v1` |
| Production | `https://api.eduai.com/api/v1` |

---

## Response Format

### Success Response

```json
{
  "success": true,
  "data": {
    // Response data
  },
  "meta": {
    "timestamp": "2024-01-01T00:00:00Z",
    "request_id": "uuid",
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 100,
      "pages": 5
    }
  }
}
```

### Error Response

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format"
      }
    ]
  },
  "meta": {
    "timestamp": "2024-01-01T00:00:00Z",
    "request_id": "uuid"
  }
}
```

---

## Error Handling

### HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Created |
| 204 | No Content |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 409 | Conflict |
| 422 | Validation Error |
| 429 | Rate Limit Exceeded |
| 500 | Internal Server Error |

### Error Codes

| Code | Description |
|------|-------------|
| `VALIDATION_ERROR` | Input validation failed |
| `AUTHENTICATION_FAILED` | Invalid credentials |
| `AUTHORIZATION_FAILED` | Insufficient permissions |
| `RESOURCE_NOT_FOUND` | Resource does not exist |
| `DUPLICATE_RESOURCE` | Resource already exists |
| `RATE_LIMIT_EXCEEDED` | Too many requests |
| `EXTERNAL_SERVICE_ERROR` | Third-party service error |

---

## Rate Limiting

| Endpoint | Limit | Window |
|----------|-------|--------|
| Auth endpoints | 5 requests | 15 minutes |
| General API | 100 requests | 15 minutes |
| AI Chat | 60 requests | 1 minute |
| File Upload | 10 requests | 1 hour |

Rate limit headers are included in responses:

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 99
X-RateLimit-Reset: 1640995200
```

---

## API Endpoints

### Authentication Endpoints

#### Register User

```http
POST /auth/register
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "first_name": "John",
  "last_name": "Doe",
  "role": "student",
  "tenant_id": "uuid"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "role": "student",
      "is_active": true,
      "created_at": "2024-01-01T00:00:00Z"
    },
    "tokens": {
      "access_token": "jwt_token",
      "refresh_token": "refresh_token",
      "expires_in": 900
    }
  }
}
```

#### Login

```http
POST /auth/login
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

#### Refresh Token

```http
POST /auth/refresh
```

**Request Body:**
```json
{
  "refresh_token": "refresh_token_here"
}
```

#### Logout

```http
POST /auth/logout
```

#### Get Current User

```http
GET /auth/me
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "email": "user@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "role": "student",
    "tenant_id": "uuid",
    "preferences": {
      "language": "en",
      "timezone": "UTC"
    },
    "last_login": "2024-01-01T00:00:00Z"
  }
}
```

---

### Users Endpoints

#### Get Users (Admin Only)

```http
GET /users?page=1&limit=20&role=student&search=john
```

**Query Parameters:**
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 20, max: 100)
- `role`: Filter by role
- `search`: Search by name or email
- `tenant_id`: Filter by tenant

#### Get User by ID

```http
GET /users/{user_id}
```

#### Update User

```http
PUT /users/{user_id}
```

**Request Body:**
```json
{
  "first_name": "John",
  "last_name": "Doe",
  "preferences": {
    "language": "mn",
    "timezone": "Asia/Ulaanbaatar"
  }
}
```

#### Delete User (Admin Only)

```http
DELETE /users/{user_id}
```

---

### Courses Endpoints

#### Get Courses

```http
GET /courses?page=1&limit=20&category=programming&level=beginner&instructor_id=uuid
```

**Query Parameters:**
- `page`: Page number
- `limit`: Items per page
- `category`: Filter by category
- `level`: Filter by level (beginner, intermediate, advanced)
- `instructor_id`: Filter by instructor
- `tenant_id`: Filter by tenant
- `search`: Search by title or description

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "title": "Introduction to Python",
      "description": "Learn Python programming from scratch",
      "instructor": {
        "id": "uuid",
        "name": "John Doe",
        "email": "instructor@example.com"
      },
      "category": "programming",
      "level": "beginner",
      "price": 49.99,
      "currency": "USD",
      "thumbnail_url": "https://cdn.example.com/course.jpg",
      "duration_hours": 40,
      "lessons_count": 25,
      "enrollments_count": 1500,
      "rating": 4.8,
      "is_published": true,
      "created_at": "2024-01-01T00:00:00Z"
    }
  ],
  "meta": {
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 50,
      "pages": 3
    }
  }
}
```

#### Get Course by ID

```http
GET /courses/{course_id}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "title": "Introduction to Python",
    "description": "Learn Python programming from scratch",
    "instructor": {
      "id": "uuid",
      "name": "John Doe",
      "bio": "Python expert with 10 years experience"
    },
    "category": "programming",
    "level": "beginner",
    "price": 49.99,
    "currency": "USD",
    "thumbnail_url": "https://cdn.example.com/course.jpg",
    "duration_hours": 40,
    "lessons_count": 25,
    "lessons": [
      {
        "id": "uuid",
        "title": "Getting Started",
        "description": "Introduction to Python",
        "order_index": 1,
        "duration_minutes": 30,
        "type": "video",
        "video_url": "https://cdn.example.com/video.mp4",
        "resources": [
          {
            "type": "pdf",
            "title": "Course Notes",
            "url": "https://cdn.example.com/notes.pdf"
          }
        ]
      }
    ],
    "requirements": ["Basic computer skills"],
    "objectives": ["Learn Python basics", "Build simple programs"],
    "rating": 4.8,
    "reviews_count": 250,
    "enrollments_count": 1500,
    "is_published": true,
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

#### Create Course (Instructor/Admin Only)

```http
POST /courses
```

**Request Body:**
```json
{
  "title": "Introduction to Python",
  "description": "Learn Python programming from scratch",
  "category": "programming",
  "level": "beginner",
  "price": 49.99,
  "currency": "USD",
  "requirements": ["Basic computer skills"],
  "objectives": ["Learn Python basics", "Build simple programs"]
}
```

#### Update Course (Instructor/Admin Only)

```http
PUT /courses/{course_id}
```

#### Delete Course (Admin Only)

```http
DELETE /courses/{course_id}
```

#### Enroll in Course

```http
POST /courses/{course_id}/enroll
```

**Response:**
```json
{
  "success": true,
  "data": {
    "enrollment_id": "uuid",
    "course_id": "uuid",
    "user_id": "uuid",
    "enrollment_date": "2024-01-01T00:00:00Z",
    "status": "active",
    "completion_percentage": 0.0
  }
}
```

#### Get Course Progress

```http
GET /courses/{course_id}/progress
```

**Response:**
```json
{
  "success": true,
  "data": {
    "enrollment_id": "uuid",
    "completion_percentage": 65.5,
    "lessons_completed": 16,
    "lessons_total": 25,
    "time_spent_minutes": 1200,
    "last_accessed": "2024-01-01T00:00:00Z",
    "lessons_progress": [
      {
        "lesson_id": "uuid",
        "completed": true,
        "completion_time": "2024-01-01T00:00:00Z",
        "time_spent_minutes": 30
      }
    ]
  }
}
```

#### Update Lesson Progress

```http
POST /courses/{course_id}/lessons/{lesson_id}/progress
```

**Request Body:**
```json
{
  "completed": true,
  "time_spent_minutes": 30,
  "last_position_seconds": 1800
}
```

---

### Enrollments Endpoints

#### Get User Enrollments

```http
GET /enrollments?status=active&page=1&limit=20
```

#### Get Enrollment Details

```http
GET /enrollments/{enrollment_id}
```

#### Cancel Enrollment

```http
DELETE /enrollments/{enrollment_id}
```

---

### AI Chat Endpoints

#### Send Chat Message

```http
POST /ai/chat
```

**Request Body:**
```json
{
  "message": "What is Python programming?",
  "session_id": "uuid",
  "context": {
    "course_id": "uuid",
    "lesson_id": "uuid"
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "response": "Python is a high-level programming language...",
    "detected_language": "en",
    "language_confidence": 0.95,
    "tokens_used": 150,
    "session_id": "uuid",
    "sources": [
      {
        "title": "Python Documentation",
        "url": "https://docs.python.org"
      }
    ]
  }
}
```

#### Get Chat History

```http
GET /ai/chat/history/{session_id}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "session_id": "uuid",
    "messages": [
      {
        "id": "uuid",
        "role": "user",
        "content": "What is Python programming?",
        "language": "en",
        "created_at": "2024-01-01T00:00:00Z"
      },
      {
        "id": "uuid",
        "role": "assistant",
        "content": "Python is a high-level programming language...",
        "language": "en",
        "tokens_used": 150,
        "model_name": "gpt-4",
        "created_at": "2024-01-01T00:00:00Z"
      }
    ]
  }
}
```

#### Clear Chat Session

```http
DELETE /ai/chat/{session_id}
```

---

### Recommendations Endpoints

#### Get Course Recommendations

```http
GET /ai/recommendations/courses?user_id=uuid&limit=10
```

**Response:**
```json
{
  "success": true,
  "data": {
    "recommendations": [
      {
        "course": {
          "id": "uuid",
          "title": "Advanced Python",
          "description": "Deep dive into Python",
          "price": 89.99,
          "rating": 4.9
        },
        "score": 0.92,
        "reason": "Based on your interest in Python programming",
        "category_match": true
      }
    ],
    "algorithm": "collaborative_filtering",
    "generated_at": "2024-01-01T00:00:00Z"
  }
}
```

#### Get Learning Path Recommendations

```http
GET /ai/recommendations/learning-path?goal=web_development&level=beginner
```

---

### Admin Endpoints

#### Get Dashboard Stats

```http
GET /admin/stats
```

**Response:**
```json
{
  "success": true,
  "data": {
    "users": {
      "total": 10000,
      "active": 8500,
      "new_this_month": 500
    },
    "courses": {
      "total": 250,
      "published": 200,
      "new_this_month": 15
    },
    "enrollments": {
      "total": 50000,
      "active": 35000,
      "completed": 15000
    },
    "revenue": {
      "total": 2500000.00,
      "this_month": 150000.00,
      "currency": "USD"
    },
    "ai_usage": {
      "total_requests": 1000000,
      "this_month": 50000,
      "avg_response_time_ms": 250
    }
  }
}
```

#### Get System Health

```http
GET /admin/health
```

**Response:**
```json
{
  "success": true,
  "data": {
    "status": "healthy",
    "services": {
      "database": {
        "status": "healthy",
        "response_time_ms": 5
      },
      "redis": {
        "status": "healthy",
        "response_time_ms": 2
      },
      "ai_service": {
        "status": "healthy",
        "response_time_ms": 150
      },
      "storage": {
        "status": "healthy",
        "available_space_gb": 500
      }
    },
    "metrics": {
      "cpu_usage_percent": 45,
      "memory_usage_percent": 60,
      "disk_usage_percent": 30
    }
  }
}
```

#### Get User Analytics

```http
GET /admin/analytics/users?period=30d&group_by=day
```

#### Get Course Analytics

```http
GET /admin/analytics/courses?period=30d&course_id=uuid
```

---

## WebSockets

### Connection

```javascript
const socket = io('ws://localhost:5000', {
  auth: {
    token: 'jwt_token_here'
  }
});
```

### Events

#### Join Course Room

```javascript
socket.emit('join_course', {
  course_id: 'uuid'
});
```

#### Send Chat Message

```javascript
socket.emit('chat_message', {
  course_id: 'uuid',
  message: 'Hello everyone!'
});
```

#### Receive Chat Message

```javascript
socket.on('chat_message', (data) => {
  console.log('New message:', data);
});
```

#### Course Updates

```javascript
socket.on('course_update', (data) => {
  console.log('Course updated:', data);
});
```

#### User Status

```javascript
socket.on('user_status', (data) => {
  console.log('User status:', data);
});
```

---

## SDKs & Libraries

### JavaScript/TypeScript SDK

```bash
npm install @eduai/api-client
```

```typescript
import { EduAIClient } from '@eduai/api-client';

const client = new EduAIClient({
  baseURL: 'https://api.eduai.com',
  token: 'jwt_token_here'
});

// Get courses
const courses = await client.courses.list();

// Enroll in course
const enrollment = await client.courses.enroll('course_id');

// Send chat message
const response = await client.ai.chat.send({
  message: 'What is Python?',
  session_id: 'session_id'
});
```

### Python SDK

```bash
pip install eduai-api
```

```python
from eduai import EduAIClient

client = EduAIClient(
    base_url='https://api.eduai.com',
    token='jwt_token_here'
)

# Get courses
courses = client.courses.list()

# Send chat message
response = client.ai.chat.send(
    message='What is Python?',
    session_id='session_id'
)
```

---

## Examples

### Complete Authentication Flow

```javascript
// 1. Register user
const registerResponse = await fetch('/api/v1/auth/register', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    email: 'user@example.com',
    password: 'SecurePass123!',
    first_name: 'John',
    last_name: 'Doe'
  })
});

const { user, tokens } = await registerResponse.json();

// 2. Store tokens
localStorage.setItem('access_token', tokens.access_token);
localStorage.setItem('refresh_token', tokens.refresh_token);

// 3. Make authenticated request
const coursesResponse = await fetch('/api/v1/courses', {
  headers: {
    'Authorization': `Bearer ${tokens.access_token}`
  }
});
```

### File Upload

```javascript
const formData = new FormData();
formData.append('file', fileInput.files[0]);
formData.append('type', 'course_thumbnail');

const uploadResponse = await fetch('/api/v1/upload', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`
  },
  body: formData
});

const { url } = await uploadResponse.json();
```

### Real-time Chat Implementation

```javascript
class ChatManager {
  constructor(token) {
    this.socket = io('/chat', {
      auth: { token }
    });
    
    this.setupEventListeners();
  }
  
  setupEventListeners() {
    this.socket.on('message', (message) => {
      this.displayMessage(message);
    });
    
    this.socket.on('typing', (data) => {
      this.showTypingIndicator(data.user);
    });
  }
  
  sendMessage(courseId, message) {
    this.socket.emit('message', {
      course_id: courseId,
      message: message
    });
  }
  
  joinCourse(courseId) {
    this.socket.emit('join_course', { course_id: courseId });
  }
}
```

### Error Handling

```javascript
class ApiClient {
  async request(url, options = {}) {
    try {
      const response = await fetch(url, {
        headers: {
          'Authorization': `Bearer ${this.token}`,
          'Content-Type': 'application/json',
          ...options.headers
        },
        ...options
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        throw new ApiError(data.error, response.status);
      }
      
      return data;
    } catch (error) {
      if (error instanceof ApiError) {
        // Handle API errors
        this.handleApiError(error);
      } else {
        // Handle network errors
        this.handleNetworkError(error);
      }
    }
  }
  
  handleApiError(error) {
    switch (error.code) {
      case 'AUTHENTICATION_FAILED':
        this.redirectToLogin();
        break;
      case 'RATE_LIMIT_EXCEEDED':
        this.showRateLimitWarning();
        break;
      default:
        this.showGenericError(error.message);
    }
  }
}
```

---

## Testing

### Postman Collection

Import the Postman collection from `docs/api-collection.json` to test all endpoints.

### cURL Examples

```bash
# Login
curl -X POST http://localhost:5000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"SecurePass123!"}'

# Get courses
curl -X GET http://localhost:5000/api/v1/courses \
  -H "Authorization: Bearer <token>"

# Send chat message
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"What is Python?","session_id":"uuid"}'
```

---

## Versioning

The API follows semantic versioning. Current version: **v1.0.0**

### Version Changes
- **v1.0.0** - Initial release
- **v1.1.0** - Added video streaming support
- **v1.2.0** - Enhanced AI recommendations

### Backward Compatibility
- Breaking changes require version increment
- Deprecated endpoints are maintained for 6 months
- Migration guides provided for major updates

---

This API documentation provides comprehensive information for integrating with the EduAI Platform, including all endpoints, authentication, and examples.
