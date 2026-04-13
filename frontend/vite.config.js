import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

// Get current version for cache busting
const getVersion = () => {
  try {
    const pkg = require('./package.json');
    return pkg.version || '1.0.0';
  } catch {
    return '1.0.0';
  }
};

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: process.env.VITE_API_URL || 'http://localhost:5000',
        changeOrigin: true,
      },
      '/ai': {
        target: process.env.VITE_AI_URL || 'http://localhost:8000',
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/ai/, ''),
      },
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
    rollupOptions: {
      output: {
        // Add version to asset filenames for cache busting
        assetFileNames: `assets/[name]-${getVersion()}-[hash][extname]`,
        chunkFileNames: `js/[name]-${getVersion()}-[hash].js`,
        entryFileNames: `js/[name]-${getVersion()}-[hash].js`,
        manualChunks: {
          vendor: ['react', 'react-dom', 'react-router-dom'],
          redux: ['@reduxjs/toolkit', 'react-redux'],
          i18n: ['i18next', 'react-i18next'],
          charts: ['recharts'],
        },
      },
    },
    target: 'es2015',
  },
  optimizeDeps: {
    include: ['react', 'react-dom'],
  },
  // Make version available in frontend
  define: {
    __APP_VERSION__: JSON.stringify(getVersion()),
    __BUILD_TIME__: JSON.stringify(new Date().toISOString()),
  },
});
