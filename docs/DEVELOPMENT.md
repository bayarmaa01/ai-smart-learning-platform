# EduAI Platform - Development Guide

## Table of Contents
- [Getting Started](#getting-started)
- [Development Environment](#development-environment)
- [Project Structure](#project-structure)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Debugging](#debugging)
- [Git Workflow](#git-workflow)
- [Contributing](#contributing)
- [Performance Optimization](#performance-optimization)
- [Troubleshooting](#troubleshooting)

---

## Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js** 20+ (LTS)
- **Python** 3.11+
- **Docker** & Docker Compose
- **PostgreSQL** 15+ (or use Docker)
- **Redis** 7+ (or use Docker)
- **Git**

### Quick Setup

```bash
# 1. Clone the repository
git clone https://github.com/your-org/ai-smart-learning-platform.git
cd ai-smart-learning-platform

# 2. Install dependencies
npm install                    # Root dependencies
cd frontend && npm install     # Frontend dependencies
cd ../backend && npm install   # Backend dependencies
cd ../ai-service && pip install -r requirements.txt  # AI service

# 3. Set up environment
cp backend/env.example backend/.env
cp ai-service/env.example ai-service/.env
cp frontend/.env.example frontend/.env

# 4. Start development environment
docker compose up -d postgres redis minio

# 5. Run database migrations
cd backend && npm run migrate

# 6. Start development servers
npm run dev:all  # Starts all services
```

---

## Development Environment

### IDE Configuration

#### VS Code Extensions

```json
{
  "recommendations": [
    "ms-vscode.vscode-typescript-next",
    "bradlc.vscode-tailwindcss",
    "ms-vscode.vscode-eslint",
    "esbenp.prettier-vscode",
    "ms-python.python",
    "ms-python.black-formatter",
    "ms-vscode.vscode-json",
    "redhat.vscode-yaml",
    "ms-kubernetes-tools.vscode-kubernetes-tools"
  ]
}
```

#### VS Code Settings

```json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true,
    "source.organizeImports": true
  },
  "typescript.preferences.importModuleSpecifier": "relative",
  "emmet.includeLanguages": {
    "javascript": "javascriptreact"
  },
  "python.defaultInterpreterPath": "./ai-service/venv/bin/python",
  "python.formatting.provider": "black",
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": true
}
```

### Environment Configuration

#### Backend Environment (.env)

```env
NODE_ENV=development
PORT=5000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=eduai_db
DB_USER=postgres
DB_PASSWORD=postgres
REDIS_URL=redis://localhost:6379
JWT_SECRET=dev_jwt_secret_minimum_32_characters
JWT_REFRESH_SECRET=dev_refresh_secret_minimum_32_characters
AI_SERVICE_URL=http://localhost:8000
```

#### AI Service Environment (.env)

```env
DEBUG=true
PORT=8000
REDIS_URL=redis://localhost:6379
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/eduai_db
AI_PROVIDER=mock  # Use mock for development, or ollama for free local AI
```

#### Frontend Environment (.env)

```env
VITE_API_URL=http://localhost:5000/api/v1
VITE_AI_URL=http://localhost:8000
VITE_APP_NAME=EduAI Platform
VITE_ENABLE_ANALYTICS=false
```

---

## Project Structure

```
ai-smart-learning-platform/
├── frontend/                    # React frontend
│   ├── src/
│   │   ├── components/         # Reusable components
│   │   │   ├── common/        # Common UI components
│   │   │   ├── forms/         # Form components
│   │   │   └── layout/        # Layout components
│   │   ├── pages/              # Route pages
│   │   ├── store/              # Redux store
│   │   ├── services/           # API services
│   │   ├── i18n/               # Internationalization
│   │   ├── hooks/              # Custom hooks
│   │   └── utils/              # Utility functions
│   ├── public/                 # Static assets
│   ├── Dockerfile
│   └── package.json
├── backend/                     # Node.js backend
│   ├── src/
│   │   ├── controllers/        # Route handlers
│   │   ├── routes/             # Express routes
│   │   ├── middleware/         # Custom middleware
│   │   ├── models/             # Data models
│   │   ├── services/           # Business logic
│   │   ├── db/                 # Database layer
│   │   ├── cache/              # Redis caching
│   │   ├── monitoring/         # Metrics
│   │   └── websocket/          # Real-time features
│   ├── tests/                  # Test files
│   ├── Dockerfile
│   └── package.json
├── ai-service/                  # Python AI service
│   ├── app/
│   │   ├── routers/            # API routes
│   │   ├── services/           # Business logic
│   │   ├── core/               # Configuration
│   │   └── models/             # Pydantic models
│   ├── tests/                  # Test files
│   ├── Dockerfile
│   └── requirements.txt
├── docs/                        # Documentation
├── k8s/                         # Kubernetes manifests
├── helm/                        # Helm charts
├── monitoring/                  # Monitoring configs
└── docker-compose.yml           # Local development
```

---

## Coding Standards

### Frontend (React/TypeScript)

#### Component Structure

```typescript
// Component template
import React from 'react';
import { useTranslation } from 'react-i18next';
import clsx from 'clsx';

interface ComponentProps {
  className?: string;
  children: React.ReactNode;
  variant?: 'primary' | 'secondary';
}

export const Component: React.FC<ComponentProps> = ({
  className,
  children,
  variant = 'primary'
}) => {
  const { t } = useTranslation();

  return (
    <div className={clsx(
      'base-class',
      {
        'base-class--primary': variant === 'primary',
        'base-class--secondary': variant === 'secondary',
      },
      className
    )}>
      {children}
    </div>
  );
};

export default Component;
```

#### Redux Toolkit Slice

```typescript
// store/slices/exampleSlice.ts
import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { apiClient } from '../services/api';

interface ExampleState {
  data: any[];
  loading: boolean;
  error: string | null;
}

const initialState: ExampleState = {
  data: [],
  loading: false,
  error: null,
};

export const fetchData = createAsyncThunk(
  'example/fetchData',
  async (params: { id: string }) => {
    const response = await apiClient.get(`/example/${params.id}`);
    return response.data;
  }
);

const exampleSlice = createSlice({
  name: 'example',
  initialState,
  reducers: {
    clearError: (state) => {
      state.error = null;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchData.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(fetchData.fulfilled, (state, action) => {
        state.loading = false;
        state.data = action.payload;
      })
      .addCase(fetchData.rejected, (state, action) => {
        state.loading = false;
        state.error = action.error.message || 'Failed to fetch data';
      });
  },
});

export const { clearError } = exampleSlice.actions;
export default exampleSlice.reducer;
```

#### API Service

```typescript
// services/api.ts
import axios, { AxiosInstance, AxiosRequestConfig } from 'axios';
import { toast } from 'react-hot-toast';

class ApiClient {
  private client: AxiosInstance;

  constructor(baseURL: string) {
    this.client = axios.create({
      baseURL,
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    this.setupInterceptors();
  }

  private setupInterceptors() {
    // Request interceptor
    this.client.interceptors.request.use(
      (config) => {
        const token = localStorage.getItem('access_token');
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor
    this.client.interceptors.response.use(
      (response) => response.data,
      (error) => {
        if (error.response?.status === 401) {
          localStorage.removeItem('access_token');
          window.location.href = '/login';
        }
        
        const message = error.response?.data?.error?.message || 'An error occurred';
        toast.error(message);
        
        return Promise.reject(error);
      }
    );
  }

  async get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    return this.client.get(url, config);
  }

  async post<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    return this.client.post(url, data, config);
  }

  async put<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    return this.client.put(url, data, config);
  }

  async delete<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    return this.client.delete(url, config);
  }
}

export const apiClient = new ApiClient(import.meta.env.VITE_API_URL);
```

### Backend (Node.js/TypeScript)

#### Controller Structure

```typescript
// controllers/exampleController.ts
import { Request, Response, NextFunction } from 'express';
import { ExampleService } from '../services/exampleService';
import { validateInput } from '../middleware/validation';
import { createExampleSchema } from '../schemas/exampleSchema';

export class ExampleController {
  private exampleService: ExampleService;

  constructor() {
    this.exampleService = new ExampleService();
  }

  public create = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const data = await this.exampleService.create(req.body);
      res.status(201).json({
        success: true,
        data,
        meta: {
          timestamp: new Date().toISOString(),
          request_id: req.id,
        },
      });
    } catch (error) {
      next(error);
    }
  };

  public getAll = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { page = 1, limit = 20, ...filters } = req.query;
      const data = await this.exampleService.findAll({
        page: Number(page),
        limit: Number(limit),
        filters,
      });
      
      res.json({
        success: true,
        data,
        meta: {
          timestamp: new Date().toISOString(),
          request_id: req.id,
          pagination: data.pagination,
        },
      });
    } catch (error) {
      next(error);
    }
  };
}
```

#### Service Layer

```typescript
// services/exampleService.ts
import { ExampleRepository } from '../repositories/exampleRepository';
import { CreateExampleDto, ExampleFilters } from '../types/example';
import { cache } from '../cache/redis';

export class ExampleService {
  private repository: ExampleRepository;

  constructor() {
    this.repository = new ExampleRepository();
  }

  async create(data: CreateExampleDto) {
    const example = await this.repository.create(data);
    
    // Invalidate cache
    await cache.del('examples:list');
    
    return example;
  }

  async findAll(filters: ExampleFilters) {
    const cacheKey = `examples:list:${JSON.stringify(filters)}`;
    const cached = await cache.get(cacheKey);
    
    if (cached) {
      return cached;
    }

    const result = await this.repository.findAll(filters);
    
    // Cache for 5 minutes
    await cache.set(cacheKey, result, 300);
    
    return result;
  }
}
```

#### Middleware

```typescript
// middleware/auth.ts
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { UnauthorizedError } from '../errors/UnauthorizedError';

interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
    role: string;
    tenant_id: string;
  };
}

export const authenticate = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      throw new UnauthorizedError('No token provided');
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET!) as any;
    req.user = decoded;
    
    next();
  } catch (error) {
    next(new UnauthorizedError('Invalid token'));
  }
};

export const authorize = (roles: string[]) => {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        error: {
          code: 'INSUFFICIENT_PERMISSIONS',
          message: 'You do not have permission to perform this action',
        },
      });
    }
    next();
  };
};
```

### AI Service (Python/FastAPI)

#### Router Structure

```python
# routers/example.py
from fastapi import APIRouter, Depends, HTTPException, Query
from typing import List, Optional
from app.schemas.example import ExampleCreate, ExampleResponse
from app.services.example_service import ExampleService
from app.core.auth import get_current_user

router = APIRouter()
example_service = ExampleService()

@router.post("/", response_model=ExampleResponse)
async def create_example(
    example: ExampleCreate,
    current_user = Depends(get_current_user)
):
    """Create a new example"""
    try:
        result = await example_service.create(example, current_user.id)
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/", response_model=List[ExampleResponse])
async def get_examples(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = None,
    current_user = Depends(get_current_user)
):
    """Get examples with pagination"""
    try:
        result = await example_service.get_all(
            page=page,
            limit=limit,
            search=search,
            user_id=current_user.id
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
```

#### Service Layer

```python
# services/example_service.py
from typing import List, Optional, Dict, Any
from app.schemas.example import ExampleCreate, ExampleResponse
from app.core.database import get_database
from app.core.redis_client import cache
import logging

logger = logging.getLogger(__name__)

class ExampleService:
    def __init__(self):
        self.db = get_database()
    
    async def create(self, example: ExampleCreate, user_id: str) -> ExampleResponse:
        """Create a new example"""
        try:
            # Insert into database
            query = """
                INSERT INTO examples (user_id, title, description, created_at)
                VALUES ($1, $2, $3, NOW())
                RETURNING id, title, description, created_at
            """
            result = await self.db.fetchrow(
                query, 
                user_id, 
                example.title, 
                example.description
            )
            
            # Invalidate cache
            await cache.delete(f"examples:user:{user_id}")
            
            return ExampleResponse(**dict(result))
            
        except Exception as e:
            logger.error(f"Error creating example: {e}")
            raise
    
    async def get_all(
        self, 
        page: int, 
        limit: int, 
        search: Optional[str],
        user_id: str
    ) -> List[ExampleResponse]:
        """Get examples for a user"""
        cache_key = f"examples:user:{user_id}:page:{page}:limit:{limit}:search:{search}"
        
        # Try cache first
        cached = await cache.get(cache_key)
        if cached:
            return cached
        
        try:
            offset = (page - 1) * limit
            query = """
                SELECT id, title, description, created_at
                FROM examples
                WHERE user_id = $1
                AND ($2::text IS NULL OR title ILIKE $2)
                ORDER BY created_at DESC
                LIMIT $3 OFFSET $4
            """
            
            search_pattern = f"%{search}%" if search else None
            results = await self.db.fetch(
                query, 
                user_id, 
                search_pattern, 
                limit, 
                offset
            )
            
            examples = [ExampleResponse(**dict(row)) for row in results]
            
            # Cache for 5 minutes
            await cache.set(cache_key, examples, 300)
            
            return examples
            
        except Exception as e:
            logger.error(f"Error fetching examples: {e}")
            raise
```

---

## Testing

### Frontend Testing

#### Unit Tests (Vitest)

```typescript
// tests/components/Button.test.tsx
import { render, screen, fireEvent } from '@testing-library/react';
import { Button } from '../components/Button';

describe('Button Component', () => {
  it('renders with correct text', () => {
    render(<Button>Click me</Button>);
    expect(screen.getByText('Click me')).toBeInTheDocument();
  });

  it('calls onClick when clicked', () => {
    const handleClick = vi.fn();
    render(<Button onClick={handleClick}>Click me</Button>);
    
    fireEvent.click(screen.getByText('Click me'));
    expect(handleClick).toHaveBeenCalledTimes(1);
  });

  it('applies correct variant class', () => {
    render(<Button variant="secondary">Click me</Button>);
    expect(screen.getByText('Click me')).toHaveClass('button--secondary');
  });
});
```

#### Integration Tests

```typescript
// tests/integration/auth.test.tsx
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import { Provider } from 'react-redux';
import { store } from '../store';
import { LoginPage } from '../pages/LoginPage';

const renderWithProviders = (component: React.ReactElement) => {
  return render(
    <Provider store={store}>
      <BrowserRouter>
        {component}
      </BrowserRouter>
    </Provider>
  );
};

describe('Authentication Flow', () => {
  it('allows user to login with valid credentials', async () => {
    renderWithProviders(<LoginPage />);
    
    // Fill form
    fireEvent.change(screen.getByLabelText(/email/i), {
      target: { value: 'test@example.com' },
    });
    fireEvent.change(screen.getByLabelText(/password/i), {
      target: { value: 'password123' },
    });
    
    // Submit form
    fireEvent.click(screen.getByRole('button', { name: /login/i }));
    
    // Wait for navigation
    await waitFor(() => {
      expect(window.location.pathname).toBe('/dashboard');
    });
  });
});
```

### Backend Testing

#### Unit Tests (Jest)

```typescript
// tests/services/exampleService.test.ts
import { ExampleService } from '../../src/services/exampleService';
import { ExampleRepository } from '../../src/repositories/exampleRepository';

jest.mock('../../src/repositories/exampleRepository');

describe('ExampleService', () => {
  let exampleService: ExampleService;
  let mockRepository: jest.Mocked<ExampleRepository>;

  beforeEach(() => {
    mockRepository = new ExampleRepository() as jest.Mocked<ExampleRepository>;
    exampleService = new ExampleService();
    (exampleService as any).repository = mockRepository;
  });

  describe('create', () => {
    it('should create an example successfully', async () => {
      const exampleData = {
        title: 'Test Example',
        description: 'Test Description',
      };

      const expectedExample = {
        id: '1',
        ...exampleData,
        created_at: new Date(),
      };

      mockRepository.create.mockResolvedValue(expectedExample);

      const result = await exampleService.create(exampleData);

      expect(mockRepository.create).toHaveBeenCalledWith(exampleData);
      expect(result).toEqual(expectedExample);
    });

    it('should throw error when repository fails', async () => {
      const exampleData = {
        title: 'Test Example',
        description: 'Test Description',
      };

      mockRepository.create.mockRejectedValue(new Error('Database error'));

      await expect(exampleService.create(exampleData)).rejects.toThrow('Database error');
    });
  });
});
```

#### Integration Tests

```typescript
// tests/integration/auth.test.ts
import request from 'supertest';
import { app } from '../../src/app';
import { setupTestDatabase, cleanupTestDatabase } from '../helpers/database';

describe('Authentication Integration', () => {
  beforeAll(async () => {
    await setupTestDatabase();
  });

  afterAll(async () => {
    await cleanupTestDatabase();
  });

  describe('POST /api/v1/auth/register', () => {
    it('should register a new user', async () => {
      const userData = {
        email: 'test@example.com',
        password: 'Password123!',
        first_name: 'Test',
        last_name: 'User',
      };

      const response = await request(app)
        .post('/api/v1/auth/register')
        .send(userData)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data.user.email).toBe(userData.email);
      expect(response.body.data.tokens.access_token).toBeDefined();
    });

    it('should return error for duplicate email', async () => {
      const userData = {
        email: 'test@example.com',
        password: 'Password123!',
        first_name: 'Test',
        last_name: 'User',
      };

      await request(app)
        .post('/api/v1/auth/register')
        .send(userData);

      const response = await request(app)
        .post('/api/v1/auth/register')
        .send(userData)
        .expect(409);

      expect(response.body.success).toBe(false);
      expect(response.body.error.code).toBe('DUPLICATE_RESOURCE');
    });
  });
});
```

### AI Service Testing

#### Unit Tests (Pytest)

```python
# tests/test_chat_service.py
import pytest
from unittest.mock import AsyncMock, patch
from app.services.chat_service import process_chat
from app.schemas.chat import ChatRequest

@pytest.mark.asyncio
async def test_process_chat_english():
    """Test processing English chat message"""
    request = ChatRequest(
        message="What is Python programming?",
        session_id="test-session",
        user_id="test-user"
    )
    
    with patch('app.services.chat_service.get_provider') as mock_get_provider:
        mock_provider = AsyncMock()
        mock_provider.generate.return_value = MockResponse(
            content="Python is a high-level programming language...",
            tokens_used=50
        )
        mock_get_provider.return_value = mock_provider
        
        result = await process_chat(
            message=request.message,
            session_id=request.session_id,
            user_id=request.user_id
        )
        
        assert result['detected_language'] == 'en'
        assert 'Python' in result['response']
        assert result['tokens_used'] == 50

@pytest.mark.asyncio
async def test_process_chat_mongolian():
    """Test processing Mongolian chat message"""
    request = ChatRequest(
        message="Програмчлал гэж юу вэ?",
        session_id="test-session",
        user_id="test-user"
    )
    
    with patch('app.services.chat_service.get_provider') as mock_get_provider:
        mock_provider = AsyncMock()
        mock_provider.generate.return_value = MockResponse(
            content="Програмчлал бол компьютерд заавар өгөх...",
            tokens_used=45
        )
        mock_get_provider.return_value = mock_provider
        
        result = await process_chat(
            message=request.message,
            session_id=request.session_id,
            user_id=request.user_id
        )
        
        assert result['detected_language'] == 'mn'
        assert 'програмчлал' in result['response'].lower()

class MockResponse:
    def __init__(self, content: str, tokens_used: int):
        self.content = content
        self.tokens_used = tokens_used
```

### Test Scripts

```json
{
  "scripts": {
    "test": "npm run test:frontend && npm run test:backend",
    "test:frontend": "cd frontend && npm run test",
    "test:backend": "cd backend && npm run test",
    "test:ai": "cd ai-service && python -m pytest",
    "test:coverage": "npm run test:coverage:frontend && npm run test:coverage:backend",
    "test:coverage:frontend": "cd frontend && npm run test:coverage",
    "test:coverage:backend": "cd backend && npm run test -- --coverage",
    "test:watch": "npm run test:watch:frontend",
    "test:watch:frontend": "cd frontend && npm run test -- --watch",
    "test:e2e": "playwright test"
  }
}
```

---

## Debugging

### Frontend Debugging

#### React DevTools Setup

```typescript
// Enable Redux DevTools
import { configureStore } from '@reduxjs/toolkit';

export const store = configureStore({
  reducer: {
    // ... reducers
  },
  devTools: process.env.NODE_ENV !== 'production',
});
```

#### Debug Utilities

```typescript
// utils/debug.ts
export const debug = {
  log: (...args: any[]) => {
    if (process.env.NODE_ENV === 'development') {
      console.log('[DEBUG]', ...args);
    }
  },
  
  error: (...args: any[]) => {
    if (process.env.NODE_ENV === 'development') {
      console.error('[ERROR]', ...args);
    }
  },
  
  group: (label: string, fn: () => void) => {
    if (process.env.NODE_ENV === 'development') {
      console.group(label);
      fn();
      console.groupEnd();
    }
  },
};

// Usage example
debug.group('API Request', () => {
  debug.log('Request URL:', url);
  debug.log('Request data:', data);
});
```

### Backend Debugging

#### Debug Middleware

```typescript
// middleware/debug.ts
import { Request, Response, NextFunction } from 'express';

export const debugMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  if (process.env.NODE_ENV === 'development') {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
    console.log('Headers:', req.headers);
    console.log('Body:', req.body);
  }
  next();
};
```

#### Database Query Debugging

```typescript
// utils/database.ts
import { Pool } from 'pg';

export const createDebugPool = (config: any) => {
  const pool = new Pool(config);
  
  if (process.env.NODE_ENV === 'development') {
    pool.on('connect', (client) => {
      console.log('New database client connected');
    });
    
    pool.on('query', (query) => {
      console.log('Executing query:', query.text);
      console.log('Parameters:', query.values);
    });
  }
  
  return pool;
};
```

### AI Service Debugging

#### Logging Configuration

```python
# app/core/logging.py
import logging
import structlog
from app.core.config import settings

def setup_logging():
    """Setup structured logging"""
    
    # Configure structlog
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer() if not settings.DEBUG else structlog.dev.ConsoleRenderer(),
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )
    
    # Configure standard logging
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=logging.DEBUG if settings.DEBUG else logging.INFO,
    )

# Usage
logger = structlog.get_logger(__name__)
logger.info("Processing chat request", user_id=user_id, session_id=session_id)
```

---

## Git Workflow

### Branch Strategy

```
main                 # Production branch
├── develop          # Integration branch
├── feature/user-auth
├── feature/ai-chat
├── feature/multilingual
├── hotfix/security-patch
└── release/v1.1.0
```

### Commit Convention

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

#### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Code style
- `refactor`: Refactoring
- `test`: Tests
- `chore`: Maintenance

#### Examples
```
feat(auth): add multi-factor authentication

Implement TOTP-based MFA for enhanced security.
- Add QR code generation
- Implement backup codes
- Update login flow

Closes #123

fix(api): resolve user registration validation error

The email validation regex was too strict and rejected
valid email addresses.

fixes #456
```

### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-json
      - id: check-merge-conflict

  - repo: https://github.com/psf/black
    rev: 23.1.0
    hooks:
      - id: black
        files: ^ai-service/

  - repo: https://github.com/pycqa/isort
    rev: 5.12.0
    hooks:
      - id: isort
        files: ^ai-service/

  - repo: https://github.com/pre-commit/mirrors-eslint
    rev: v8.36.0
    hooks:
      - id: eslint
        files: ^frontend/
        additional_dependencies:
          - eslint@8.36.0
          - "@typescript-eslint/eslint-plugin"
          - "@typescript-eslint/parser"

  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: v3.0.0-alpha.4
    hooks:
      - id: prettier
        files: ^frontend/
```

---

## Contributing

### Pull Request Process

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Make** your changes
4. **Add** tests for new functionality
5. **Run** the test suite (`npm run test`)
6. **Commit** your changes (`git commit -m 'feat: add amazing feature'`)
7. **Push** to the branch (`git push origin feature/amazing-feature`)
8. **Open** a Pull Request

### PR Template

```markdown
## Description
Brief description of the changes made.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or documented)
- [ ] Tests pass locally

## Screenshots (if applicable)
Add screenshots to help explain your changes.

## Additional Context
Any other context about the pull request.
```

### Code Review Guidelines

1. **Functionality**: Does the code work as intended?
2. **Testing**: Are there adequate tests?
3. **Style**: Does the code follow the style guide?
4. **Performance**: Are there any performance concerns?
5. **Security**: Are there any security implications?
6. **Documentation**: Is the code well documented?

---

## Performance Optimization

### Frontend Performance

#### Bundle Optimization

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'path';

export default defineConfig({
  plugins: [react()],
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          router: ['react-router-dom'],
          redux: ['@reduxjs/toolkit', 'react-redux'],
          ui: ['lucide-react', 'react-hot-toast'],
        },
      },
    },
    chunkSizeWarningLimit: 1000,
  },
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
    },
  },
});
```

#### Image Optimization

```typescript
// components/OptimizedImage.tsx
import React, { useState } from 'react';

interface OptimizedImageProps {
  src: string;
  alt: string;
  width?: number;
  height?: number;
  className?: string;
}

export const OptimizedImage: React.FC<OptimizedImageProps> = ({
  src,
  alt,
  width,
  height,
  className,
}) => {
  const [isLoaded, setIsLoaded] = useState(false);
  const [isError, setIsError] = useState(false);

  return (
    <div className={`relative ${className}`}>
      {!isLoaded && !isError && (
        <div className="absolute inset-0 bg-gray-200 animate-pulse" />
      )}
      <img
        src={src}
        alt={alt}
        width={width}
        height={height}
        loading="lazy"
        onLoad={() => setIsLoaded(true)}
        onError={() => setIsError(true)}
        className={`transition-opacity duration-300 ${
          isLoaded ? 'opacity-100' : 'opacity-0'
        }`}
      />
      {isError && (
        <div className="absolute inset-0 flex items-center justify-center bg-gray-100">
          <span className="text-gray-500">Failed to load image</span>
        </div>
      )}
    </div>
  );
};
```

### Backend Performance

#### Database Optimization

```typescript
// utils/database.ts
export class DatabaseOptimizer {
  static async createIndexes() {
    const queries = [
      'CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email ON users(email)',
      'CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_courses_tenant ON courses(tenant_id)',
      'CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_enrollments_user ON enrollments(user_id)',
      'CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_enrollments_course ON enrollments(course_id)',
      'CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_chat_sessions_user ON chat_sessions(user_id)',
    ];

    for (const query of queries) {
      await this.pool.query(query);
    }
  }

  static async analyzeTables() {
    const tables = ['users', 'courses', 'enrollments', 'chat_sessions'];
    
    for (const table of tables) {
      await this.pool.query(`ANALYZE ${table}`);
    }
  }
}
```

#### Caching Strategy

```typescript
// services/cacheService.ts
export class CacheService {
  static async getOrSet<T>(
    key: string,
    fetcher: () => Promise<T>,
    ttl: number = 300
  ): Promise<T> {
    const cached = await redis.get(key);
    
    if (cached) {
      return JSON.parse(cached);
    }

    const data = await fetcher();
    await redis.set(key, JSON.stringify(data), ttl);
    
    return data;
  }

  static async invalidatePattern(pattern: string): Promise<void> {
    const keys = await redis.keys(pattern);
    if (keys.length > 0) {
      await redis.del(...keys);
    }
  }
}
```

### AI Service Performance

#### Response Caching

```python
# services/cache_service.py
import json
import hashlib
from typing import Any, Optional
from app.core.redis_client import get_redis

class CacheService:
    def __init__(self):
        self.redis = get_redis()
    
    def _generate_key(self, prefix: str, **kwargs) -> str:
        """Generate cache key from parameters"""
        key_data = json.dumps(kwargs, sort_keys=True)
        hash_key = hashlib.md5(key_data.encode()).hexdigest()
        return f"{prefix}:{hash_key}"
    
    async def get_or_set(
        self, 
        prefix: str, 
        fetcher: callable, 
        ttl: int = 300,
        **kwargs
    ) -> Any:
        """Get from cache or set from fetcher"""
        key = self._generate_key(prefix, **kwargs)
        
        # Try to get from cache
        cached = await self.redis.get(key)
        if cached:
            return json.loads(cached)
        
        # Fetch and cache
        data = await fetcher(**kwargs)
        await self.redis.set(key, json.dumps(data), ttl)
        
        return data
    
    async def invalidate_pattern(self, pattern: str) -> None:
        """Invalidate keys matching pattern"""
        keys = await self.redis.keys(pattern)
        if keys:
            await self.redis.delete(*keys)
```

---

## Troubleshooting

### Common Issues

#### Frontend Issues

**Issue: CORS errors in development**
```bash
# Solution: Configure proxy in vite.config.ts
export default defineConfig({
  server: {
    proxy: {
      '/api': 'http://localhost:5000',
      '/ai': 'http://localhost:8000',
    },
  },
});
```

**Issue: Hot module replacement not working**
```bash
# Clear cache and restart
rm -rf node_modules/.vite
npm run dev
```

#### Backend Issues

**Issue: Database connection failed**
```bash
# Check database status
docker compose ps postgres
docker compose logs postgres

# Reset database
docker compose down postgres
docker volume rm ai-smart-learning-platform_postgres_data
docker compose up -d postgres
npm run migrate
```

**Issue: Redis connection timeout**
```bash
# Check Redis status
docker compose ps redis
docker compose exec redis redis-cli ping

# Clear Redis cache
docker compose exec redis redis-cli FLUSHALL
```

#### AI Service Issues

**Issue: AI provider not responding**
```bash
# Check AI service logs
docker compose logs ai-service

# Test AI service directly
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello", "session_id": "test"}'

# Switch to mock provider for testing
export AI_PROVIDER=mock
```

### Debug Commands

```bash
# Check all services
docker compose ps

# View service logs
docker compose logs -f [service-name]

# Restart specific service
docker compose restart [service-name]

# Enter container shell
docker compose exec [service-name] sh

# Check resource usage
docker stats

# Database connection test
docker compose exec postgres psql -U postgres -d eduai_db -c "SELECT 1;"

# Redis connection test
docker compose exec redis redis-cli ping
```

### Performance Monitoring

```bash
# Frontend bundle analysis
cd frontend
npm run build
npx vite-bundle-analyzer dist

# Backend performance profiling
cd backend
npm run start:profiling

# Database query analysis
docker compose exec postgres psql -U postgres -d eduai_db -c "
  SELECT query, calls, total_time, mean_time 
  FROM pg_stat_statements 
  ORDER BY total_time DESC 
  LIMIT 10;
"
```

---

This development guide provides comprehensive information for developers working on the EduAI Platform, ensuring consistent code quality and efficient development workflows.
