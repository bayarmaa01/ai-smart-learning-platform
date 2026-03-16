module.exports = {
  env: {
    browser: true,
    node: true,
    es2022: true,
    jest: true
  },
  globals: {
    global: 'writable',
    IntersectionObserver: 'writable',
    ResizeObserver: 'writable',
    vi: 'readonly',
    expect: 'readonly',
    afterEach: 'readonly',
    beforeEach: 'readonly'
  },
  extends: [
    'eslint:recommended',
    '@typescript-eslint/recommended',
    'plugin:react/recommended',
    'plugin:react-hooks/recommended'
  ],
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module',
    ecmaFeatures: {
      jsx: true
    }
  },
  plugins: [
    'react',
    'react-hooks',
    '@typescript-eslint'
  ],
  rules: {
    // React specific rules
    'react/react-in-jsx-scope': 'error',
    'react/prop-types': 'warn',
    'react/jsx-uses-react': 'error',
    'react/jsx-uses-react': 'error',
    'react/jsx-uses-react-1': 'error',
    'react/jsx-key': 'error',
    'react/no-children-prop': 'error',
    'react/no-array-index-key': 'error',
    'react/no-unsafe': 'warn',
    'react/no-unescaped-entities': 'error',
    'react/require-render-return': 'error',
    'react/self-closing-comp': 'error',
    'react/jsx-fragments': 'error',
    
    // React Hooks rules
    'react-hooks/rules-of-hooks': 'error',
    'react-hooks/exhaustive-deps': 'warn',
    
    // General JavaScript rules
    'no-unused-vars': ['warn', { 
      argsIgnorePattern: '^_',
      varsIgnorePattern: '^toast$|^rejectWithValue$|^action$'
    }],
    'no-console': 'warn',
    'no-debugger': 'error',
    'no-duplicate-imports': 'error',
    'no-unused-expressions': 'error',
    'prefer-const': 'warn',
    'no-var': 'error'
  },
  settings: {
    react: {
      version: 'detect'
    }
  },
  overrides: [
    {
      files: ['**/*.test.js', '**/*.test.jsx', '**/*.test.ts', '**/*.test.tsx'],
      env: {
        jest: true
      },
      globals: {
        global: 'writable',
        IntersectionObserver: 'writable',
        ResizeObserver: 'writable',
        vi: 'readonly',
        expect: 'readonly',
        afterEach: 'readonly',
        beforeEach: 'readonly'
      },
      rules: {
        'no-unused-expressions': 'off',
        'no-console': 'off',
        'no-undef': 'off'
      }
    }
  ]
};
